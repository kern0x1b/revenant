#!/bin/sh
# run.sh - the host differential of the SKNode tree (iOS 7, with its iOS 8 subscript and iOS 9 move), and the control
# that says it can fail.
#
# differential.m is built twice from one source: against the host's own SpriteKit framework (the oracle), and against
# the port's SpriteKit7.o, SpriteKit8.o and SpriteKit9.o with no SpriteKit framework linked. Both print the same
# scenarios, and the two outputs must be identical line by line.
#
# The control is the same differential linked against a copy of SpriteKit7.m in which a name is matched exactly rather
# than as an fnmatch(3) pattern, which the host does. The run passes only when the port matches the host and the
# control's output differs: a comparison that cannot tell the mutated class from the host proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
src=${SPRITEKIT_SRC:-$root/packages/a/apple-backports/SpriteKit}
build=${SPRITEKIT_NODE_BUILD:-$(runs_folder spritekit-node)}
rm -rf "$build"
mkdir -p "$build/control"

xcrun clang -fobjc-arc -framework Foundation -framework SpriteKit "$here/differential.m" -o "$build/oracle"
for object in SpriteKit7 SpriteKit8 SpriteKit9; do
    xcrun clang -fobjc-arc -Wall -Wextra -Werror -I "$src" -c "$src/$object.m" -o "$build/$object.o"
done
xcrun clang -fobjc-arc -framework Foundation -framework CoreGraphics "$here/differential.m" \
    "$build/SpriteKit7.o" "$build/SpriteKit8.o" "$build/SpriteKit9.o" -o "$build/differential-port"
xcrun clang -fobjc-arc -framework Foundation -framework SpriteKit "$here/crash.m" -o "$build/crash-host"
xcrun clang -fobjc-arc -framework Foundation -framework CoreGraphics "$here/crash.m" \
    "$build/SpriteKit7.o" "$build/SpriteKit8.o" "$build/SpriteKit9.o" -o "$build/crash-port"

# The control: the same tree with the name matched exactly, which drops the glob and the single-character patterns.
sed 's|return name != nil \&\& fnmatch(\[pattern UTF8String\], \[name UTF8String\], 0) == 0;|return name != nil \&\& [name isEqualToString:pattern];|' "$src/SpriteKit7.m" > "$build/control/SpriteKit7.m"
cmp -s "$src/SpriteKit7.m" "$build/control/SpriteKit7.m" && { echo "FAIL the control mutation did not apply"; exit 1; }
xcrun clang -fobjc-arc -I "$src" -c "$build/control/SpriteKit7.m" -o "$build/control7.o"
xcrun clang -fobjc-arc -framework Foundation -framework CoreGraphics "$here/differential.m" \
    "$build/control7.o" "$build/SpriteKit8.o" "$build/SpriteKit9.o" -o "$build/differential-control"

status=0
"$build/oracle" > "$build/log-host" 2>&1 || status=1
"$build/differential-port" > "$build/log-port" 2>&1 || status=1
"$build/differential-control" > "$build/log-control" 2>&1 || status=1

if cmp -s "$build/log-host" "$build/log-port"; then
    echo "ok SKNode port matches the host: $(wc -l < "$build/log-host" | tr -d ' ') lines"
else
    echo "FAIL SKNode port differs from the host:"
    diff "$build/log-host" "$build/log-port" || status=1
fi
# The control must run to the end and print every line the host prints: a control that crashed early would differ from
# the host too, and that difference would prove nothing about the rule it mutates.
if [ "$(wc -l < "$build/log-control")" -ne "$(wc -l < "$build/log-host")" ]; then
    echo "FAIL the control did not print every scenario: its log is not comparable"
    status=1
elif cmp -s "$build/log-host" "$build/log-control"; then
    echo "FAIL the control matched the host: the differential cannot tell the mutated class apart"
    status=1
else
    echo "control differs from the host (must): $(diff "$build/log-host" "$build/log-control" | grep -c '^>') line(s)"
fi
# The crash cases, one child process per case: crash.m runs a single case and the shell starts it fresh each time, so a
# crash ends only that case. Where the host answers, the port's output line and exit status must match the host's. Where
# the host is killed by a signal, the port must not be: it must exit normally and say what it did (an answer or an
# exception), since the host has no answer to match.
crash_cases="childNodeWithName-nil childNodeWithName-empty subscript-nil subscript-empty enumerate-nil insert-nil insert-nil-described insert-at-count insert-index-2 insert-index-65535 insert-index-2147483647 insert-index-2147483648 insert-index-4294967294 insert-index-4294967295 insert-index-9223372036854775807"
crashes=0
for case in $crash_cases; do
    "$build/crash-host" "$case" > "$build/crash-host-$case.log" 2>&1 && host_status=0 || host_status=$?
    "$build/crash-port" "$case" > "$build/crash-port-$case.log" 2>&1 && port_status=0 || port_status=$?
    if [ "$host_status" -gt 128 ]; then
        crashes=$((crashes + 1))
        if [ "$port_status" -eq 0 ]; then
            echo "ok $case: host killed by signal $((host_status - 128)), port answers: $(cat "$build/crash-port-$case.log")"
        else
            echo "FAIL $case: port killed by status $port_status where the host is killed by signal $((host_status - 128))"
            status=1
        fi
    elif cmp -s "$build/crash-host-$case.log" "$build/crash-port-$case.log" && [ "$host_status" -eq "$port_status" ]; then
        echo "ok $case: $(cat "$build/crash-host-$case.log")"
    else
        echo "FAIL $case: host status $host_status, port status $port_status"
        diff "$build/crash-host-$case.log" "$build/crash-port-$case.log" || true
        status=1
    fi
done
echo "crash cases: $(echo $crash_cases | wc -w | tr -d ' ') run, $crashes where the host is killed by a signal"
echo "logs=$build"
exit $status
