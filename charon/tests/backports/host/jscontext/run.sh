#!/bin/sh
# A differential: the same checks.m runs first against the host's own JavaScriptCore.framework,
# which ships JSContext, JSValue, JSManagedValue and JSVirtualMachine - the oracle every
# expectation in checks.m has to pass - and then against the backport. The backport's classes carry
# the names the host framework also exports, so its build renames them at compile time and links
# against the host's real JSGlobalContextRef, JSEvaluateScript and the rest of the C API without
# the two colliding. Each side holds itself to the checks; the lines it prints starting with
# "matrix" (blocks with C number and struct arguments against many values) are then diffed, side
# against side, and any difference fails the run.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/JavaScriptCore}
out=${BUILD:-$(runs_fresh charon-jscontext)}
xcrun clang -fobjc-arc -w -framework Foundation -framework JavaScriptCore -framework CoreGraphics "$here/checks.m" -o "$out/oracle"
echo "oracle: the host's JavaScriptCore"
"$out/oracle" > "$out/oracle.txt" || { cat "$out/oracle.txt"; exit 1; }
grep -v '^matrix ' "$out/oracle.txt"
renames=""
for name in JSContext JSValue JSManagedValue JSVirtualMachine; do
    renames="$renames -D$name=CharonHost$name"
done
objects=""
for source in JSInternal JSVirtualMachine JSContext JSValue JSManagedValue JSExportBridge JSCAPI; do
    xcrun clang -fobjc-arc -w $renames -I"$port" -c "$port/$source.m" -o "$out/$source.o"
    objects="$objects $out/$source.o"
done
xcrun clang -fobjc-arc -w -DCHARON_PORT -framework Foundation -framework JavaScriptCore -framework CoreGraphics $renames "$here/checks.m" $objects -o "$out/checks"
echo "backport"
"$out/checks" > "$out/checks.txt" || { cat "$out/checks.txt"; exit 1; }
grep -v '^matrix ' "$out/checks.txt"
grep '^matrix ' "$out/oracle.txt" > "$out/oracle.matrix"
grep '^matrix ' "$out/checks.txt" > "$out/checks.matrix"
if diff "$out/oracle.matrix" "$out/checks.matrix"; then
    echo "matrix: $(wc -l < "$out/checks.matrix" | tr -d ' ') lines, the same on both sides"
else
    echo "matrix: the backport differs from the oracle"
    exit 1
fi
