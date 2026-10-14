#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRESET="${CANNONBALL_PRESET:-macos-release}"
APP="$ROOT_DIR/build/$PRESET/cannonball-dx.app"
BINARY="$APP/Contents/MacOS/cannonball-dx"
TEST_DIR="$(mktemp -d /tmp/cannonball-validation.XXXXXX)"
[ "$(lipo -archs "$BINARY")" = arm64 ]
if otool -L "$BINARY" | tail -n +2 | awk '{print $1}' | grep -vE '^(/System/Library/|/usr/lib/|@rpath/libclang_rt\.)'; then
  echo 'Unexpected runtime dependency' >&2; exit 1
fi
codesign --verify --deep --strict "$APP"
CANNONBALL_USER_DATA="$TEST_DIR" "$BINARY" --metal-self-test
CANNONBALL_USER_DATA="$TEST_DIR" "$BINARY" --audio-self-test
if [ -n "${CANNONBALL_ROM_PATH:-}" ]; then
  CANNONBALL_USER_DATA="$TEST_DIR" CANNONBALL_TEST_SECONDS="${CANNONBALL_TEST_SECONDS:-15}" "$BINARY"
fi
echo "Validation data retained at $TEST_DIR"
