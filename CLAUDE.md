# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目信息

**INAV** — 面向多旋翼/固定翼 RC 飞行器的导航飞控固件（C99/C11）。
MCU: STM32H743 | IMU: ICM42688P | 支持 STM32F4/F7/H7 和 AT32F43x

## 要求

- 用中文回答
- 代码逐行解释
- 必须分析延迟、SPI、DRDY
- 不要空话，只给工程结论

重点关注：
- IMU 采样链路
- 中断 vs 轮询
- 数据延迟
- INAV 调参

## 构建

**Docker 构建（推荐）：**
```bash
./build.sh <TARGET_NAME>      # 构建指定目标（如 MATEKH743）
./build.sh all                # 构建所有目标
./build.sh valid_targets      # 列出所有支持的目标
./build.sh clean              # 清理所有构建产物
```

**手动构建（需要 arm-none-eabi 工具链）：**
```bash
mkdir -p build && cd build
cmake -DWARNINGS_AS_ERRORS=ON ..
make <TARGET_NAME>
```

**SITL 仿真构建（宿主机运行）：**
```bash
cmake -DSITL=ON ..
make
```

## 单元测试

测试框架：Google Test，位于 `src/test/unit/`（22 个 `.cc` 测试文件）。

```bash
cd build
cmake ..
make check          # 运行全部测试（通过 ctest）
ctest -R <test>     # 运行单个测试，例如 ctest -R gyro
```

## 架构

### 启动与主循环

`main.c` → `fc/fc_init.c:init()` → `fc/fc_tasks.c:tasksInit()` → 协作式任务调度器（`scheduler/scheduler.c`）

调度器按优先级轮询任务，最高优先级路径：**陀螺仪采样 → PID → Mixer → 电机输出**。

### 关键子系统

| 目录 | 职责 |
|---|---|
| `fc/` | 核心逻辑、MSP 协议、初始化 |
| `sensors/` | 陀螺仪、加速度计、气压计、GPS、空速管驱动与处理 |
| `drivers/` | 硬件抽象层：SPI/I2C/UART/DMA/Timer |
| `flight/` | PID 控制器、Mixer |
| `navigation/` | 航点任务、RTH、定点悬停 |
| `scheduler/` | 实时任务调度 |
| `config/` | Parameter Group (PG) 系统，EEPROM 存储 |
| `target/` | 212 块板级定义（`target.h` + `target.c`） |

### IMU 采样链路（本项目重点）

ICM42688P 通过 SPI 连接，DRDY 引脚触发外部中断 → ISR 置位标志 → 调度器在最高优先级任务中读取数据 → 陀螺数据送入 PID。

关键文件：
- `drivers/accgyro/accgyro_spi_icm426xx.c` — SPI 驱动、DRDY 中断注册
- `sensors/gyro.c` — 采样任务、滤波器链
- `fc/fc_tasks.c` — `taskGyroUpdate` 任务优先级配置

### 配置系统

设置定义在 `fc/settings.yaml`（自动生成 C 代码）。Parameter Group 通过 `config/parameter_group.h` 的 `PG_REGISTER_*` 宏注册，存储于 EEPROM。

## 编码规范

- 类型名后缀 `_t`（如 `gyroConfig_t`），枚举后缀 `_e`
- 函数名 camelCase：`gyroInit()`、`isOkToArm()`
- 常量/宏全大写：`MAX_GYRO_COUNT`、`FASTRAM`
- 缩进 4 空格，K&R 大括号风格
- 头文件用 `#pragma once`
- 条件编译区分 MCU 型号：`#if defined(STM32H7)`
