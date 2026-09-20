#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_dir="${1:-$PWD/dist/照片命名.app}"
test -x "$app_dir/Contents/MacOS/PhotoNaming"
test -s "$app_dir/Contents/Resources/AppIcon.icns"
test -s "$app_dir/Contents/Resources/BrandLogo.png"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --verify --strict --verbose=2 "$app_dir"
python3 - "$app_dir" <<'PY'
import pathlib, plistlib, sys
root = pathlib.Path(sys.argv[1])
with (root / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleShortVersionString'] == pathlib.Path('VERSION').read_text().strip()
assert info['CFBundleIdentifier'] == 'studio.qiushan.PhotoNaming'
assert info['CFBundleIconFile'] == 'AppIcon'
assert info['LSMinimumSystemVersion'] == '14.0'
assert (root / 'Contents/Resources/AppIcon.icns').read_bytes()[:4] == b'icns'
assert (root / 'Contents/Resources/BrandLogo.png').read_bytes() == pathlib.Path('assets/branding/logo.png').read_bytes()
print('PASS: version, identifier, minimum OS, icon and bundled logo')
PY
file "$app_dir/Contents/MacOS/PhotoNaming"
