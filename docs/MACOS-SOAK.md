# Performance soak — 14 October 2026

## Test method

Release arm64 build, M1 MacBook Air with 16 GB RAM, macOS 27.0.1,
AC power. User-supplied Revision B ROMs remain outside the project.
The automated test runs the animated attract/demo loop, including its road,
sprite and audio workload, at 60 fps with the default visual options, 4:3,
window scale 2 and vsync off. It is not a 30-minute human-played race and does
not validate all game modes or controllers.

`script/build_and_run.sh --soak` runs GPU pixel and audio callback checks first,
then a bounded 1,800-second engine run. It samples presented frame rates every
two seconds, application mixer starvation counters, process RSS/CPU every five
seconds and macOS thermal warnings every minute. The first minute is warm-up.
Logs and isolated configuration are retained in the ignored `test-results/`
directory. Focus-loss pausing is bypassed only in the explicit soak test mode;
normal app launches retain it. A temporary `caffeinate` process keeps the test
awake and exits with the game.

Audio missing-buffer counts measure requests the application mixer could not
satisfy immediately. They are not measurements of all possible downstream
CoreAudio/device glitches. The thermal command reports OS warnings, not silicon
temperature or proof that clock throttling never occurred. RSS is resident
memory, not a complete heap/leak measurement.

## First full run

Evidence: `test-results/soak-20261014-141637/`.

- Clean exit after 1,800 seconds of engine operation (harness elapsed 1,804.51 s,
  including startup and polling).
- 895 frame-rate samples; steady-state median 59.9944 fps, minimum 47.2818 fps.
  Five steady-state two-second samples fell below 57 fps.
- 107,767 presented frames and 61 skipped frames at the final sample;
  zero paused frames.
- 225,277 audio callbacks; 100 missing buffers total, 98 after warm-up.
  Therefore the strict audio criterion failed despite their low frequency.
- RSS after warm-up: 99,456 KiB initially, 88,064 KiB finally; peak 99,568 KiB.
- No thermal or performance warning was reported by `pmset`.

## Corrections

Inspection found that the upstream audio callback waited indefinitely on a
producer semaphore. The callback now returns silence immediately when a buffer
is missing, records the event, and leaves ring ownership intact for recovery.
A regression test covers starvation, recovery, multiple ring wraps and slot
accounting. Pausing stops and joins the producer before resetting its queue;
playback state is initialized before the producer starts.

The first full measurement still showed intermittent starvation, often alongside
rendering stalls. The Mac mixer now requests user-interactive QoS for its 8 ms
deadline. Active gameplay holds an `NSProcessInfo` user-initiated activity to
avoid App Nap; pausing releases it and normal idle system sleep remains allowed.
The test additionally records maximum mixer work time and scheduling gaps to
distinguish computational cost from delayed execution. These changes do not
increase the four-buffer queue or its normal audio latency.

## Full rerun after the scheduling corrections — passed

Evidence: `test-results/soak-20261014-145036/` (`result.json`, `metrics.json`,
`resources.json`, `thermal.log`, `run.log`, GPU/audio self-test logs and binary
SHA256 in `environment.json`).

| Measurement | Result |
| --- | --- |
| Requested engine duration | 1,800 seconds |
| Harness elapsed / process exit | 1,804.16 seconds / 0 |
| Frame-rate samples | 895 |
| Steady-state average / median | 59.8996 / 59.9947 fps |
| Lowest two-second sample | 53.798 fps |
| Steady-state samples below 57 fps | 6 (under 1%) |
| Frames / skipped / paused at final sample | 107,733 / 73 / 0 |
| Observed audio callbacks / missing buffers | 225,298 / 0 |
| Maximum mixer work time / scheduling gap | 0.897 ms / 20.128 ms |
| RSS after warm-up: initial / final / peak | 107.33 / 86.31 / 107.56 MiB |
| Mean sampled process CPU after warm-up | 21.10% (100% denotes one logical CPU) |
| macOS thermal/performance warnings | None reported |

The weighted average uses cumulative frames and elapsed time between the first
post-warm-up sample and the final sample. Counters above are from the last
periodic sample at 1,798.62 seconds; the engine then reached its 1,800-second
limit and shut down successfully. Six isolated frame-rate dips remain, but no
sustained decline or upward resident-memory trend was observed. The test passes
its documented frame-rate and zero-starvation criteria; it does not promise a
perfect 16.67 ms frame interval on every frame.

The first run's intermittent mixer starvation did not recur in this full rerun.
The zero count is an application-level result, not an acoustic measurement or a
guarantee against all device-level audio glitches. Human gameplay across every
mode, gamepad/rumble tests, audio-device changes and sleep/wake remain separate
acceptance work.

## Final regression and packaging checks

The corrected Debug build passed Metal GPU readback, audio callback starvation/
recovery tests and a 15-second real-ROM smoke run under AddressSanitizer and
UndefinedBehaviorSanitizer, with no sanitizer diagnostics. The Release bundle
was rebuilt and ad-hoc signed after adding this report; strict bundle signature
verification passed. Its app code uses the same source as the successful soak.
The report/resources and resulting code signature differ from the recorded test
bundle, so its whole-executable SHA256 is not expected to match the test hash.
