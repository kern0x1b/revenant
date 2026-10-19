#!/bin/sh
# ipa.sh INPUT.ipa INCLUDES OUTPUT.ipa — translate an arm64 iOS application archive for armv7 iOS 6.
set -eu
LAB=$(cd "$(dirname "$0")/.." && pwd)
input=$(cd "$(dirname "$1")" && pwd)/$(basename "$1") includes=$(cd "$(dirname "$2")" && pwd)/$(basename "$2") output=$3
work=$(mktemp -d "${TMPDIR:-/tmp}/xlate-ipa.XXXXXX")
trap 'rm -rf "$work"' EXIT
ditto -x -k "$input" "$work/in"
app=$(ls -d "$work"/in/Payload/*.app | head -1)
executable=$(plutil -extract CFBundleExecutable raw "$app/Info.plist")
images=""
if [ -d "$app/Frameworks" ]; then
  for framework in "$app"/Frameworks/*; do
    case "$framework" in
      *.framework) images="$images $framework/$(plutil -extract CFBundleExecutable raw "$framework/Info.plist")" ;;
      *.dylib) images="$images $framework" ;;
    esac
  done
fi
lipo -thin arm64 "$app/$executable" -output "$work/$executable-arm64" 2>/dev/null || cp "$app/$executable" "$work/$executable-arm64"
"$LAB/scripts/translate.sh" "$work/$executable-arm64" "$includes" "$work/build" $images
rm -rf "$app/Frameworks" "$app/_CodeSignature" "$app/embedded.mobileprovision" "$app/PlugIns"
cp "$work/build/$executable" "$app/$executable"
plutil -convert xml1 "$app/Info.plist"
plutil -replace MinimumOSVersion -string 6.0 "$app/Info.plist"
plutil -replace UIRequiredDeviceCapabilities -json '["armv7"]' "$app/Info.plist"
plutil -convert binary1 "$app/Info.plist"
rules="${includes%/*}/$(basename "$app" .app).rules"
[ -f "$rules" ] && cp "$rules" "$app/xlate.rules"
ldid -S "$app/$executable"
mkdir -p "$(dirname "$output")"
(cd "$work/in" && ditto -c -k --norsrc --noextattr --keepParent Payload "$work/out.ipa")
mv "$work/out.ipa" "$output"
echo "$output"
