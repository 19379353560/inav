# Contributing

Thanks for reviewing these INAV firmware experiments. The most useful
contributions are flight logs, careful code review, and reproducible test notes.

## Helpful Feedback

- Blackbox logs comparing `dterm_lpf2_hz = 0` with enabled values such as 200Hz
  or 250Hz.
- Motor temperature notes after short hover and active flight.
- Notes about frame size, props, motors, firmware version, and vibration source.
- Code review on PID/filter initialization, scheduler cleanup, and sensor-chain
  maintainability.

## Where To Comment

- Flight-test request:
  https://github.com/19379353560/inav/issues/1
- Discussion:
  https://github.com/19379353560/inav/discussions/2
- Flight-test guide:
  https://19379353560.github.io/dterm-flight-test-guide.html
- Upstream PR #11464:
  https://github.com/iNavFlight/inav/pull/11464
- Upstream PR #11465:
  https://github.com/iNavFlight/inav/pull/11465

## Safety

Treat these branches as experimental. Do not fly unreviewed firmware on a model
you cannot safely test, and always keep conservative filter/PID changes.
