#!/bin/sh
# The port's PDFDocument and PDFPage against the host's own PDFKit, on a PDF this harness writes.
#
# TWO BINARIES, and that is the only shape that works.  An earlier version compiled the port's objects
# into the host's process with their class names renamed, so the host framework's PDFKit and the port's
# @interface shared a translation-unit universe and a small integer ended up in the port's
# CGPDFDocumentRef.  So:
#
#   host-side  the host's PDFKit and nothing else, no port object in the process
#   port-side  the port's objects and nothing else, no macOS PDFKit imported or linked - it builds
#              against the port's RevenantPDFKit.h, which needs only Foundation and CoreGraphics
#
# There is no -D rename anywhere, so the two sets of ivars cannot meet.  Each side prints one
# key=value line per fact and the image dladdr names for the classes it used, and this script diffs the
# two.  The images differ by construction: one names PDFKit, the other names this binary.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/PDFKit
build=${BUILD:-$tree/.agent-work/runs/pdfkit-document}
mkdir -p "$build/fixtures"

# the fixture: written here with the release's own CGPDFContext, so neither side is asked about a file
# it cannot reproduce
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation "$here/make-pdf.m" -framework Foundation -framework CoreGraphics \
    -o "$build/make-pdf" 2> "$build/make.log" || {
    echo "BUILD the fixture writer did not compile:"; head -6 "$build/make.log" | sed 's/^/    /'; exit 1; }
xmake l "$here/make-box-pdfs.lua" "$build/fixtures" > /dev/null
"$build/make-pdf" "$build/fixtures" > /dev/null
# the annotation fixtures join the same directory, written by the release-aware writer rather than by
# CGPDFContext: an annotation's dictionary has to be in the file by the time it is read, and these are
# measured by both sides through the same /Annots array the port walks.
xmake l "$here/tools/make-annotation-fixtures.lua" "$build/fixtures" > /dev/null
# the DICTIONARY-OBJECT fixtures, for the families that read a nested dictionary rather than one
# annotation's flat keys: PDFBorder over /Border and /BS, PDFAppearanceCharacteristics over /MK, and
# the actions and destinations of the families after them.
xmake l "$here/tools/make-object-fixtures.lua" "$build/fixtures" > /dev/null
# the CONFORMING-WRITER text fixtures, built here and not committed: they are a by-product of a tool, and
# a committed PDF would be a second source of truth for what the tool writes.  They are here for the text
# rows specifically - the hand-written fixtures are the control, and both kinds are walked, because a
# string answer measured only on files this port wrote itself would prove nothing about a file a
# conforming writer produced.
xcrun clang -fobjc-arc -Wall "$here/make-text-fixture.m" -framework Foundation -framework CoreGraphics \
    -o "$build/make-text-fixture" 2> "$build/make-text-fixture.log" || {
    echo "BUILD the conforming text fixture writer did not compile:"; head -6 "$build/make-text-fixture.log" | sed 's/^/    /'; exit 1; }
"$build/make-text-fixture" "$build/fixtures" > /dev/null
# the FONT fixtures, for -[PDFSelection boundsForPage:].  These cannot come from the conforming writer,
# because a conforming writer emits a CONSISTENT font - it computes /Widths from the program it embeds -
# and the whole question is which of the two a reader uses.  So the PROGRAM is lifted verbatim out of the
# /FontFile2 stream of a fixture the conforming writer wrote (make-text-fixture.m has just written it) and
# the /Widths are written from a spec beside it, disagreeing on purpose and by a wide margin.
xmake l "$here/tools/make-font-fixtures.lua" "$build/fixtures/cgfixture-1.pdf" "$build/fixtures" > /dev/null
# and the standard fourteen's TABLE, which is GENERATED from a measurement rather than typed, is checked
# against that measurement here so a hand edit to it cannot pass unnoticed.  The measurement is committed
# beside the generator for exactly this reason: a check that only runs in the session that measured is not
# a check.  It is a no-op that must be silent on a clean checkout, so its verdict is printed as a line.
xmake l "$here/tools/make-base14-table.lua" "$port/Base14Widths11.m" --check || {
    echo "the standard fourteen's table is not what the committed measurement produces:"; exit 1; }
