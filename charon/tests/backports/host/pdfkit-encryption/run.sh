#!/bin/sh
# PDFDocument's encryption members (isEncrypted, isLocked) and -unlockWithPassword: against the host's own
# PDFKit, on three PDFs this harness writes with CGPDFContext's own encryption.
#
# The same source, probe.m, is built twice: against the host's PDFKit, and against the port's own
# CharonPDFKit.h with -DCHARON_PORT and the port's objects. Each side prints one key=value line per fact,
# and the two outputs must be identical. A planted control - a copy of the port in which isLocked answers
# NO - must make the same comparison go red, or the comparison proves nothing.
#
# No python anywhere in this harness: the fixtures come from make-encrypted.m, and the comparison is diff.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/PDFKit
build=${BUILD:-$tree/.agent-work/runs/pdfkit-encryption}
mkdir -p "$build/fixtures"

xcrun clang -fobjc-arc -Wall "$here/make-encrypted.m" -framework Foundation -framework CoreGraphics \
    -o "$build/make-encrypted" 2> "$build/make.log" || {
    echo "BUILD the fixture writer did not compile:"; head -6 "$build/make.log" | sed 's/^/    /'; exit 1; }
"$build/make-encrypted" "$build/fixtures" > "$build/make.txt"
for name in plain.pdf owner-only.pdf user-locked.pdf; do
    grep -q "^$name written$" "$build/make.txt" || { echo "the fixture $name was not written"; exit 1; }
done

# side A: the host's PDFKit, and nothing from the port
xcrun clang -fobjc-arc -Wall "$here/probe.m" -framework Foundation -framework PDFKit \
    -o "$build/host-side" 2> "$build/host.log" || {
    echo "BUILD the host side did not compile:"; head -8 "$build/host.log" | sed 's/^/    /'; exit 1; }

# side B: the port's PDFDocument and everything it links, with no macOS PDFKit anywhere in the process
port_objects="$port/PDFDocument11.m $port/PDFPage11.m $port/PDFView11.m $port/PDFAnnotation11.m
    $port/PDFBorder11.m $port/PDFAppearanceCharacteristics11.m $port/PDFDestination11.m $port/PDFAction11.m
    $port/PDFOutline11.m $port/PDFPageText11.m $port/PDFSelection11.m $port/Base14Widths11.m
    $port/PDFKitConstants11.m"
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation -DCHARON_PORT -I "$port" "$here/probe.m" \
    $port_objects -framework Foundation -framework CoreGraphics -o "$build/port-side" 2> "$build/port.log" || {
    echo "BUILD the port side did not compile:"; head -8 "$build/port.log" | sed 's/^/    /'; exit 1; }

# the planted control: the same port with isLocked answering NO, in a scratch copy of the directory
rm -rf "$build/mutant"
mkdir -p "$build/mutant"
cp -R "$port" "$build/mutant/PDFKit"
sed 's/!CGPDFDocumentIsUnlocked(_document)/NO/' "$build/mutant/PDFKit/PDFDocument11.m" > "$build/mutant/PDFDocument11.m.new"
mv "$build/mutant/PDFDocument11.m.new" "$build/mutant/PDFKit/PDFDocument11.m"
mutant="$build/mutant/PDFKit"
mutant_objects="$mutant/PDFDocument11.m $mutant/PDFPage11.m $mutant/PDFView11.m $mutant/PDFAnnotation11.m
    $mutant/PDFBorder11.m $mutant/PDFAppearanceCharacteristics11.m $mutant/PDFDestination11.m $mutant/PDFAction11.m
    $mutant/PDFOutline11.m $mutant/PDFPageText11.m $mutant/PDFSelection11.m $mutant/Base14Widths11.m
    $mutant/PDFKitConstants11.m"
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation -DCHARON_PORT -I "$mutant" "$here/probe.m" \
    $mutant_objects -framework Foundation -framework CoreGraphics -o "$build/mutant-side" 2> "$build/mutant.log" || {
    echo "BUILD the planted control did not compile:"; head -8 "$build/mutant.log" | sed 's/^/    /'; exit 1; }

set +e
"$build/host-side" "$build"/fixtures/plain.pdf "$build"/fixtures/owner-only.pdf "$build"/fixtures/user-locked.pdf > "$build/host.txt" 2>&1; hoststatus=$?
"$build/port-side" "$build"/fixtures/plain.pdf "$build"/fixtures/owner-only.pdf "$build"/fixtures/user-locked.pdf > "$build/port.txt" 2>&1; portstatus=$?
"$build/mutant-side" "$build"/fixtures/plain.pdf "$build"/fixtures/owner-only.pdf "$build"/fixtures/user-locked.pdf > "$build/mutant.txt" 2>&1; mutantstatus=$?
set -e
if [ "$hoststatus" -ne 0 ] || [ "$portstatus" -ne 0 ] || [ "$mutantstatus" -ne 0 ]; then
    echo "a side crashed: host=$hoststatus port=$portstatus mutant=$mutantstatus - a crash is not a verdict"
    exit 1
fi

# the fixtures must say what they were written to say, on the HOST, or the comparison is over the wrong files
grep -qx 'user-locked.pdf.opened.isEncrypted=1' "$build/host.txt" || { echo "the user-locked fixture is not encrypted on the host"; exit 1; }
grep -qx 'user-locked.pdf.opened.isLocked=1' "$build/host.txt" || { echo "the user-locked fixture is not locked on the host"; exit 1; }
grep -qx 'owner-only.pdf.opened.isLocked=0' "$build/host.txt" || { echo "the owner-only fixture is locked on the host"; exit 1; }
grep -qx 'plain.pdf.opened.isEncrypted=0' "$build/host.txt" || { echo "the plain fixture is encrypted on the host"; exit 1; }

if ! diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "the port and the host disagree (first lines):"; head -10 "$build/diff.txt" | sed 's/^/    /'; exit 1
fi
echo "COMPARED $(wc -l < "$build/host.txt" | tr -d ' ') facts, all equal to the host"

# the control must go red: a difference that is not there would prove the comparison is decorative
if diff "$build/host.txt" "$build/mutant.txt" > "$build/mutant-diff.txt"; then
    echo "RED CONTROL FAILED: the planted port answers exactly as the host, so the comparison is blind"; exit 1
fi
echo "RED CONTROL ok: the planted isLocked goes red, $(grep -c '^[<>]' "$build/mutant-diff.txt") lines differ"
