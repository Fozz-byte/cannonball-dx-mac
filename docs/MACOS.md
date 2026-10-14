# CannonBall DX for Mac

This branch ports CannonBall DX 1.04 at upstream commit
`09edd625138d5b95bc41b184ee8bda0e0d7c4b8b` to arm64, macOS 27.0 and newer.
The C++ engine and SDL2 input/audio remain intact; the Mac display backend uses
Metal and ports the original James Pearce CRT shader equations. No EGL, ANGLE,
Rosetta, Homebrew runtime, or ROM data is required in the application bundle.

## Build and launch

Install Xcode 27 with its macOS SDK, CMake 3.31 and Ninja. The development setup
used here installs build tools in a project-local virtual environment:

```sh
python3 -m venv .tools
.tools/bin/pip install cmake==3.31.6 ninja==1.11.1.4
./script/build_and_run.sh
```

The script performs a local ad-hoc signature. `--build-only` builds without
launching; `--debug` starts LLDB; `--logs` follows the app log; `--telemetry`
streams system process logs; `--verify` checks launch/process survival.
The Codex Run action uses this script.

Use `CANNONBALL_PRESET=macos-debug ./script/build_and_run.sh` for the
AddressSanitizer/UndefinedBehaviorSanitizer Debug build. Debug is intentionally
much slower than Release and is not a performance reference.

The script stages the bundle at `dist/CannonBall DX for Mac.app`. It can be copied to
Applications or another directory. It contains only arm64 application code and
statically linked third-party libraries. Public distribution, Developer ID
signing, notarization and sandboxing are outside this personal-use build.

## First run and controls

Choose your own OutRun Revision B ZIP or extracted folder. Files are validated
with the existing CRC/size loader and referenced in place. Moving the source
requires choosing it again. The app never modifies or packages the ROMs.
Choose ROMs in the application menu saves a validated location for the next
launch. Cancel leaves the previous selection unchanged.

Settings, scores, statistics, the application log and `Music/` are in
`~/Library/Application Support/CannonBall DX/`. The menu can open this folder.
The original folder and bundle identifier are retained after the rename to
CannonBall DX for Mac, so existing settings and high scores continue to load.
Custom music uses the upstream `01_Name.wav`, `.mp3`, or `.ym` naming convention.
Bundled resources and user music use separate absolute paths; launch does not
rely on a working directory. Existing XML and `-cfgfile` remain supported.

The current DX default keyboard profile is **1** Start, **5** Coin,
**Left Control** accelerator, **Left Option** brake, arrow keys steering,
**Space** low gear, **Left Shift** high gear, **Z** view and **Tab** game menu.
Bindings remain editable in the game. **Command-Q** quits and **Command-P**
pauses/resumes. Focus loss/minimization/sleep pauses play and stops rumble;
resume explicitly with Command-P or F1. The first Mac launch is windowed.

While an unpaused game has keyboard focus, keyboard capture suppresses macOS
Control-arrow desktop/Mission Control shortcuts. **Escape** pauses and releases
capture; Command-P, focus loss and native panels also release it. Command-Q
remains available. App switching shortcuts may be captured too, so pause first
when switching by keyboard. The mouse remains free: its pointer hides over the
active game content, reappears over the title bar/outside the game, and is shown
while paused or in native panels. No System Settings shortcuts are changed.
The personal-use build enables SDL2's existing non-sandboxed Cocoa keyboard-grab
implementation, which uses a non-public macOS API; this must be revisited for
any future sandboxed/App Store build or incompatible macOS update.

SDL-compatible gamepads use the existing binding matrix. Physical controller
reconnection and rumble must be verified on each supported device. Wheel input
may work through SDL, but wheel force feedback and cabinet outputs are disabled
on Mac in this release.

## Rendering and threading

`presentation.hpp` selects Metal on Apple and the existing GLES backend on other
platforms. Metal uploads support padded rows, packed 5551 engine output, RGBA,
ABGR and an R8 overlay. The backend waits for the previous GPU command buffer
before reusing texture storage. CPU rendering retains its two worker threads;
input, native windows, event dispatch and Metal presentation stay on the main
thread. Mac uses standard scheduling rather than Linux CPU affinity.

The full shader retains curvature, brightness, noise, desaturation, vignette
and shadow masks. Fast mode omits the same effects as the upstream fast shader.
The original CPU NTSC filter and xBRZ/HQx stages remain available. Extreme scaler
settings may exceed the 60 fps frame budget on an M1; the default preset does not enable
them. The built-in 30/60/120 settings retain the upstream 30 Hz game logic.

## Validation

```sh
./script/build_and_run.sh --build-only
./script/test_macos.sh
CANNONBALL_ROM_PATH=/absolute/path/outrun.zip ./script/test_macos.sh
```

The test script checks architecture, runtime dependency paths and signature,
then exercises real Metal GPU readback for RGBA/ABGR/5551 uploads, padded row
pitch, corner orientation, both neutral CRT shader variants, overlays and
renderer recreation. With ROMs it also runs a bounded gameplay smoke test.
`CANNONBALL_TEST_SECONDS` sets its duration. Test state goes into a fresh `/tmp`
directory and is retained for inspection. `CANNONBALL_USER_DATA` and
`CANNONBALL_ROM_PATH` are explicit local test overrides, not app defaults.

Run the default-preset 30-minute performance soak with:

```sh
CANNONBALL_ROM_PATH=/absolute/path/outrun.zip ./script/build_and_run.sh --soak
```

This builds Release, checks Metal and audio buffer recovery, then runs the
animated attract/demo cycle with isolated state. It records two-second frame
rates, skipped/paused frame counters, audio callback and missing-buffer counts,
five-second process RSS/CPU samples and macOS thermal warnings in `test-results/`.
The display stays awake only for the test. The explicit `CANNONBALL_SOAK=1` test
mode bypasses focus-loss pausing so other apps can be used; normal launches retain
focus-loss pausing. Avoid interacting with the game's menus during measurement.
`CANNONBALL_SOAK_SECONDS=30` is available for a short harness preflight.

The first minute is treated as warm-up. A successful run requires clean shutdown,
active unpaused frames, audio callbacks, no missing audio buffers after warm-up,
a median of at least 59 fps and no more than 1% of samples below 57 fps. RSS and
thermal observations are recorded for inspection, not inferred from frame rate.
Missing-buffer counts measure application mixer starvation; they do not detect
all possible hardware or downstream CoreAudio glitches.

See [MACOS-SOAK.md](MACOS-SOAK.md) for the completed 30-minute measurements
and audio fixes, and `MACOS-VALIDATION.md` for remaining hardware tests.

## Dependencies and notices

Mac dependency archives are version- and SHA256-pinned: SDL 2.32.10, TinyXML2
11.0.0 and mpg123 1.32.9. miniz and Mesen2 scaler sources retain the upstream
commit pins. Dependency source and build artifacts live under the CMake build
directory. Preserve upstream and third-party notices. Static LGPL components
and the repository's other license terms need a separate distribution review
before releasing binaries outside personal use.
