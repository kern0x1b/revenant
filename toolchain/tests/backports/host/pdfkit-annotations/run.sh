#!/bin/sh
# PDFAnnotation's hasAppearanceStream, open and URL against the host's own PDFKit, on eleven PDFs this harness
# writes byte by byte (make-annotations.m: CGPDFContext cannot put an annotation on a page).
#
# The same source, probe.m, is built twice: against the host's PDFKit, and against the port's own RevenantPDFKit.h
# with -DREVENANT_PORT and the port's objects. The two outputs must be identical. A planted control - a copy of
# the port in which /Open is read under the wrong key - must make the same comparison go red.
#
# No python anywhere in this harness: the fixtures come from make-annotations.m, and the comparison is diff.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/PDFKit
build=${BUILD:-$tree/.agent-work/runs/pdfkit-annotations}
mkdir -p "$build/fixtures"

xcrun clang -fobjc-arc -Wall "$here/make-annotations.m" -framework Foundation \
    -o "$build/make-annotations" 2> "$build/make.log" || {
    echo "BUILD the fixture writer did not compile:"; head -6 "$build/make.log" | sed 's/^/    /'; exit 1; }
rm -f "$build"/fixtures/*.pdf
"$build/make-annotations" "$build/fixtures" > "$build/make.txt"
for name in annot-square annot-ap annot-ap-down annot-uri annot-link-noa annot-open annot-open-no \
    annot-highlight annot-link-h annot-link-h-n annot-goto annot-gotor annot-launch annot-launch-spec \
    annot-launch-win annot-square-open annot-link-open annot-none; do
    grep -qx "$name.pdf written" "$build/make.txt" || { echo "the fixture $name.pdf was not written"; exit 1; }
done

# side A: the host's PDFKit, and nothing from the port
xcrun clang -fobjc-arc -Wall "$here/probe.m" -framework Foundation -framework PDFKit \
    -o "$build/host-side" 2> "$build/host.log" || {
    echo "BUILD the host side did not compile:"; head -8 "$build/host.log" | sed 's/^/    /'; exit 1; }

# side B: the port's objects and nothing from macOS PDFKit
port_objects="$port/PDFDocument11.m $port/PDFPage11.m $port/PDFView11.m $port/PDFAnnotation11.m
    $port/PDFBorder11.m $port/PDFAppearanceCharacteristics11.m $port/PDFDestination11.m $port/PDFAction11.m
    $port/PDFOutline11.m $port/PDFPageText11.m $port/PDFSelection11.m $port/Base14Widths11.m
    $port/PDFKitConstants11.m"
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation -DREVENANT_PORT -I "$port" "$here/probe.m" \
    $port_objects -framework Foundation -framework CoreGraphics -o "$build/port-side" 2> "$build/port.log" || {
    echo "BUILD the port side did not compile:"; head -8 "$build/port.log" | sed 's/^/    /'; exit 1; }

# the planted control: the port with /Open read under a key nothing writes
rm -rf "$build/mutant"
mkdir -p "$build/mutant"
cp -R "$port" "$build/mutant/PDFKit"
mutant="$build/mutant/PDFKit"
sed 's/"Open", &open/"Opened", \&open/' "$mutant/PDFAnnotation11.m" > "$build/mutant/PDFAnnotation11.m.new"
mv "$build/mutant/PDFAnnotation11.m.new" "$mutant/PDFAnnotation11.m"
grep -q '"Opened"' "$mutant/PDFAnnotation11.m" || { echo "the planted control did not change the source"; exit 1; }
mutant_objects="$mutant/PDFDocument11.m $mutant/PDFPage11.m $mutant/PDFView11.m $mutant/PDFAnnotation11.m
    $mutant/PDFBorder11.m $mutant/PDFAppearanceCharacteristics11.m $mutant/PDFDestination11.m $mutant/PDFAction11.m
    $mutant/PDFOutline11.m $mutant/PDFPageText11.m $mutant/PDFSelection11.m $mutant/Base14Widths11.m
    $mutant/PDFKitConstants11.m"
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation -DREVENANT_PORT -I "$mutant" "$here/probe.m" \
    $mutant_objects -framework Foundation -framework CoreGraphics -o "$build/mutant-side" 2> "$build/mutant.log" || {
    echo "BUILD the planted control did not compile:"; head -8 "$build/mutant.log" | sed 's/^/    /'; exit 1; }

set +e
"$build/host-side" "$build"/fixtures/*.pdf > "$build/host.txt" 2>&1; hoststatus=$?
"$build/port-side" "$build"/fixtures/*.pdf > "$build/port.txt" 2>&1; portstatus=$?
"$build/mutant-side" "$build"/fixtures/*.pdf > "$build/mutant.txt" 2>&1; mutantstatus=$?
set -e
if [ "$hoststatus" -ne 0 ] || [ "$portstatus" -ne 0 ] || [ "$mutantstatus" -ne 0 ]; then
    echo "a side crashed: host=$hoststatus port=$portstatus mutant=$mutantstatus - a crash is not a verdict"
    exit 1
fi

# the fixtures must say what they were written to say, on the HOST, or the comparison is over the wrong files
grep -qx 'annot-ap.pdf.hasAppearanceStream=1' "$build/host.txt" || { echo "annot-ap is not an appearance on the host"; exit 1; }
grep -qx 'annot-ap-down.pdf.hasAppearanceStream=0' "$build/host.txt" || { echo "annot-ap-down has an appearance on the host"; exit 1; }
grep -qx 'annot-open.pdf.open=1' "$build/host.txt" || { echo "annot-open is not open on the host"; exit 1; }
grep -qx 'annot-uri.pdf.URL=https://example.com/a' "$build/host.txt" || { echo "annot-uri has no URL on the host"; exit 1; }
grep -qx 'annot-none.pdf.annotations=0' "$build/host.txt" || { echo "annot-none has annotations on the host"; exit 1; }

if ! diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "the port and the host disagree (first lines):"; head -10 "$build/diff.txt" | sed 's/^/    /'; exit 1
fi
echo "COMPARED $(wc -l < "$build/host.txt" | tr -d ' ') facts, all equal to the host"

if diff "$build/host.txt" "$build/mutant.txt" > "$build/mutant-diff.txt"; then
    echo "RED CONTROL FAILED: the planted port answers exactly as the host, so the comparison is blind"; exit 1
fi
echo "RED CONTROL ok: the planted open goes red, $(grep -c '^[<>]' "$build/mutant-diff.txt") lines differ"