# the -string table in the facts file is what tools/verify-table.sh regenerates and asks the host about, and the census of
# the PDFKit declarations and rows is wired in with the check of rows against the header (both were called by nothing)
sh "$here/tools/verify-table.sh" || { echo "the -string table in the facts file is not what these tools produce"; exit 1; }
xmake l "$here/tools/declared-check.lua" "$tree" || { echo "a PDFKit registry row names a member no header of its class declares"; exit 1; }
xmake l "$here/tools/count-missing.lua" "$tree" || { echo "the census of undeclared members could not run"; exit 1; }


# The fixture must carry text, checked by reading the stream back through CGPDFStreamCopyData, which
# inflates it - a grep over the file's bytes sees only the compressed form CGPDFContext writes.  Built
# and run here, outside any pipeline, so the status checked is the checker's own.
xcrun clang -fobjc-arc -Wall "$here/check-fixture.m" -framework Foundation -framework CoreGraphics \
    -o "$build/check-fixture" 2> "$build/check-fixture.log" || {
    echo "BUILD the fixture check did not compile:"; head -6 "$build/check-fixture.log" | sed 's/^/    /'; exit 1; }
if ! "$build/check-fixture" "$build/fixtures"; then
    echo "the fixture carries no text, so every fact below would be over a document with none in it"
    exit 1
fi

# side A: the host only
# AppKit too: the host's PDFView is an AppKit view and its symbols do not link without it
xcrun clang -fobjc-arc -Wall "$here/host.m" -framework Foundation -framework AppKit -framework PDFKit \
    -o "$build/host-side" 2> "$build/host.log" || {
    echo "BUILD the host side did not compile:"; head -8 "$build/host.log" | sed 's/^/    /'; exit 1; }
# side B: the port only, with no macOS PDFKit anywhere
# -Werror=incomplete-implementation makes the COMPILER the completeness check: a selector
# RevenantPDFKit.h declares with no body fails this build and the compiler names it.  That is the check.
# A hand-written metadata parser here once reported 23 missing bodies when only two were, and a check
# that cries wolf is worse than no check.  -respondsToSelector: is no use either: it answers YES for a
# declared method with no body, which is how a missing -revenant_readAttributes and a missing
# -pageAtIndex: both reached a differential that printed "the port has it=1".
# -Wall and NOT -w: -w switches the warning off, and -Werror does not switch a disabled warning
# back on, so with -w the completeness check was decorative - it said nothing while a body was missing.
# PDFKitConstants11.m joins the list because the class files now READ the port's own exported string
# constants rather than repeating their values, and a constant this process does not define is an
# Undefined symbol at link time.  That file imports the SDK's PDFKit.h for its values' types and
# defines them itself, so the port binary carries its own copies and links no host PDFKit.
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation -I "$port" "$here/port.m" \
    "$port/PDFDocument11.m" "$port/PDFPage11.m" "$port/PDFView11.m" "$port/PDFAnnotation11.m" \
    "$port/PDFBorder11.m" "$port/PDFAppearanceCharacteristics11.m" \
    "$port/PDFDestination11.m" "$port/PDFAction11.m" "$port/PDFOutline11.m" "$port/PDFPageText11.m" \
    "$port/PDFSelection11.m" "$port/Base14Widths11.m" \
    "$port/PDFKitConstants11.m" \
    -framework Foundation -framework CoreGraphics -o "$build/port-side" 2> "$build/port.log" || {
    echo "BUILD the port side did not compile:"; head -8 "$build/port.log" | sed 's/^/    /'; exit 1; }

