#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
icon_dir="$PWD/.build/branding/AppIcon.iconset"
mkdir -p "$icon_dir"
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" assets/branding/logo.png --out "$icon_dir/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -s format png -z "$double_size" "$double_size" assets/branding/logo.png --out "$icon_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_dir" -o .build/branding/AppIcon.icns
