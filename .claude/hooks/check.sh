#!/bin/bash
grep -RIn "HAL_Delay" . || true
grep -RIn "while *(.*1" . || true
