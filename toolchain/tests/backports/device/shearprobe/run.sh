#!/bin/sh
# run.sh - configure, build and install the shear probe into the emulated iPhone3,1 6.1.3 image, gate on the
# built binary's LC_UUID against the installed copy, and stop. The emulator RUN is the only heavy part and it
# lives in run-guest.sh, which this calls.
#
# WHY THE SPLIT, and it is measured: `coordination/heavy.sh` wraps a job at lowered priority in one of three
# machine-wide slots, and under it this kind of project's `xmake f` fails with rc=255 and every package
# reported as not found - shade, swiftshader, emulator-guest, iphoneos-sdk, ld64, ldid, llvm, firmware-tools -
# while the identical command run directly configures with rc=0 (v-crutch6, measured). So configure, build and
# install run directly and only the run takes a slot:
#
#   $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/shearprobe/run-guest.sh
#
# THE IMAGE IS FOUND BY ASKING XMAKE FOR ITS NAME, and a glob is wrong here. `xmake emulate` names an image
# after the project DIRECTORY: plugins/emulate/main.lua computes
# `(project.name() .. "-" .. hash.strhash32(os.projectdir()))`, so this project directory has exactly one image
# name and asking is the only way to name it. Two images of one project exist on this machine the moment a
# second copy of the project does (metalchainprobe-6cc2f0f5 and metalchainprobe-d6a40e29, both real), and the
# first a glob picks is not the one the install filled - the gate then compares this build's LC_UUID against
# another copy and stops, which is safe but means the run never happens. No image is deleted here.
#
# THE LC_UUID GATE IS THE POINT OF THIS SCRIPT. `xmake emulate install` has been observed printing
# "installing .. install ok!" and leaving the image's copy of the program unchanged, so a guest run has executed
# a binary two edits old and reported its output as a result. Every run compares the built binary against the
# copy in THIS image's rootfs and stops if they differ. The identity read is LC_UUID and not a byte hash,
# because neither strip nor `ldid -S` changes LC_UUID while both rewrite the bytes a hash would be taken over.
#
# THE MTIMES ARE PRINTED AND NOT COMPARED, which is vdsp-probe's measured correction and not a weakening: on
# this image the installed copy reads `mtime 0` while the build it came from reads a real time, so an mtime
# gate refuses a run whose two LC_UUIDs are the same value.
#
# `xmake emulate run` is given a BARE PATH and no arguments: with arguments it answers "fail(spawn error 2)"
# even for a system binary (coordinator, measured on the v-crutch5 runs of 2026-10-04). The probe therefore
# names no scenario on the command line and forks one child per case, each answering through a pipe - a forked
# child's writes to this guest's standard output do not reach the runner's capture (v-crutch6, measured: twelve
# children each printed one line and not one line arrived).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${SHEARPROBE_ROOT:-$(cd "$here/../../../.." && pwd)}
out="$here/run"
mkdir -p "$out"
cd "$here"
export SHEARPROBE_ROOT="$root"

device=${SHEARPROBE_DEVICE:-iPhone3,1}
release=${SHEARPROBE_RELEASE:-6.1.3}
xmake=/opt/homebrew/bin/xmake

echo "run.sh: the prediction this run answers, printed so the log carries it verbatim"
sed 's/^/  | /' "$here/PREDICTION.md"
echo

"$xmake" f -c -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
"$xmake" emulate -d "$device" -r "$release" install > "$out/install.log" 2>&1

program=shear-probe
built=$(find "$here/build" -name "$program" -type f 2>/dev/null | head -1)

# THIS PROJECT'S IMAGE NAME, asked of xmake with the expression plugins/emulate/main.lua itself uses. NOT
# `2>/dev/null`: a silent xmake here would leave `owner` empty and the gate would report a missing image rather
# than the reason, which is the failure this script exists to prevent.
printf 'print("shearprobe-" .. hash.strhash32(os.projectdir()))\n' > "$out/owner.lua"
owner=$(cd "$here" && "$xmake" lua "$out/owner.lua" | head -1)
image=$(ls -d "$HOME"/.charon/emulator/images.noindex/"$owner" 2>/dev/null | head -1)
installed=""
if [ -n "$image" ]; then
  installed=$(ls "$image"/${device}_*/rootfs/usr/libexec/$program 2>/dev/null | head -1)
fi

uuid_of() {
  [ -f "$1" ] || { echo "(no file)"; return; }
  /usr/bin/otool -l "$1" 2>/dev/null | awk '/cmd +LC_UUID/ { seen = 1; next } seen && $1 == "uuid" { print $2; exit }'
}

{
  printf 'project   %s\n' "$here"
  printf 'root      %s\n' "$root"
  printf 'image     %s\n' "${image:-NOT FOUND}"
  printf 'device    %s, release %s\n' "$device" "$release"
  printf 'built     %s\n' "${built:-NOT FOUND}"
  printf 'installed %s\n' "${installed:-NOT FOUND}"
  if [ -n "$built" ] && [ -n "$installed" ] && [ -f "$installed" ]; then
    ua=$(uuid_of "$built"); ub=$(uuid_of "$installed")
    printf 'built     LC_UUID %s\n' "$ua"
    printf 'installed LC_UUID %s\n' "$ub"
    printf 'built     mtime   %s\n' "$(stat -f %m "$built")"
    printf 'installed mtime   %s\n' "$(stat -f %m "$installed")"
    if [ "$ua" = "$ub" ] && [ -n "$ua" ] && [ "$ua" != "(no file)" ]; then
      printf 'the two carry the same LC_UUID, so this image holds this build\n'
      printf 'HASHES MATCH\n'
    else
      printf 'the two carry different LC_UUIDs, so the image holds a program from another build\n'
      printf 'HASHES MISMATCH\n'
    fi
  else
    printf 'one of the two is missing, so the run is NOT going ahead\n'
    printf 'HASHES MISMATCH\n'
  fi
} > "$out/hash.txt" 2>&1
grep -q "HASHES MATCH" "$out/hash.txt" || { cat "$out/hash.txt"; exit 1; }
cat "$out/hash.txt"

# The imports check the other working models run: every non-weak import of the armv7 slices of this binary must
# resolve against the release's own exports. A probe that cannot call the release is not a measurement.
/usr/bin/otool -L "$installed" 2>/dev/null | sed 's/^/  link  /' || true

echo
echo "run.sh: the gate is green; the guest run is $here/run-guest.sh"
if [ "${SHEARPROBE_GATE_ONLY:-0}" = "1" ]; then
  echo "run.sh: SHEARPROBE_GATE_ONLY=1, stopping before the emulator run"
  exit 0
fi
sh "$here/run-guest.sh"