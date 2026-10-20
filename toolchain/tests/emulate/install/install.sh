#!/bin/bash
set -eu
cd "$(dirname "$0")"
. ../../common/runs.sh "$PWD"
device=${1:-iPhone2,1}
release=${2:-6.1.3}
out=${OUT_DIR:-$(runs_folder emulate-install)}
program=emulateinstall
installed=/usr/libexec/$program
mkdir -p "$out"

image=$(grep -rl "org.revenant.emulateinstall" "${HOME}/.revenant/emulator/images.noindex"/*/*/image.json 2>/dev/null |
        sed 's#/image.json$##' | head -1)
if [ -n "$image" ]; then
  echo "the image for this project is already there: $image" >&2
  echo "remove it to run this case against a fresh one, or run it against a device and release whose image" >&2
  echo "this project has not got yet" >&2
  exit 1
fi

xmake f -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
xmake emulate install -d "$device" -r "$release" > "$out/install.log" 2>&1
status=0
sed 's/^/  /' "$out/install.log" | tail -3

built=$(find build -name "$program" -type f 2>/dev/null | head -1)
if [ -z "$built" ]; then
  echo "the project was not built, so there is nothing to look for in the image; see $out/configure.log" >&2
  exit 1
fi
image=$(grep -rl "org.revenant.emulateinstall" "${HOME}/.revenant/emulator/images.noindex"/*/*/image.json 2>/dev/null |
        sed 's#/image.json$##' | head -1)
if [ -z "$image" ]; then
  echo "the install wrote no image.json, so it placed nothing it named; see $out/install.log" >&2
  exit 1
fi
rootfs=$image/rootfs
echo "the image is $rootfs"
uuid() { /usr/bin/otool -l "$1" 2>/dev/null | awk '/LC_UUID/{getline;getline;print $2}'; }

if [ ! -d "$rootfs$installed" ] && [ ! -e "$rootfs$installed" ]; then
  echo "the directory the program belongs in is not there: $rootfs$installed" >&2
  ls -d "$rootfs"/usr/* 2>/dev/null | sed 's/^/  /' >&2 || echo "  and neither is $rootfs/usr" >&2
  echo "the install reported success and placed nothing" >&2
  status=1
elif [ ! -f "$rootfs$installed" ]; then
  echo "$rootfs$installed is not a file" >&2
  status=1
else
  echo "the program is at $rootfs$installed, $(stat -f%z "$rootfs$installed") B"
  a=$(uuid "$built"); b=$(uuid "$rootfs$installed")
  echo "  built     ${a:-no LC_UUID}"
  echo "  installed ${b:-no LC_UUID}"
  if [ -z "$a" ] || [ -z "$b" ]; then
    echo "  one of the two has no LC_UUID, so they cannot be told apart" >&2
    status=1
  elif [ "$a" = "$b" ]; then
    echo "  MATCH: the image holds this build's program"
  else
    echo "  MISMATCH: the image holds another build's program" >&2
    status=1
  fi
fi
exit $status
