#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export PATH="$ROOT_DIR/.tools/bin:$PATH"
MODE="${1:-run}"
PRESET="${CANNONBALL_PRESET:-macos-release}"
case "$MODE" in run|--build-only|--debug|--logs|--telemetry|--verify|--soak) ;; *) echo "Usage: $0 [--build-only|--debug|--logs|--telemetry|--verify|--soak]" >&2; exit 2;; esac
command -v cmake >/dev/null || { echo 'Install CMake 3.31+ and Ninja (see docs/MACOS.md).'; exit 1; }
if [ "$MODE" != --build-only ]; then pkill -x cannonball-dx || true; fi
cmake --preset "$PRESET"
cmake --build --preset "$PRESET" --parallel 4
APP="$ROOT_DIR/build/$PRESET/cannonball-dx.app"
/usr/bin/codesign --force --sign - "$APP"
# Keep the internal CMake target stable while publishing the Mac fork's app name.
STAGED_APP="$ROOT_DIR/dist/CannonBall DX for Mac.app"
/usr/bin/ditto "$APP" "$STAGED_APP"
APP="$STAGED_APP"
BINARY="$APP/Contents/MacOS/cannonball-dx"
case "$MODE" in
 --build-only) echo "$APP";;
 --soak) exec python3 "$ROOT_DIR/tests/macos_soak.py";;
 --debug) /usr/bin/lldb -- "$BINARY";;
 --logs) /usr/bin/open -n "$APP"; tail -F "$HOME/Library/Application Support/CannonBall DX/CannonBall.log";;
 --telemetry) /usr/bin/open -n "$APP"; /usr/bin/log stream --level info --style compact --predicate 'process == "cannonball-dx"';;
 --verify) /usr/bin/open -n "$APP"; sleep 2; pgrep -x cannonball-dx >/dev/null;;
 run) /usr/bin/open -n "$APP";;
esac
