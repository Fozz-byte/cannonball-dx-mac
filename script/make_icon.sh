#!/usr/bin/env bash
set -euo pipefail
SOURCE="$1"
OUTPUT="$2"
ICONSET="$OUTPUT/CannonBall.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  /usr/bin/sips -z "$SIZE" "$SIZE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  /usr/bin/sips -z "$DOUBLE" "$DOUBLE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT/CannonBall.icns"
