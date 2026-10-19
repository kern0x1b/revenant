#!/bin/sh
# The probe on the emulator at 6.1.3, through heavy.sh's slow lane. The log is the deliverable:
# facts/AVFAudio/AVAudioUnitSampler.md pastes it verbatim.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${SAMPLERPROBE_ROOT:-$(cd "$here/../../../.." && pwd)}
out="$here/run"
mkdir -p "$out"
cd "$here"
export SAMPLERPROBE_ROOT="$root"
/opt/homebrew/bin/xmake f -p iphoneos -a armv7 -y > "$out/configure.log" 2>&1
/opt/homebrew/bin/xmake emulate install > "$out/install.log" 2>&1
# /usr/libexec, not /usr/bin: that is where the package's program lands. Asking for /usr/bin made
# the emulate run fail with "spawn error 2" - ENOENT for a path the install never created - after a
# boot that had otherwise worked, which is the third time this probe's own setup rather than the
# emulator has been what stopped it.
#
# The emulate run reads the project's control file, which xmake.lua names with set_values; without it
# the run stops with "cannot open file: .../control" and the guest is never reached, which is what the
# first six attempts of this probe did.
/opt/homebrew/bin/xmake emulate -t 900 -s 300 run /usr/libexec/sampler-probe > "$out/run.log" 2>&1
/opt/homebrew/bin/xmake emulate log > "$out/guest.log" 2>&1 || true
printf 'exit=%s\n' "$?" >> "$out/run.log"
