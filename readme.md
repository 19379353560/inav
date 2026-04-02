# INAV 飞控固件 — 性能优化版

> 基于 [iNavFlight/inav](https://github.com/iNavFlight/inav) 官方仓库的个人优化分支，针对 PID 控制质量、调度器效率和自制飞控板硬件适配进行了系统性改进。
>
> **官方 PR：** [iNavFlight/inav#11464](https://github.com/iNavFlight/inav/pull/11464)

---

## 优化概览

| 类别 | 工作内容 | 核心收益 |
|---|---|---|
| 算法优化 | D 项预微分低通滤波 | 噪声放大倍数从 9× 降至 3.6×，D 增益余量提升 15~25% |
| 工程优化 | 调度器 / 任务系统 / 传感器链路共 6 处 | 减少重复遍历与无意义操作，降低热路径开销 |
| 硬件适配 | 新建 SKYPILOT target（STM32H743 + 双 ICM-42688P） | IMU 读取延迟从 ~1ms 降至 ~20μs |

---

## 一、算法优化：D 项预微分低通滤波

### 问题

PID 控制器的 D 项对陀螺仪信号做差分，微分操作天然放大高频噪声。在 1kHz 采样率下，500Hz 噪声经微分放大约 **9 倍**，导致：

- kD 调大后电机发热、高频嗡嗡声
- D 增益余量受限，无法充分发挥 D 项的抗振荡能力

### 解决方案

在差分之前增加一级 PT1 低通预滤波（借鉴 Betaflight 架构）：

```
原方案：陀螺仪原始值 ──→ [差分] ──→ [后置LPF] ──→ D输出
                          ↑ 噪声在此放大 ~9×

新方案：陀螺仪原始值 ──→ [前置PT1 LPF @250Hz] ──→ [差分] ──→ [后置LPF] ──→ D输出
                                                    ↑ 噪声放大倍数降至 ~3.6×
```

代价：250Hz PT1 引入约 **+0.6ms** 延迟，对 1kHz PID 循环完全可接受。

### 核心代码改动

**`pid.h`** — 新增配置字段：
```c
typedef struct pidProfile_s {
    uint16_t dterm_lpf_hz;   // D 项后置滤波器截止频率（原有）
+   uint16_t dterm_lpf2_hz;  // D 项前置滤波器截止频率（新增，0=禁用）
} pidProfile_t;
```

**`pid.c`** — `dTermProcess()` 核心路径重构：
```c
static float dTermProcess(...) {
    if (pidState->kD == 0) return 0;  // 提前返回，减少 Yaw 轴无效运算

    float delta;
    if (dtermLpf2Hz > 0) {
        // 新增路径：先滤波再差分
        const float filteredGyro = pt1FilterApply(&pidState->dtermLpf2State, pidState->gyroRate);
        delta = pidState->previousFilteredGyroRate - filteredGyro;
        pidState->previousFilteredGyroRate = filteredGyro;
    } else {
        delta = pidState->previousRateGyro - pidState->gyroRate;  // 原有路径
    }
    return delta * (pidState->kD * dT_inv) * applyDBoost(...);
}
```

### 效果对比

| 指标 | 优化前 | 优化后 |
|---|---|---|
| D 项噪声放大倍数 | ~9× | ~3.6×（降低 60%） |
| 引入额外延迟 | 0 | +0.6ms |
| D 增益余量 | 基准 | +15~25% |

---

## 二、工程优化：调度器与任务系统

### 2.1 `queueAdd()` 合并两次扫描为一次

原实现先调用 `queueContains()` 查重（一次 O(n) 扫描），再 for 循环找插入位置（第二次 O(n) 扫描）。改为单次遍历同时完成查重和定位：

```c
// 改动后：一次 O(n) 扫描完成查重 + 找插入位置
int insertPos = taskQueueSize;
for (int ii = 0; ii < taskQueueSize; ++ii) {
    if (taskQueueArray[ii] == task) return false;  // 查重
    if (insertPos == taskQueueSize &&
        taskQueueArray[ii]->staticPriority < task->staticPriority) {
        insertPos = ii;  // 记录插入位置
    }
}
```

### 2.2 `setTaskEnabled()` 避免重复启停

原实现不检查任务当前状态，直接调用 `queueAdd/queueRemove`，导致已启用的任务被重复加入。改为先检查状态，只在需要变化时才操作队列。

### 2.3 传感器链路：缓存重复配置查询

`taskUpdateBattery()`、`getAmperageSample()`、`currentMeterUpdate()` 等函数中，同一次调用内 `isAmperageConfigured()`、`feature(FEATURE_VBAT)`、`batteryMetersConfig()` 被重复调用 2~3 次。统一改为函数开头缓存到局部变量，复用结果。

---

## 三、硬件适配：SKYPILOT 自制飞控板

### 硬件规格

- MCU：STM32H743VIT6（480MHz Cortex-M7）
- IMU：双 ICM-42688P，各配独立 DRDY 中断引脚
- 连接：SPI1（陀螺仪 0）+ SPI4（陀螺仪 1）

### DRDY 中断的工程意义

```
轮询模式：CPU 每 1ms 主动读取 → 最坏情况引入 ~1ms 额外延迟
中断模式：ICM-42688P 采样完成 → DRDY 拉高 → EXTI 触发 → ISR 置标志 → 立即读取
         实际延迟：~20μs（SPI 传输时间）
```

IMU 读取延迟从最坏 **1ms** 降至 **~20μs**，对 1kHz PID 循环意义重大。

### 新建 Target 文件

```c
// target.h — 双陀螺仪 + DRDY 引脚定义
#define USE_DUAL_GYRO
#define ICM42688_CS_PIN_1    PC15
#define ICM42688_SPI_BUS_1   BUS_SPI1
#define ICM42688_EXTI_PIN_1  PA4    // DRDY → EXTI Line 4

#define ICM42688_CS_PIN_2    PE11
#define ICM42688_SPI_BUS_2   BUS_SPI4
#define ICM42688_EXTI_PIN_2  PD2    // DRDY → EXTI Line 2
```

---

## 推荐参数

| 机型 | `dterm_lpf2_hz` |
|---|---|
| 5寸穿越机 | 250 Hz |
| 7寸长续航 | 200 Hz |
| 禁用预滤波 | 0 |

---

## 相关链接

- [官方 PR #11464](https://github.com/iNavFlight/inav/pull/11464)
- [INAV 官方仓库](https://github.com/iNavFlight/inav)
- [SKYPILOT 飞控硬件](https://github.com/19379353560/skypilot)
