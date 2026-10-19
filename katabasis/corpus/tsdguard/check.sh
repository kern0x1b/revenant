#!/bin/sh
# check.sh -- corpus/tsdguard: proves runtime/xl_tsd_guard.h's page-protection scheme (the
# runtime half of coordination/crutches.md's TPIDRRO_EL0 entry) on the build host. mmap, mprotect
# and SIGSEGV are POSIX: no device, no lift, no translate.sh needed -- this compiles main.c
# against the exact host architecture running the test and runs it directly.
#
# This proves the arithmetic at THIS MACHINE's page size (main.c now prints it: 16384 on Apple
# Silicon, where this is normally run) -- xl_tsd_guard.h's own comment on why sysconf-genericity,
# not a matching-granularity run, is what stands behind the 4 KiB device case; round 12 builds and
# runs this same main.c for armv7 and pushes it to the actual device for that measurement instead
# of only reasoning about it (coordination/reviews/2026-09-27-katabasis-2afe24d.md).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/out}
mkdir -p "$out"
cc -O0 -Wall -o "$out/tsdguard" "$here/main.c"
# main.c bounds itself (each check forks, with its own alarm() plus a parent-side bounded wait and
# SIGKILL fallback -- see its own header comment on why, after a real hang on device). This outer
# `timeout` is a second, independent belt: if THIS wrapper ever fires, that is itself a finding
# (main.c's own bounding failed), not silently a slow machine.
if command -v timeout >/dev/null 2>&1; then
  timeout 60 "$out/tsdguard"
else
  "$out/tsdguard"
fi
