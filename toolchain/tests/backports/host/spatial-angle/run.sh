#!/bin/sh
# run.sh - the host differential of the SPAngle functions (iOS 16), and the control that says it can fail.
#
# The port's Spatial16.m is linked into one program with the differential, and the host's own Spatial (the SDK's
# inline bodies, in oracle.c) is compiled alongside it. The differential compares every function's result bit for
# bit over one million generated inputs and every pair of the edge values (differential.c).
#
# The control is the same differential linked against a copy of Spatial16.m with one expression changed to the
# other ordering of the degrees conversion, which the measurement in facts/Spatial/SPAngle.md found differs from the
# host on many inputs. The run passes only when the port matches and the control is caught: a comparison that
# cannot tell a wrong expression from the right one proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
src=${SPATIAL_SRC:-$root/packages/frameworks/apple-backports/Spatial}
build=${SPATIAL_ANGLE_BUILD:-$(runs_folder spatial-angle)}
rm -rf "$build"
mkdir -p "$build/control"

xcrun clang -I "$src" -w -c "$src/Spatial16.m" -o "$build/port.o"
xcrun clang -w -c "$here/oracle.c" -o "$build/oracle.o"
xcrun clang -I "$src" -w -c "$here/differential.c" -o "$build/differential.o"
xcrun clang "$build/differential.o" "$build/oracle.o" "$build/port.o" -o "$build/differential-port"

# The control: the same file with the radians-to-degrees expression written the other way.
sed 's|angle.radians \* 180.0 / M_PI|angle.radians * (180.0 / M_PI)|' "$src/Spatial16.m" > "$build/control/Spatial16.m"
cmp -s "$src/Spatial16.m" "$build/control/Spatial16.m" && { echo "FAIL the control mutation did not apply"; exit 1; }
xcrun clang -I "$src" -w -c "$build/control/Spatial16.m" -o "$build/control.o"
xcrun clang "$build/differential.o" "$build/oracle.o" "$build/control.o" -o "$build/differential-control"

status=0
"$build/differential-port" > "$build/log-port" 2>&1 || status=1
control_status=0
"$build/differential-control" > "$build/log-control" 2>&1 || control_status=$?
if [ "$control_status" -eq 0 ]; then
    echo "FAIL the control passed: the differential cannot tell the other ordering from the host"
    status=1
fi
cat "$build/log-port"
echo "control (must fail):"
grep '^FAIL' "$build/log-control" || echo "(no FAIL line from the control)"
echo "logs=$build"
exit $status
