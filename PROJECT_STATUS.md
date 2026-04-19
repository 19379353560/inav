# Project Status

This repository is a personal INAV firmware branch used for experiments,
upstream pull requests, and SkyPilot H743 support work.

## Focus Areas

- D-term pre-differentiation low-pass filtering.
- Scheduler and task-system cleanup.
- Sensor-chain code cleanup.
- SkyPilot H743 target support.

## Upstream Pull Requests

- https://github.com/iNavFlight/inav/pull/11464
- https://github.com/iNavFlight/inav/pull/11465

## Current Review Request

Flight-test feedback and Blackbox logs are welcome here:

https://github.com/19379353560/inav/issues/1

Useful feedback includes:

- Logs on noisy and clean frames with `dterm_lpf2_hz` disabled and enabled.
- Motor temperature notes after hover and active flight.
- D-term noise comparisons around disabled, 200Hz, and 250Hz.
- Any unexpected behavior when changing PID/filter profiles.

## Validation Status

Treat this branch as experimental unless a change has been merged upstream or
validated on a specific aircraft with logs. Review upstream discussion before
using the branch for real flights.

## Review Needed

- D-term filter naming and default value.
- Flight logs on noisy and clean frames.
- Motor temperature observations.
- Scheduler and sensor-chain maintainability review.
- SkyPilot target review.
