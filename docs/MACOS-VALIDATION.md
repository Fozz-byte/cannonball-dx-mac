# Mac port validation — 14 October 2026

## Environment and scope

Apple M1 MacBook Air, 16 GB RAM, macOS 27.0.1, Xcode 27 / macOS 27 SDK.
Upstream base: `09edd625138d5b95bc41b184ee8bda0e0d7c4b8b`.
ROM source: user-supplied OutRun Revision B ZIP, referenced outside this repository.
No ROMs are included in source or the app bundle.

This is a working personal-use port, not a completed release acceptance run.
Automated runs and keyboard gameplay establish basic operation. A subsequent
30-minute attract/demo soak passed after audio scheduling fixes; see
[MACOS-SOAK.md](MACOS-SOAK.md). This does not establish every game mode or
controller compatibility.

## Completed checks

- Release and Debug compile with Apple Clang for arm64, minimum macOS 27.0.
- Release executable has only Apple system dynamic dependencies. SDL2, TinyXML2,
  mpg123, miniz and scalers are compiled into the app. Debug additionally uses
  Apple's sanitizer runtime and is intended to run on a development machine.
- Ad-hoc bundle signature passes strict verification.
- GPU readback passes in Release and Debug: RGBA, ABGR and packed 5551; padded
  rows; red/green/blue/white corner orientation; overlay masking; neutral normal
  and fast shaders; repeated backend initialization and destruction.
- User-supplied ZIP and loose ROM folder containing spaces load successfully.
  Missing ZIP, empty directory and corrupt ZIP return validation failure.
- Native first-launch picker saves a validated location. Relaunch resolves that
  location without relying on the shell's working directory.
- Actual game displayed and driven using keyboard Start, steering and accelerator.
  Normal graphics and the full CRT/NTSC combination were visually inspected.
- Command-P toggles pause once per keypress; Command-O opens the native picker;
  Command-Q quits. Explicit pause is shown in the window title. Normal quit
  persists configuration and statistics.
- Short Debug gameplay run with AddressSanitizer and UndefinedBehaviorSanitizer
  completed without reported sanitizer errors. This does not cover all engine paths.

## Rendering matrix

Each case ran for ten seconds with isolated user data and exited successfully.
The first FPS sample includes startup; subsequent samples are shown below.
These are short-run frame throughput measurements, not a thermal soak or a
measurement of simulation speed. The upstream 30 Hz simulation divisor remains
unchanged.

| Case | Observed subsequent FPS range |
| --- | --- |
| Default 30 fps | 29.98–30.03 |
| Default 60 fps | 60.00–60.01 |
| Default 120 fps | 119.25–120.09 |
| 16:9 | 59.96–60.04 |
| 21:9 | 60.00–60.03 |
| Fast CRT | 59.95–60.02 |
| Full CRT + NTSC | 58.07–60.04 |
| xBRZ 3× | 59.96–60.08 |
| xBRZ 4× | 59.95–60.08 |
| xBRZ 5× | 59.96–60.06 |
| xBRZ 6× | 57.55–60.00 |
| HQx 3× | 59.97–60.05 |
| HQx 4× | 59.98–60.03 |

Reproduce with `CANNONBALL_ROM_PATH=/path/outrun.zip python3 tests/macos_render_matrix.py`.
ROM failure checks use `tests/macos_rom_paths.py` with the same environment variable.
Both retain logs in temporary directories; neither writes ROMs into the repository.

## Acceptance still outstanding

- A physical Mac-compatible gamepad: mappings, reconnection and supported rumble.
- A human-played 30-minute session and expensive-preset performance comparisons.
  The automated default-preset 30-minute attract/demo soak is complete; it averaged
  59.90 fps with zero observed application audio starvation after the fixes.
- Completion of all game modes, results and high-score entry; custom music;
  explicit simulation-speed comparison at 30/60/120 fps.
- Physical sleep/wake and audio-device changes, external displays, exhaustive
  Retina resize/fullscreen transitions and sustained renderer restart stress.
- Full visual parity against upstream GLES reference captures, beyond synthetic
  pixel tests and the inspected gameplay frames.
- Explicit Finder double-click testing (LaunchServices launch from `/Applications`
  has now been checked, along with workspace paths containing spaces).

Wheel force feedback and cabinet output remain deliberately unavailable. Public
signing and notarization are deferred. No claim of full release acceptance is made.

## Follow-up input checks

The installed windowed build now captures system shortcuts during focused,
unpaused gameplay. On macOS 27.0.1, Control-Left and Control-Up kept the game
focused; Escape paused and released capture, and Command-O opened the native ROM
panel with capture released. Diagnostic state confirmed the pointer hid over
content and reappeared over the title bar. Command-Q shut down normally. These
input/cursor changes were checked separately after the recorded performance soak.

## App identity and credits follow-up

The installed app is now `CannonBall DX for Mac.app`. LaunchServices launch from
Applications, window/menu titles, the native About window and the in-game credits
were checked. The project credit order is Chris White, James Pearce, Endprodukt,
then Astra and Fozz-byte. The original bundle identifier and Application Support
folder remain in use; `config.xml` and `highscores.xml` matched their pre-rename
hashes after launch. These changes do not constitute a repeat of the full soak.
