#!/bin/sh
# run.sh - the host differential of SKUniform (iOS 8), and the control that says it can fail.
#
# differential.m is built twice from one source: against the host's own SpriteKit framework (the oracle), and against
# the port's SpriteKit8.o with no SpriteKit framework linked. Both print the same scenarios, and the two outputs must
# be identical byte for byte. The class is reached through the runtime only, so the two builds differ in nothing but
# the class behind the name.
#
# The control is the same differential linked against a copy of SpriteKit8.m in which setFloatValue no longer moves a
# None uniform to the Float type, which the host does. The run passes only when the port matches the host and the
# control's output differs: a comparison that cannot tell the mutated class from the host proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
src=${SPRITEKIT_SRC:-$root/packages/a/apple-backports/SpriteKit}
build=${SPRITEKIT_UNIFORM_BUILD:-$root/.agent-work/runs/spritekit-uniform}
rm -rf "$build"
mkdir -p "$build/control"

xcrun clang -fobjc-arc -framework Foundation -framework SpriteKit "$here/differential.m" -o "$build/oracle"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I "$src" -c "$src/SpriteKit8.m" -o "$build/port.o"
xcrun clang -fobjc-arc -framework Foundation "$here/differential.m" "$build/port.o" -o "$build/differential-port"

# The control: the same file with the None-to-Float rule of setFloatValue removed.
sed '/^- (void)setFloatValue:/,/^}/ s|if (_uniformType == SKUniformTypeNone) {|if (0) {|' "$src/SpriteKit8.m" > "$build/control/SpriteKit8.m"
cmp -s "$src/SpriteKit8.m" "$build/control/SpriteKit8.m" && { echo "FAIL the control mutation did not apply"; exit 1; }
xcrun clang -fobjc-arc -I "$src" -c "$build/control/SpriteKit8.m" -o "$build/control.o"
xcrun clang -fobjc-arc -framework Foundation "$here/differential.m" "$build/control.o" -o "$build/differential-control"

status=0
"$build/oracle" > "$build/log-host" 2>&1 || status=1
"$build/differential-port" > "$build/log-port" 2>&1 || status=1
"$build/differential-control" > "$build/log-control" 2>&1 || status=1

if cmp -s "$build/log-host" "$build/log-port"; then
    echo "ok SKUniform port matches the host: $(wc -l < "$build/log-host" | tr -d ' ') lines"
else
    echo "FAIL SKUniform port differs from the host:"
    diff "$build/log-host" "$build/log-port" || status=1
fi
# The control must run to the end and print every line the host prints: a control that crashed early would differ
# from the host too, and that difference would prove nothing about the rule it mutates.
if [ "$(wc -l < "$build/log-control")" -ne "$(wc -l < "$build/log-host")" ]; then
    echo "FAIL the control did not print every scenario: its log is not comparable"
    status=1
elif cmp -s "$build/log-host" "$build/log-control"; then
    echo "FAIL the control matched the host: the differential cannot tell the mutated class apart"
    status=1
else
    echo "control differs from the host (must): $(diff "$build/log-host" "$build/log-control" | grep -c '^>') line(s)"
fi
echo "logs=$build"
exit $status
