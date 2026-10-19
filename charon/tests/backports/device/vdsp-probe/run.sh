#!/bin/sh
# The probe on the emulated iPhone3,1 6.1.3 (10B329) guest, through heavy.sh. The log is the deliverable:
# the release's own vDSP against this band's kernel, on the target's own arithmetic.
#
# VDSPPROBE_DEVICE and VDSPPROBE_RELEASE name the device and the release, and both the install and the run
# are given them, so the program cannot be installed into one image and run in another.
#
# **The hash check is the point of this script, not a nicety in it.** `xmake emulate install` has been observed
# reporting "installing .. install ok!" and leaving the image's copy of the program unchanged, so a guest run
# has been executing a binary two edits old and reporting its output as a result. Every run now compares the
# built binary against the one in the image's rootfs and stops if they differ. A run that does not happen is
# better than a run that reports the wrong binary's answers, and a silent stale run is worse than both.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${VDSPPROBE_ROOT:-$(cd "$here/../../../.." && pwd)}
out="$here/run"
mkdir -p "$out"
cd "$here"
export VDSPPROBE_ROOT="$root"

# **iPhone3,1 is the device this run uses, and it is asked for.** The default device of the emulate command is
# the first catalog device of the architecture, an iPhone2,1, and this project's image for it no longer
# installs; iPhone3,1 at 6.1.3 has a golden image in ~/.charon/emulator today. Both the install and the run
# take the same -d and -r, or the program is installed into one image and run in another.
device=${VDSPPROBE_DEVICE:-iPhone3,1}
release=${VDSPPROBE_RELEASE:-6.1.3}

/opt/homebrew/bin/xmake f -c -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
/opt/homebrew/bin/xmake emulate -d "$device" -r "$release" install > "$out/install.log" 2>&1

program=vdsp-biquad-probe
built=$(find "$here/build" -name "$program" -type f 2>/dev/null | head -1)
image=$(ls -d "$HOME"/.charon/emulator/images.noindex/vdspprobe-* 2>/dev/null | head -1)
# The image directory is named for the device and its build, so it is globbed rather than spelled: a spelled
# one that names another device would compare this build against a program that was never installed here.
installed=$(ls "$image"/${device}_*/rootfs/usr/libexec/$program 2>/dev/null | head -1)

# **LC_UUID, not a byte hash, and that is 7e035ac0's rule rather than mine.** A hash of the bytes before the
# code signature cannot prove provenance: strip rewrites those bytes, and an unsigned build has no bytes there
# at all, so the "before" region of one is empty. Neither strip nor ldid -S changes LC_UUID, so the UUID is
# what identifies a build. It is read through `otool -l` rather than parsed by hand, because Charon's ld64
# writes the magic byte-swapped and a hand-rolled reader would have to know that.
uuid_of() {
  [ -f "$1" ] || { echo "(no file)"; return; }
  /usr/bin/otool -l "$1" 2>/dev/null | awk '/cmd +LC_UUID/ { seen = 1; next } seen && $1 == "uuid" { print $2; exit }'
}

{
  printf 'device    %s, release %s\n' "$device" "$release"
  printf 'built     %s\n' "${built:-NOT FOUND}"
  printf 'installed %s\n' "${installed:-NOT FOUND}"
  if [ -n "$built" ] && [ -f "$installed" ]; then
    ua=$(uuid_of "$built"); ub=$(uuid_of "$installed")
    printf 'built     LC_UUID %s\n' "$ua"
    printf 'installed LC_UUID %s\n' "$ub"
    printf 'built     mtime   %s\n' "$(stat -f %m "$built")"
    printf 'installed mtime   %s\n' "$(stat -f %m "$installed")"
    # **The LC_UUID is the gate and the mtime is only printed.** The two rules were joined by an `elif` on
    # the timestamps, and this rootfs does not keep them: measured on the iPhone3,1 6.1.3 image of
    # 2026-10-03, the installed copy reads `mtime 0` while the build it came from reads a real time, so the
    # mtime test refused a run whose two LC_UUIDs were the same value -
    # `507BFF79-1BC5-3C33-83DD-A67F6D9E9138` on both sides - and a stale run is exactly what this script
    # exists to prevent, so a rule that stops the good run without ever identifying a bad one is worse than
    # no rule. The image's rootfs is cloned from a golden image and the placed file carries no timestamp of
    # its own; the UUID is what identifies a build, as the comment above says, and neither strip nor
    # `ldid -S` changes it.
    if [ "$ua" = "$ub" ] && [ -n "$ua" ] && [ "$ua" != "(no file)" ]; then
      printf 'the two carry the same LC_UUID, so the image holds this build\n'
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

/opt/homebrew/bin/xmake emulate -d "$device" -r "$release" -t 900 -s 300 run "/usr/libexec/$program" > "$out/run.log" 2>&1 || true
/opt/homebrew/bin/xmake emulate log > "$out/guest.log" 2>&1 || true