# side C: the port's appearance characteristics and PDFAnnotation's three colours and its font, in a
# process that HAS a UIColor and a UIFont.  Mac Catalyst carries UIKit in a macOS process, which is the
# only way both platforms' own colour class can answer them - see color.m's header for why this is a
# third binary and not part of port.m.  PDFAnnotationColours11.m is on THIS line and not the macOS one for
# the same reason: it is the only object of the port that imports UIKit.
catalyst_sdk=$(xcrun --show-sdk-path)
xcrun clang -fobjc-arc -Wall -Werror=incomplete-implementation \
    -target arm64-apple-ios15.0-macabi -isysroot "$catalyst_sdk" \
    -iframework "$catalyst_sdk/System/iOSSupport/System/Library/Frameworks" \
    -I "$port" "$here/color.m" \
    "$port/PDFDocument11.m" "$port/PDFPage11.m" "$port/PDFView11.m" "$port/PDFAnnotation11.m" \
    "$port/PDFAnnotationColours11.m" \
    "$port/PDFBorder11.m" "$port/PDFAppearanceCharacteristics11.m" \
    "$port/PDFDestination11.m" "$port/PDFAction11.m" "$port/PDFOutline11.m" \
    "$port/PDFPageText11.m" "$port/PDFSelection11.m" "$port/Base14Widths11.m" \
    "$port/PDFKitConstants11.m" \
    -framework Foundation -framework UIKit -framework CoreGraphics \
    -o "$build/port-color-side" 2> "$build/color.log" || {
    echo "BUILD the Catalyst side did not compile:"; head -8 "$build/color.log" | sed 's/^/    /'; exit 1; }

