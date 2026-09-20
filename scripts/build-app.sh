#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid VERSION\n' >&2; exit 1; }
swift build -c release
bash scripts/build-icon.sh
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/照片命名.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/PhotoNaming" "$app_dir/Contents/MacOS/PhotoNaming"
cp .build/branding/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
cp assets/branding/logo.png "$app_dir/Contents/Resources/BrandLogo.png"
cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PhotoNaming</string>
<key>CFBundleIdentifier</key><string>studio.qiushan.PhotoNaming</string>
<key>CFBundleName</key><string>照片命名</string>
<key>CFBundleDisplayName</key><string>照片命名</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Qiushan (QiushanHuang). MIT License.</string>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf '%s\n' "$app_dir"
