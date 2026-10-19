#!/bin/zsh
# Renders the icon and packs it into Resources/AppIcon.icns.
set -euo pipefail

cd "$(dirname "$0")/.."
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

swift scripts/make-icon.swift Resources/AppIcon.png
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
trash "$(dirname "$ICONSET")"
echo "Wrote Resources/AppIcon.icns"
