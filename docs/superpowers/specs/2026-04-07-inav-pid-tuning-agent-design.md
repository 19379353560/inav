# INAV PID Tuning Agent — Design Spec

Date: 2026-04-07

## Overview

A web-based tool that accepts INAV Blackbox log files (.bbl), analyzes flight data using rule-based algorithms, and produces PID/filter tuning recommendations with ready-to-paste CLI commands.

No external AI APIs. No server rental required. Runs entirely on the user's local machine.

---

## Architecture

```
Browser (HTML/JS)
  │  Upload .bbl file
  ▼
FastAPI Backend (Python, local)
  ├── blackbox_decode (CLI tool) → CSV
  ├── Data extractor (pandas) → key metrics
  ├── Rule engine → tuning recommendations
  └── CLI command generator
  ▼
Browser
  ├── Charts (gyro noise, step response, PID error)
  ├── Recommendations with explanations
  └── Copy-to-clipboard CLI commands
```

---

## Components

### 1. Log Parser
- Accepts `.bbl` / `.bfl` upload via HTTP POST
- Calls `blackbox_decode` subprocess → CSV
- Loads CSV with pandas

### 2. Metrics Extractor
Extracts from CSV:
- Gyro noise floor (FFT of gyro signal)
- P error magnitude (setpoint vs gyroADC)
- D term noise (high-frequency content in dterm)
- I term windup (sustained error over time)
- Step response shape (rise time, overshoot, oscillation)

### 3. Rule Engine
Rules per axis (roll, pitch, yaw):

| Symptom | Metric | Recommendation |
|---|---|---|
| Oscillation | High-freq P error peaks | Lower P by 10-15% |
| Slow response | Large sustained P error | Raise P by 10% |
| D noise | High HF content in dterm | Raise dterm_lpf_hz or lower D |
| I windup | Sustained non-zero I error | Raise I by 10% |
| Gyro noise | High noise floor in FFT | Lower gyro_lpf_hz |
| Motor buzz | Noise spike at specific freq | Add notch filter at that freq |

### 4. CLI Command Generator
Outputs INAV CLI snippet, e.g.:
```
set p_roll = 42
set d_roll = 28
set dterm_lpf_hz = 90
save
```

### 5. Frontend
- Single HTML page, no framework
- File upload → POST to `/analyze`
- Display: charts (Chart.js), recommendation cards, CLI textarea with copy button

---

## Data Flow

1. User uploads `.bbl` → POST `/analyze`
2. Backend saves temp file, runs `blackbox_decode`
3. pandas loads CSV, extractor computes metrics
4. Rule engine produces recommendations list
5. CLI generator builds command string
6. Response JSON: `{metrics, recommendations, cli_commands}`
7. Frontend renders charts + recommendations + CLI box

---

## Tech Stack

- Backend: Python, FastAPI, pandas, numpy, scipy (FFT)
- Frontend: Plain HTML + Chart.js (CDN)
- External tool: `blackbox_decode` (must be installed by user)

---

## Out of Scope

- Real-time MSP connection
- Automatic parameter write to FC
- Machine learning / external AI
- Multi-flight comparison
