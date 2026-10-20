#!/bin/sh
# run.sh - the host differential of SKTexture and SKSpriteNode of iOS 7, and the control that says it can fail, and the
# crash cases of the two classes, one process per case.
#
# differential.m is built twice from one source: against the host's own SpriteKit framework (the oracle), and against the
# port's SpriteKit7.o, SpriteKitTexture7.o and SpriteKitSprite7.o, with no SpriteKit framework linked. The stdout of the
# two runs must be identical line by line.
#
# The control is the same differential linked against a copy of SpriteKitSprite7.m in which the default anchor point is
# moved. The run passes only when the port matches the host and the control's output differs.
#
# crash.m is built the same two ways. Each case runs in its own process. Where the host exits with an exception or a
# return, the port's stdout and exit status must match it, so the exception's name and reason are compared. Where the host
# is killed by a signal, the port must be killed by the same signal (status 128 plus the signal), in the same kind of
# nil dereference; the host's crash is measured in facts/SpriteKit/SKTexture.md.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
src=${SPRITEKIT_SRC:-$root/packages/frameworks/apple-backports/SpriteKit}
build=${SPRITEKIT_SPRITE_BUILD:-$(runs_folder spritekit-sprite)}
rm -rf "$build"
mkdir -p "$build/control"

xcrun clang -fobjc-arc -framework Foundation -framework AppKit -framework SpriteKit "$here/differential.m" -o "$build/oracle"
xcrun clang -fobjc-arc -framework Foundation -framework AppKit -framework SpriteKit "$here/crash.m" -o "$build/crash-oracle"
for object in SpriteKit7 SpriteKitTexture7 SpriteKitSprite7; do
    xcrun clang -fobjc-arc -Wall -Wextra -Werror -I "$src" -c "$src/$object.m" -o "$build/$object.o"
done
xcrun clang -fobjc-arc -framework Foundation -framework AppKit "$here/differential.m" \
    "$build/SpriteKit7.o" "$build/SpriteKitTexture7.o" "$build/SpriteKitSprite7.o" -o "$build/differential-port"
xcrun clang -fobjc-arc -framework Foundation -framework AppKit "$here/crash.m" \
    "$build/SpriteKit7.o" "$build/SpriteKitTexture7.o" "$build/SpriteKitSprite7.o" -o "$build/crash-port"

# The control: the default anchor point of a sprite moved to x = 0.25, in both initialisers.
sed 's|CGPointMake(0.5, 0.5)|CGPointMake(0.25, 0.5)|' "$src/SpriteKitSprite7.m" > "$build/control/SpriteKitSprite7.m"
cmp -s "$src/SpriteKitSprite7.m" "$build/control/SpriteKitSprite7.m" && { echo "FAIL the control mutation did not apply"; exit 1; }
xcrun clang -fobjc-arc -I "$src" -c "$build/control/SpriteKitSprite7.m" -o "$build/control-sprite.o"
xcrun clang -fobjc-arc -framework Foundation -framework AppKit "$here/differential.m" \
    "$build/SpriteKit7.o" "$build/SpriteKitTexture7.o" "$build/control-sprite.o" -o "$build/differential-control"

status=0
"$build/oracle" > "$build/log-host" 2> "$build/err-host" || status=1
"$build/differential-port" > "$build/log-port" 2> "$build/err-port" || status=1
"$build/differential-control" > "$build/log-control" 2> "$build/err-control" || status=1

if cmp -s "$build/log-host" "$build/log-port"; then
    echo "ok SKTexture and SKSpriteNode port match the host: $(wc -l < "$build/log-host" | tr -d ' ') lines"
else
    echo "FAIL the port differs from the host:"
    diff "$build/log-host" "$build/log-port" || status=1
fi
if [ "$(wc -l < "$build/log-control")" -ne "$(wc -l < "$build/log-host")" ]; then
    echo "FAIL the control did not print every line: its log is not comparable"
    status=1
elif cmp -s "$build/log-host" "$build/log-control"; then
    echo "FAIL the control matched the host: the differential cannot tell the mutated anchor apart"
    status=1
else
    echo "control differs from the host (must): $(diff "$build/log-host" "$build/log-control" | grep -c '^>') line(s)"
fi

# The crash cases, one process each.
cases="rect-nil-base data-short data-nil sprite-neg-color sprite-neg-texture-size sprite-neg-init tex-color-neg tex-size-zero-height copy-mip"
signalled=0
checked=0
for case in $cases; do
    "$build/crash-oracle" "$case" > "$build/crash-host-$case" 2> /dev/null && hstatus=0 || hstatus=$?
    "$build/crash-port" "$case" > "$build/crash-port-$case" 2> /dev/null && pstatus=0 || pstatus=$?
    checked=$((checked + 1))
    if [ "$hstatus" -gt 128 ]; then
        signalled=$((signalled + 1))
        if [ "$pstatus" -ne "$hstatus" ]; then
            echo "FAIL $case: the host is killed by a signal (status $hstatus) and the port exits $pstatus"
            status=1
        else
            echo "ok $case: host and port killed by the same signal (status $hstatus)"
        fi
    elif [ "$hstatus" -ne "$pstatus" ] || ! cmp -s "$build/crash-host-$case" "$build/crash-port-$case"; then
        echo "FAIL $case: host status $hstatus, port status $pstatus"
        diff "$build/crash-host-$case" "$build/crash-port-$case" || true
        status=1
    else
        echo "ok $case: $(tr '\n' ' ' < "$build/crash-host-$case" | cut -c1-150)"
    fi
done
echo "crash cases: $checked run, $signalled where the host is killed by a signal"
echo "logs=$build"
exit $status
