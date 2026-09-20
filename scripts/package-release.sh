#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
bash scripts/verify-app.sh
version="$(cat VERSION)"
arch="$(uname -m)"
[[ "$arch" == "arm64" ]] || { printf 'This release target requires Apple Silicon.\n' >&2; exit 1; }
name="PhotoNaming-$version-macos-$arch"
release_dir="$PWD/dist/releases"
mkdir -p "$release_dir"
stage="$(mktemp -d "$PWD/.build/release-stage.XXXXXX")"
mkdir -p "$stage/$name"
ditto --norsrc --noextattr "$PWD/dist/照片命名.app" "$stage/$name/照片命名.app"
cp docs/USER_GUIDE.md "$stage/$name/USER_GUIDE.md"
cp docs/README-FIRST.txt "$stage/$name/README-FIRST.txt"
cp LICENSE "$stage/$name/LICENSE"
ditto -c -k --norsrc --noextattr --keepParent "$stage/$name" "$release_dir/$name.zip"
ln -s /Applications "$stage/$name/Applications"
hdiutil create -ov -volname "PhotoNaming $version" -srcfolder "$stage/$name" -format UDZO "$release_dir/$name.dmg"
(
    cd "$release_dir"
    shasum -a 256 "$name.zip" "$name.dmg" > SHA256SUMS.txt
)
revision="$(git rev-parse HEAD)"
{
    printf 'PhotoNaming %s\nSource: https://github.com/QiushanHuang/PhotoNaming\nRevision: %s\nArchitecture: %s\nMinimum macOS: 14.0\n' "$version" "$revision" "$arch"
    printf 'Signing: ad-hoc; not Developer ID signed; not Apple-notarized\nMaintainer: Qiushan (@QiushanHuang)\n\n'
    swift --version
    sw_vers
} > "$release_dir/BUILD-INFO.txt"
printf '\nRelease assets: %s\n' "$release_dir"
