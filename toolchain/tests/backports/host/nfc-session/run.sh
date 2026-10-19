#!/bin/sh
# run.sh - the CoreNFC reader sessions, asked the same questions on the host (Catalyst's CoreNFC) and on the port's classes, from one
# probe source (probe.m). The port's objects are CoreNFC/NFCReaderSession.m, built here with its classes renamed RevenantHost<Name>
# so they link beside nothing; the probe finds them by that prefix.
#
# The host is held to expected.txt, the golden answer. The port must answer every line the host does. The plant: a port whose
# unsupported-feature error is NFCReaderErrorRadioDisabled (14) instead of NFCReaderErrorUnsupportedFeature (1). Its diff against
# the host must be non-empty, or the comparison cannot fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
P=${PORT_DIR:-$here/../../../../packages/a/apple-backports}
build=${NFC_SESSION_BUILD:-$(runs_fresh revenant-nfc-session)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="$target -fobjc-arc -fvisibility=hidden -w -DREVENANT_HOST_BUILD"
probe_flags="$target -fobjc-arc -fvisibility=hidden -w"
frameworks="-framework Foundation -framework CoreNFC"
source="$P/CoreNFC/NFCReaderSession.m"
mkdir -p "$build/plain" "$build/port" "$build/plant"

xcrun clang $probe_flags "$here/probe.m" $frameworks -o "$build/host"
"$build/host" > "$build/host.txt"
if ! diff -u "$here/expected.txt" "$build/host.txt"; then
    echo "FAIL: the host answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/host.txt" | tr -d ' ') host lines, the golden answer"

# The port's objects, compiled plain to read which classes they define, then under renamed symbols.
xcrun clang $flags -c "$source" -o "$build/plain/NFCReaderSession.o"
renames=""
for name in $(xcrun nm -gU "$build/plain/NFCReaderSession.o" | awk 'NF == 3 {print $3}' | grep -E '^_OBJC_CLASS_\$_' | sed -e 's/^_OBJC_CLASS_\$_//' | sort -u); do
    renames="$renames -D$name=RevenantHost$name"
done
xcrun clang $flags $renames -c "$source" -o "$build/port/NFCReaderSession.o"
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build/port/NFCReaderSession.o" -framework Foundation -o "$build/port-probe"
"$build/port-probe" > "$build/port.txt"
if ! diff -u "$build/host.txt" "$build/port.txt"; then
    echo "FAIL: the port answers differently from the host (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/port.txt" | tr -d ' ') lines alike, the port's sessions answer as the host's"

# The plant: the port's error code is RadioDisabled (14), not UnsupportedFeature (1), in the callback a begun session makes.
sed 's/code:NFCReaderErrorUnsupportedFeature userInfo/code:NFCReaderErrorRadioDisabled userInfo/' "$source" > "$build/plant/plant-NFCReaderSession.m"
if cmp -s "$source" "$build/plant/plant-NFCReaderSession.m"; then
    echo "FAIL: the plant edit changed nothing, so the plant is not a plant"
    exit 1
fi
xcrun clang $flags $renames -c "$build/plant/plant-NFCReaderSession.m" -o "$build/plant/NFCReaderSession.o"
xcrun clang $probe_flags -DPORT "$here/probe.m" "$build/plant/NFCReaderSession.o" -framework Foundation -o "$build/plant-probe"
status=0
"$build/plant-probe" > "$build/plant.txt" || status=$?
if [ "$status" -ne 0 ]; then
    echo "PLANT: the planted port stopped with status $status, which differs from the host, as it must"
    exit 0
fi
if diff -q "$build/host.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the planted port agrees with the host, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the planted port differs from the host, as it must"
