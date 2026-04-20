# Safety

This repository contains experimental INAV firmware work. Treat branches,
builds, and configuration notes as review material unless the change has been
merged upstream or validated on a specific aircraft with logs.

## Before Testing

- Read the active upstream PR discussion.
- Back up the current tune and configuration.
- Keep `dterm_lpf2_hz` disabled for baseline testing.
- Change one setting at a time and use conservative flight patterns.
- Watch motor temperature and stop if behavior changes unexpectedly.

## Useful Test Data

- Blackbox logs with `dterm_lpf2_hz = 0`.
- Comparable logs at 200Hz and 250Hz when safe.
- Notes about aircraft size, props, motors, firmware commit, tune profile, and
  vibration symptoms.

## Reporting

Flight-test request:

https://github.com/19379353560/inav/issues/1

Flight-test guide:

https://19379353560.github.io/dterm-flight-test-guide.html