# the rows are truncated FIRST: a stale verdict in this file once made a crash look like a pass
: > "$build/host.txt"; : > "$build/port.txt"
set +e
"$build/host-side" "$build"/fixtures/*.pdf > "$build/host.txt" 2>&1; hoststatus=$?
"$build/port-side" "$build"/fixtures/*.pdf > "$build/port.txt" 2>&1; portstatus=$?
: > "$build/color.txt"
"$build/port-color-side" "$build"/fixtures/*.pdf > "$build/color.txt" 2>&1; colorstatus=$?
set -e
# each side's own status, not a pipeline's: a crash is a failure whatever the file says
if [ "$hoststatus" -ne 0 ] || [ "$portstatus" -ne 0 ] || [ "$colorstatus" -ne 0 ]; then
    echo "a side crashed: host=$hoststatus port=$portstatus color=$colorstatus - a crash is not a verdict"
    exit 1
fi
# The Catalyst side must have answered something, or the merge below would silently leave the
# appearance keys to a port side that cannot compile the type they hold - and it must have answered the
# ANNOTATION colour keys too, which is the only place a UIColor exists for -[PDFAnnotation backgroundColor].
if ! grep -q '^appearance.full.key.BG=' "$build/color.txt"; then
    echo "the Catalyst side printed no appearance key values; its output:"
    head -5 "$build/color.txt" | sed 's/^/    /'
    exit 1
fi

# the images must differ BY CONSTRUCTION, or the two sides are not what this thinks they are
hostimage=$(grep -m1 '^host.PDFDocument.image=' "$build/host.txt" | cut -d= -f2-)
portimage=$(grep -m1 '^port.PDFDocument.image=' "$build/port.txt" | cut -d= -f2-)
case "$hostimage" in *PDFKit*) ;; *) echo "the host side's PDFDocument is not from PDFKit: $hostimage"; exit 1;; esac
case "$portimage" in *port-side*|*port\.side*) ;; *) echo "the port side's PDFDocument is not from this binary: $portimage"; exit 1;; esac
[ "$hostimage" != "$portimage" ] || { echo "both sides name the same image: $hostimage"; exit 1; }
echo "images differ by construction: host=$hostimage port=$portimage"

# the counts are derived from the fixtures, not typed in: three fixtures, and per fixture the
# document, its page count and the past-the-end page are comparable, while the three attributes and
# the two boxes are not - the host's PDFKit has no such methods, which the run names per line
fixtures_expected=$(ls "$build"/fixtures/*.pdf | wc -l | tr -d ' ')
# The expected count is NOT written as an arithmetic formula any more: it depended on how many
# attributes a fixture's Info carries, and that differs per fixture - the box fixtures name no Info and
# answer no keys, the text fixtures name six.  A formula that counted them would have to be right about
# every fixture to be a check at all.  The comparison now asserts instead that every key BOTH sides
# printed was accounted for, and that the only keys not compared are the ones the run says why.

# the facts both sides can answer, compared key by key. tools/compare.lua is THE COMPARISON, as one verdict the red control
# below runs as well rather than a second copy that could disagree with it. $1 is the mutation mode: empty for the plain
# comparison, "auto" to plant a key the two sides currently agree on, or a key's own name.
# THE FIXTURES WHOSE TEXT SETS A NON-ZERO Tc, read from the fixtures (tools/tc-fixtures.lua). It is computed once here, not
# once per comparison: the fixtures do not change during the run, so every comparison reads the same list.
TC_FIXTURES=$(xmake l "$here/tools/tc-fixtures.lua" "$build/fixtures")
compare() {
    xmake l "$here/tools/compare.lua" "$build/host.txt" "$build/port.txt" "$build/color.txt" "$1" "$TC_FIXTURES" \
        "$build/mutation-scratch"
}

# the plain comparison: the run's own verdict, and a mismatch here fails the run
compare "" || { echo "the port and the host disagree on something; see above"; exit 1; }

# THE RED CONTROL, and it is part of the sequence rather than something a reader can run later: the
# port's answers are mutated on ONE key in a SCRATCH COPY, and the run requires that this makes the
# comparison go red. A comparison that still reports no mismatch after a value it agreed on has
# changed is blind, and a differential that cannot say so is not evidence of anything.
control_log="$build/mutation.log"
if compare auto > "$control_log" 2>&1; then
    echo "RED CONTROL FAILED: the comparison was run against a mutated port and still reported no"
    echo "  mismatch, so it would pass a port that is wrong. Its output:"
    sed 's/^/    /' "$control_log"
    exit 1
fi
grep -q "^MUTATION planted on " "$control_log" || {
    echo "RED CONTROL FAILED: the mutated run went non-zero without saying which key it planted,"
    echo "  so the failure is not the control's. Its output:"
    sed 's/^/    /' "$control_log"
    exit 1
}
# and the same requirement as the named controls below: a DIFFERENCE, not only a non-zero exit
grep -q "^  DIFFER " "$control_log" || {
    echo "RED CONTROL FAILED: the mutated comparison reported no difference, so it would pass a port"
    echo "  that is wrong on this key. Its output:"
    sed 's/^/    /' "$control_log"
    exit 1
}
echo "RED CONTROL ok: the comparison goes red on a mutated port, and names the key:"
grep "^MUTATION planted on " "$control_log" | sed 's/^/    /'
grep "^  DIFFER " "$control_log" | sed 's/^/    /' | head -4

# THE FAMILY'S OWN RED CONTROLS, one per rule this series added.  The control above plants on the first
# key the two sides agree on, which is a document fact and would go red even if the border comparison
# were blind.  Each key below is a border or appearance fact, and each is required to be a key both
# sides print with the SAME value (compare() refuses anything else), so planting on it and going red is
# a statement about that key and not about the harness.
# NOT NAMED IN THIS LIST, and the mutator is what says so rather than the comment: cgfixture-text-tc,
# cgfixture-lines2 and cgfixture-3 all draw with a character spacing, so their bounds keys are one of the
# stated boundaries above and the two sides do not agree on them.  A control on such a key proves nothing
# about the comparison seeing a difference it should have seen, and the run refuses it by name - which is
# the right answer and is why those three are absent here rather than present and failing.
#
# cgfixture-high-byte.pdf is absent for the other reason: its text is "caf<E9>" and none of the harness's
# needles matches any of it, so it prints no bounds key at all and a control naming one is refused for the
# same reason - "the two sides do not both print it".  Its -string keys are still compared.
for key in \
    border-plain.pdf.page0.annotation0.border.lineWidth \
    border-bs.pdf.page0.annotation0.border.style \
    border-bs.pdf.page0.annotation0.border.dash.values \
    border-none.pdf.page0.annotation0.border.lineWidth \
    border-link.pdf.page0.annotation0.border \
    noborder-widget-bc.pdf.page0.annotation0.border.lineWidth \
    noborder-widget.pdf.page0.annotation0.border \
    appearance.full.key.BG \
    appearance.fresh.key.R \
    appearance.cleared.keys \
    appearance.controlType2.keys \
    border.fresh.lineWidth \
    border.fresh.keys \
    border.all.lineWidth \
    border.all.keys \
    border.pattern.style \
    border.empty.keys \
    border.cleared.lineWidth \
    border.styleonly.keys \
    border.widthzero.keys \
    border-plain.pdf.page0.border.identity.same \
    border-plain.pdf.page0.border.set.same \
    border-plain.pdf.page0.border.set.mutated \
    border-plain.pdf.page0.border.set.nil \
    act-goto-xyz.pdf.page0.annotation0.action.class \
    act-goto-xyz.pdf.page0.annotation0.actionGoTo.destination.pageIndex \
    act-goto-xyz.pdf.page0.annotation0.actionGoTo.destination.point.x \
    act-goto-badpage-xyz.pdf.page0.annotation0.actionGoTo.destination.point.y \
    act-goto-badpage-xyz.pdf.page0.annotation0.actionGoTo.destination.zoom \
    act-goto-fit.pdf.page0.annotation0.actionGoTo.destination.page \
    act-goto-page2.pdf.page0.annotation0.action.pageIndex \
    act-goto-page2.pdf.page0.annotation0.action.URL \
    act-goto-shapes.pdf.page0.annotation3.actionGoTo.destination \
    act-named-all.pdf.page0.annotation1.action.name \
    act-named-all.pdf.page0.annotation0.action \
    act-named-all.pdf.page0.annotation2.action \
    act-uri.pdf.page0.annotation0.action.URL \
    act-gotor.pdf.page0.annotation0.action.URL \
    act-reset-flags.pdf.page0.annotation2.action.cleared \
    act-reset-flags.pdf.page0.annotation3.action.cleared \
    act-reset-flags.pdf.page0.annotation4.action.cleared \
    act-reset.pdf.page0.annotation0.action.fields.values \
    ann-dest-array.pdf.page0.annotation0.destination.point.x \
    ann-dest-dict.pdf.page0.annotation0.destination \
    ann-dest-and-a.pdf.page0.annotation0.destination.point.x \
    init.goto.class \
    init.named.class \
    init.named99.name \
    init.remote.class \
    init.reset.class \
    init.destination.made.zoomAfterSet \
    initdest.nilpage \
    initgoto.class \
    initnamed.class \
    initremote.class \
    initremote.point.x \
    copy.destination.same \
    copy.destination.page.same \
    copy.destination.zoomAfterSet \
    copy.destination.zoomOriginal \
    copy.nopage \
    copy.goto.destination.same \
    copy.goto.destination.page.same \
    copy.named.nameAfterSet \
    copy.remote.pageIndex \
    copy.reset.fields.same \
    copy.action.class \
    initoutline.class \
    initoutline.dest \
    initoutline.root \
    outline-collapsed.pdf.outline.label \
    outline-collapsed.pdf.outline.children \
    outline-collapsed.pdf.outline.isOpen \
    outline-collapsed.pdf.outline.parent \
    outline-collapsed.pdf.c0.outline.index \
    outline-collapsed.pdf.c0.outline.isOpen \
    outline-collapsed.pdf.c0.outline.dest.point \
    outline-collapsed.pdf.c0.outline.action.type \
    outline-collapsed.pdf.c0.c0.outline.label \
    outline-collapsed.pdf.c0.c1.outline.index \
    outline-collapsed.pdf.c1.outline.action.class \
    outline-signs.pdf.c0.outline.isOpen \
    outline-signs.pdf.c1.outline.isOpen \
    outline-nocount.pdf.c0.outline.isOpen \
    outline-untitled.pdf.c0.c0.c0.c0.outline.isOpen \
    outline-titled.pdf.c0.c0.c0.c0.outline.isOpen \
    outline-titlekey.pdf.c0.c0.outline.isOpen \
    outline-titlekey.pdf.c1.c0.outline.isOpen \
    outline-titlekey.pdf.c2.c0.outline.isOpen \
    outline-shapes.pdf.c0.c0.outline.action.dest.point \
    outline-shapes.pdf.c2.outline.dest.page \
    outline-shapes2.pdf.c0.c1.outline.isOpen \
    act-goto-fit.pdf.outline \
    outline-collapsed.pdf.childPastEnd \
    outline-collapsed.pdf.c0.childPastEnd \
    outline-collapsed.pdf.c0.c0.childPastEnd \
    outline-nocount.pdf.c0.childPastEnd \
    cgfixture-pair-down.pdf.page0.string \
    cgfixture-pair-down.pdf.page0.numberOfCharacters \
    cgfixture-pair-same.pdf.page0.string \
    cgfixture-pair-up.pdf.page0.string \
    cgfixture-lines.pdf.page0.string \
    cgfixture-lines.pdf.page0.numberOfCharacters \
    widget-flags.pdf.page0.annotation0.flags.readOnly \
    widget-flags.pdf.page0.annotation0.flags.multiline \
    widget-flags.pdf.page0.annotation0.flags.isPasswordField \
    widget-flags.pdf.page0.annotation0.flags.comb \
    widget-flags.pdf.page0.annotation0.flags.allowsToggleToOff \
    widget-flags.pdf.page0.annotation0.flags.radiosInUnison \
    widget-flags.pdf.page0.annotation0.flags.listChoice \
    widget-flags.pdf.page0.annotation0.flags.widgetControlType \
    widget-flags.pdf.page0.annotation0.flags.activatableTextField \
    widget-flags.pdf.page0.annotation5.flags.widgetControlType \
    widget-flags.pdf.page0.annotation6.flags.widgetControlType \
    widget-flags.pdf.page0.annotation7.flags.listChoice \
    widget-flags.pdf.page0.annotation12.flags.radiosInUnison \
    widget-flags.pdf.page0.annotation4.flags.allowsToggleToOff \
    widget-noflags.pdf.page0.annotation0.flags.widgetControlType \
    widget-allflags.pdf.page0.annotation0.flags.widgetControlType \
    widget-allflags.pdf.page0.annotation0.flags.readOnly \
    widget-fttx1.pdf.page0.annotations.count \
    widget-ftch2.pdf.page0.annotations.count \
    widget-ftch4.pdf.page0.annotations.count \
    widget-ftch5.pdf.page0.annotations.count \
    widget-ftbtn0.pdf.page0.annotation0.flags.activatableTextField \
    act-goto-fit.pdf.page0.annotation0.flags.activatableTextField \
    widget-t-literal.pdf.page0.annotation0.flags.fieldName \
    widget-t-empty.pdf.page0.annotation0.flags.fieldName \
    widget-t-merged.pdf.page0.annotation0.flags.fieldName \
    widget-t-mergedname.pdf.page0.annotation0.flags.fieldName \
    widget-t-extra-TU.pdf.page0.annotation0.flags.fieldName \
    widget-t-extra-DAstring.pdf.page0.annotation0.flags.fieldName \
    widget-t-extra-DAstring.pdf.page0.annotations.count \
    button-ap-states.pdf.page0.annotation0.state.onName \
    button-ap-states.pdf.page0.annotation1.state.onName \
    button-ap-states.pdf.page0.annotation2.state.onName \
    button-ap-states.pdf.page0.annotation3.state.onName \
    button-ap-states.pdf.page0.annotation4.state.onName \
    button-as-alone.pdf.page0.annotation0.state.onName \
    widget-flags.pdf.page0.annotation0.state.onName \
    button-as-and-v.pdf.page0.annotation1.state.on \
    button-as-and-v.pdf.page0.annotation2.state.on \
    button-asoff-von.pdf.page0.annotation0.state.on \
    button-asoff-von.pdf.page0.annotation3.state.on \
    button-v-only.pdf.page0.annotation3.state.on \
    button-v-only.pdf.page0.annotation2.state.on \
    button-ap-states.pdf.page0.annotation1.state.on \
    button-ap-states.pdf.page0.annotation3.state.on \
    button-ap-states.pdf.page0.annotation4.state.on \
    text-as.pdf.page0.annotation3.state.on \
    button-merged-vyes-asyes.pdf.page0.annotation0.state.on \
    cgfixture-lines2.pdf.page0.string \
    cgfixture-lines2.pdf.page0.numberOfCharacters \
    cgfixture-words.pdf.page0.string \
    cgfixture-gap.pdf.page0.string \
    cgfixture-gap.pdf.page0.numberOfCharacters \
    cgfixture-lead.pdf.page0.string \
    cgfixture-tail.pdf.page0.string \
    cgfixture-tail.pdf.page0.numberOfCharacters \
    cgfixture-tailpair.pdf.page0.string \
    cgfixture-blank.pdf.page0.string \
    cgfixture-inline.pdf.page0.string \
    cgfixture-tab.pdf.page0.string \
    cgfixture-cross.pdf.page0.string \
    cgfixture-words.pdf.find.alpha.count \
    cgfixture-words.pdf.find.alpha.0.string \
    cgfixture-words.pdf.find.alpha.0.range0 \
    cgfixture-words.pdf.find.alpha.0.ranges \
    cgfixture-words.pdf.find.alpha.0.pages \
    cgfixture-words.pdf.find.alpha.0.byLine \
    cgfixture-words.pdf.find.alpha.0.copy \
    cgfixture-words.pdf.find.alpha.0.attributedLength \
    cgfixture-words.pdf.find.alpha.backwards.0.range0 \
    cgfixture-lines.pdf.find.third.0.string \
    cgfixture-lines.pdf.find.third.0.range0 \
    cgfixture-lines2.pdf.find.two.0.string \
    cgfixture-lines2.pdf.find.two.0.range0 \
    cgfixture-3.pdf.find.page.backwards.0.ranges \
    cgfixture-widths-vs-program-wide.pdf.find.page.0.bounds0 \
    cgfixture-widths-vs-program-narrow.pdf.find.page.0.bounds0 \
    cgfixture-no-font-program.pdf.find.page.0.bounds0 \
    cgfixture-broken-font-program.pdf.find.page.0.bounds0 \
    cgfixture-text-no-tc.pdf.find.page.0.bounds0 \
    cgfixture-base14-with-widths.pdf.find.page.0.bounds0 \
    act-goto-bad-page.pdf.find.line.backwards.0.boundsLast \
    cgfixture-gap.pdf.find.alpha.0.string \
    cgfixture-blank.pdf.find.alpha.0.string \
    cgfixture-lead.pdf.find.bravo.0.range0 \
    annotation-colours.pdf.colours.names \
    annotation-colours.pdf.colours.nmbg-rgb.backgroundColor.space \
    annotation-colours.pdf.colours.nmbg-rgb.backgroundColor.components \
    annotation-colours.pdf.colours.nmbg-cmyk.backgroundColor.space \
    annotation-colours.pdf.colours.nmbg-notarray.backgroundColor \
    annotation-colours.pdf.colours.nmic-square-gray.interiorColor.space \
    annotation-colours.pdf.colours.nmic-circle-cmyk.interiorColor.components \
    annotation-colours.pdf.colours.nmda-fill-rgb.fontColor.space \
    annotation-colours.pdf.colours.nmda-fill-rgb.fontColor.components \
    annotation-colours.pdf.colours.nmda-fill-badcount.fontColor.components \
    annotation-colours.pdf.colours.nmda-stroke-k.fontColor.space \
    annotation-colours.pdf.colours.nmfont-courier-7.font.name \
    annotation-colours.pdf.colours.nmfont-courier-7.font.size \
    annotation-colours.pdf.colours.nmfont-abbrev-hebo.font.name \
    annotation-colours.pdf.colours.nmfont-unknown.font.size
do
    family_log="$build/mutation-$key.log"
    if compare "$key" > "$family_log" 2>&1; then
        echo "RED CONTROL FAILED for $key: the comparison was run against a mutated $key and still"
        echo "  reported no mismatch. Its output:"
        sed 's/^/    /' "$family_log"
        exit 1
    fi
    grep -q "^MUTATION planted on " "$family_log" || {
        echo "RED CONTROL FAILED for $key: the mutated run went non-zero without saying which key it"
        echo "  planted, so the failure is not the control's. Its output:"
        sed 's/^/    /' "$family_log"
        exit 1
    }
    # AND IT HAS TO GO RED ON THE DIFFERENCE, not merely exit non-zero: the defect this family found is
    # that a control which planted nothing at all exited non-zero with "MUTATION failed" and was read as
    # a pass, so a non-zero exit alone is not evidence that the comparison saw anything.
    grep -q "^  DIFFER " "$family_log" || {
        echo "RED CONTROL FAILED for $key: the mutated comparison reported no difference, so planting on"
        echo "  this key proves nothing about the comparison seeing one. Its output:"
        sed 's/^/    /' "$family_log"
        exit 1
    }
    echo "RED CONTROL ok for $key:"
    grep "^  DIFFER " "$family_log" | sed 's/^/    /' | head -1
done
