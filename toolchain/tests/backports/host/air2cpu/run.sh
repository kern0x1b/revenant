#!/bin/sh
# run.sh - the entry point the host sweep looks for, and the liveness and completeness question it asks.
#
# compare.sh is the differential and needs no wrapper of its own: it is run.sh here. What this adds is
# what the sweep cannot get from compare.sh alone, and it is only on the failure path, because a run
# that works must not pay for it:
#
#   * when the oracle's dynamic-library step refuses, the run says WHICH of the fixture's kernels
#     Apple's own compiler will not link, measured one kernel at a time by link-probe.m. compare.sh
#     can only say that the whole file did not come out, and a reader is left with no cause.
#
# Every line printed here starts with ok/FAIL/note so run-all.sh reads this test as alive: a test whose
# run.sh says nothing before it stops is DEAD as far as the sweep is concerned, whatever it printed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/air2cpu/run.sh}

if sh "$here/compare.sh"; then
    echo "ok   the differential is complete: Apple's answer and the port's, kernel for kernel"
    exit 0
fi

# The differential did not finish, so name the cause. The fixture is split by kernel and each part is
# asked for a dynamic library on its own: the step that refuses is the same one, so a part that links
# and a part that does not separates what the whole file could not say.
echo "note the differential did not finish; probing the fixture one kernel at a time"
probe=$work/link-probe
mkdir -p "$work/kernels"
rm -rf "$work/kernels"
mkdir -p "$work/kernels"
python3 - "$here/kernels.metal" "$work/kernels" <<'PY'
import os, re, sys
source, out = sys.argv[1], sys.argv[2]
lines = open(source).read().split('\n')
starts = [index for index, line in enumerate(lines) if line.startswith('kernel void ')]
prologue = '\n'.join(lines[:starts[0]])
for number, index in enumerate(starts):
    end = starts[number + 1] if number + 1 < len(starts) else len(lines)
    top = index
    while top > 0 and (lines[top - 1].startswith('//') or lines[top - 1].strip() == ''):
        top -= 1
    name = re.match(r'kernel void (\w+)', lines[index]).group(1)
    open(os.path.join(out, '%02d-%s.metal' % (number, name)), 'w').write(
        prologue + '\n' + '\n'.join(lines[top:end]) + '\n')
print('note %d kernels split out of the fixture' % len(starts))
PY
xcrun clang -fobjc-arc -Wno-deprecated-declarations "$here/link-probe.m" -framework Metal -framework Foundation -o "$probe"
linked=0
refused=0
for kernel in "$work"/kernels/*.metal; do
    line=$("$probe" "$kernel" | tail -1)
    printf '%s\n' "$line"
    case "$line" in
        ok*) linked=$((linked + 1)) ;;
        *) refused=$((refused + 1)) ;;
    esac
done
echo "note $linked kernel(s) linked, $refused did not, one at a time"
if [ "$refused" != 0 ]; then
    echo "FAIL Apple's own compiler will not link $refused of the fixture's kernels, so there is no"
    echo "     Apple answer for those and the differential cannot compare them. The lines above name"
    echo "     them; the kernel source is tests/backports/host/air2cpu/kernels.metal."
fi
exit 1