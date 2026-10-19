#!/bin/sh
# run.sh - the document browser's behaviour check, in the name the sweep knows.
#
# behaviour.sh is the check: it runs the port's five methods on the host, breaks each behaviour once
# and watches the test name the break. It ends with "PASS: every behaviour runs, and every mutant
# is red by name", which the sweep's liveness pattern does read, but the directory had no run.sh, so
# the sweep passed it over as "no run.sh" - the blind spot the sweep exists to close.
#
# The counts here are read out of behaviour.sh's own transcript: one check for each "ok" line it
# printed, and the failing count from the verdict it ended with. A run that ends without its
# verdict is a FAIL rather than a pass.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=$("$here/behaviour.sh" 2>&1) && status=0 || status=$?
printf '%s\n' "$out"
checks=$(printf '%s\n' "$out" | grep -c ': ok ' || true)
case $out in
*"FAIL: a mutant was not caught"*) echo "checks=$checks failures=1"; exit 1 ;;
*"PASS: every behaviour runs"*)    echo "checks=$checks failures=0"; exit "$status" ;;
esac
echo "FAIL: behaviour.sh ended without the verdict of its own, so this run cannot be read as one"
exit 1
