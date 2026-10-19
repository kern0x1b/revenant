#!/bin/sh
# run.sh - the port's Metal 4 command chain on the emulated iPhone3,1 6.1.3 guest, through heavy.sh.
# The log is the deliverable.
#
# WHY iPhone3,1 6.1.3 AND NOT A HOST: the port's Metal 4 queue wraps the port's CharonMetalQueue, which
# holds an EAGL context over OpenGL ES 2.0, and OpenGLES/EAGL.h is a DEVICE framework - a host binary
# cannot compile the file at all. So Apple's side was measured on the host and written down in
# tests/backports/device/metalchain-expectations.h, and this is where the port meets it.
#
# **THE IMAGE IS FOUND BY THIS PROJECT'S OWN NAME, and a glob was wrong here.** `xmake emulate` names an
# image after the project directory: plugins/emulate/main.lua computes
# `(project.name() .. "-" .. hash.strhash32(os.projectdir()))`, so this project directory has ONE image
# name and asking xmake for it is the only way to name it. The first version globbed
# `images.noindex/metalchainprobe-*` and took the first hit, and that is wrong the moment a second copy
# of this project exists - v-metal's worktree holds `metalchainprobe-d6a40e29` (measured: `xmake lua` over
# that directory prints d6a40e29, which is the image on disk) and this worktree's directory hashes to
# something else. The gate then compares this build's LC_UUID against ANOTHER project's installed copy,
# reports a mismatch, and stops - safe, but the run never happens and the reason is in the script rather
# than in the port. No image is ever deleted here.
#
# **THE HASH CHECK IS THE POINT OF THIS SCRIPT, NOT A NICETY IN IT.** `xmake emulate install` has been
# observed reporting "installing .. install ok!" and leaving the image's copy of the program unchanged,
# so a guest run has executed a binary two edits old and reported its output as a result. Every run
# compares the built binary against the one in this image's rootfs and stops if they differ. A run that
# does not happen is better than a run that reports the wrong binary's answers, and a silent stale run is
# worse than both. The identity read is LC_UUID and not a byte hash, because that is 7e035ac0's rule: a
# hash of the bytes before the code signature cannot prove provenance - strip rewrites those bytes, and
# an unsigned build has none there at all - while neither strip nor ldid -S changes LC_UUID.
#
# **THE MTIMES ARE PRINTED AND NOT COMPARED**, which is vdsp-probe's measured correction and not a
# weakening: on the iPhone3,1 6.1.3 image of 2026-10-03 the installed copy reads `mtime 0` while the
# build it came from reads a real time, so an mtime gate refuses a run whose two LC_UUIDs are the same
# value, and a rule that stops the good run without ever identifying a bad one is worse than no rule.
#
# METALCHAINPROBE_DEVICE and METALCHAINPROBE_RELEASE name the device and the release, and BOTH the install
# and the run take them, so the program cannot be installed into one image and run in another. The
# default device of `xmake emulate` is the first catalog device of the architecture, an iPhone2,1, whose
# image installs; iPhone3,1 at 6.1.3 has a golden image in ~/.charon/emulator.
#
# `xmake emulate run` is given a BARE PATH: with arguments it answers "fail(spawn error 2)" even for a
# system binary (coordinator, measured on the v-crutch5 runs of 2026-10-04).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${METALCHAINPROBE_ROOT:-$(cd "$here/../../../.." && pwd)}
out="$here/run"
mkdir -p "$out"
cd "$here"
export METALCHAINPROBE_ROOT="$root"

device=${METALCHAINPROBE_DEVICE:-iPhone3,1}
release=${METALCHAINPROBE_RELEASE:-6.1.3}
xmake=/opt/homebrew/bin/xmake

# CONFIGURE, BUILD AND INSTALL RUN DIRECTLY, NOT THROUGH heavy.sh (coordinator, 2026-10-04): heavy.sh
# breaks this kind of project's `xmake f` with rc=255 and every package "not found". Only the emulator
# run below takes a slot.
"$xmake" f -c -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
"$xmake" emulate -d "$device" -r "$release" install > "$out/install.log" 2>&1

program=metalchain-probe
built=$(find "$here/build" -name "$program" -type f 2>/dev/null | head -1)

# THIS PROJECT'S IMAGE NAME, asked of xmake with the expression plugins/emulate/main.lua itself uses.
# NOT `2>/dev/null`: a silent xmake here would leave `owner` empty and the gate would then report a
# missing image rather than the reason, which is the failure mode this script exists to prevent.
printf 'print("metalchainprobe-" .. hash.strhash32(os.projectdir()))\n' > "$out/owner.lua"
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

# THE GUEST RUN IS THE ONLY HEAVY PART and it lives in run-guest.sh, which this calls. METALCHAINPROBE_GATE_ONLY=1
# stops here instead, for a caller that wants the guest run queued on its own through
# coordination/heavy.sh - which is what the coordinator asked for on 2026-10-04, after this whole script
# under heavy.sh came back "every package not found" from the configure.
if [ "${METALCHAINPROBE_GATE_ONLY:-0}" = "1" ]; then
  echo
  echo "run.sh: the gate is green; the guest run is $here/run-guest.sh"
  exit 0
fi
sh "$here/run-guest.sh"