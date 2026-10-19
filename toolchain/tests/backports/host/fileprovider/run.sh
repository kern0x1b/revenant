#!/bin/sh
# The port's NSFileProviderManager.m against the host's own FileProvider, on the lines macOS
# offers, and the two answers diffed. The shape is tests/backports/host/appleblas/run.sh: the
# port's .m is compiled for the host with xcrun clang, its identifiers renamed so it does not
# collide with the framework that is also linked, and the probe is built twice - once against the
# framework, once against the port.
#
#   ./run.sh            the control: an empty diff is green
#   ./run.sh mutant     the port's -2001 changed to -1005, which must give one line of diff
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FP=${FILEPROVIDER:-$here/../../../../packages/a/apple-backports/FileProvider}
build=${FILEPROVIDER_BUILD:-$(runs_folder charon-fileprovider-host)}
rm -rf "$build"; mkdir -p "$build"

# The mutant, on a COPY: the port's source is never edited, and the diff names the line that
# changed rather than a working tree that has to be restored.
cp "$FP/NSFileProviderManager.m" "$build/port.m"
if [ "${1:-}" = "mutant" ]; then
    sed -i.bak 's/CharonFileProviderUnavailable = -2001/CharonFileProviderUnavailable = -1005/' "$build/port.m"
    rm -f "$build/port.m.bak"
    echo "MUTANT: the port's unavailable code is -1005, not the host's -2001"
fi

# The port, for the host: identifiers renamed, warnings down, and the port's own header for what
# the macOS SDK does not declare.
xcrun clang -fobjc-arc -w -Wno-unavailable-declarations \
    -DNSFileProviderManager=CharonFPManager -DNSFileProviderErrorDomain=CharonFPErrorDomain \
    -I"$FP" -c "$build/port.m" -o "$build/port.o"

# The probe, twice: against the framework, and against the port's renamed class.
xcrun clang -fobjc-arc -w -Wno-unavailable-declarations \
    "$here/differential.m" -framework Foundation -framework FileProvider -o "$build/host"
xcrun clang -fobjc-arc -w -Wno-unavailable-declarations -DCHARON_PORT=1 \
    "$here/differential.m" "$build/port.o" -framework Foundation -framework FileProvider -o "$build/port"

"$build/host" > "$build/host.tsv" 2>/dev/null || true
"$build/port" > "$build/port.tsv" 2>/dev/null || true
echo "--- host"; cat "$build/host.tsv"
echo "--- port"; cat "$build/port.tsv"
echo "--- diff host.tsv port.tsv"
if diff "$build/host.tsv" "$build/port.tsv" > "$build/diff"; then
    echo "VERDICT: green - the port answers what the host answers, on every line macOS offers"
    exit 0
fi
cat "$build/diff"
lines=$(wc -l < "$build/diff" | tr -d ' ')
echo "VERDICT: RED - $lines line(s) of diff"
exit 1
