# PDFDocument and PDFPage over the release's own CGPDFDocument

## What the subtraction said, and how

`objc.inventory` — an Objective-C class census — reports `PDFDocument` and `PDFPage` as carried by
**neither** 6.1.3 nor 4.3, with `ZZNotAClassAnywhere` and `CGPDFKitNotAThing` answering "not carried".
So these are the port's own classes.

The same census is the **wrong test** for the CoreGraphics side, because `CGPDFDocument`, `CGPDFPage`
and `CGPDFScanner` are C types that no Objective-C inventory can see. The dyld export tables answer
instead, and they answer that the substrate is the release's own: `CGPDFDocumentCreateWithURL`,
`CGPDFDocumentGetNumberOfPages`, `CGPDFDocumentGetPage`, `CGPDFDocumentRelease`, `CGPDFPageGetBoxRect`,
`CGPDFPageGetDictionary` and `CGPDFScannerCreate` are exported by **both** bands, with
`CGPDFKitNotAFunction` answering "not in the release".

**And the two scanner readers are not:** `CGPDFScannerScanString` and `CGPDFScannerGetString` are
exported by neither. So string extraction through the scanner is not feasible on this release, `-string`
answers only what the port holds, and the scanned extraction is owed. No row claims otherwise.

## The harness, and why it is two binaries

One binary with the port's objects compiled in under renamed class names cannot work: the host
framework's PDFKit and the port's `@interface` share a translation-unit universe, and a small integer
ended up in the port's `CGPDFDocumentRef`. So there are two, with nothing of the other side in either
process, and the images `dladdr` names are asserted to differ before any fact is compared.

    $ sh tests/backports/host/pdfkit-document/run.sh
      images differ by construction: host=/System/…/PDFKit.framework/…/PDFKit
                                      port=…/runs/pdfkit-document/port-side
      COMPARED 10 MISMATCHES 0  (not compared: 15)

Ten facts the host can answer, all agreeing: `pageCount` on three fixtures (1, 1, 3), each document an
object, and `pageAtIndex:` one past the end nil on all three. The fifteen it cannot are named per line —
the host's `PDFDocument` has no `documentAttributes` and no `documentAttribute:`, and its `PDFPage` has no
`mediaBox` and no `cropBox`.

## What the crash was, and what the ownership change is

**The crash was missing bodies.** Repeated rewrites of PDFDocument11.m dropped the definitions of
-revenant_readAttributes, -documentAttribute:, -pageAtIndex: and -pageCount while RevenantPDFKit.h kept
declaring them, and `-respondsToSelector:` answers YES for a declared method with no body — which is how
a method that does not exist reached a differential printing "the port has it=1". The crash was always

    -[PDFDocument revenant_readAttributes]: unrecognized selector sent to instance …

and the compiler's `-Wincomplete-implementation` was naming them while I read CF ownership.

**The ownership change is unproven either way.** The page holds its `CGPDFPageRef` as a Get, owns a
`CGPDFDocumentRetain`, and the document keeps the pages it handed out. That is correct by the CF rules on
its own — a `Get` is not owned, and the page needs a document reference to outlive its document, which
the header's `weak` document property (PDFPage.h:70) implies. But its red control no longer fires:

    the true inverse - the page retain/release AND pageAtIndex's release of the Get -  exit=0
    COMPARED 10 MISMATCHES 0  (not compared: 15)

so nothing here shows the ownership was what made the run pass, and the earlier bisect
("pageAtIndex:0, page kept" 0 / "pageAtIndex:0 then dropped" 139) was bisecting a tree that was also
missing four methods. The ownership is kept because it is right by the rules; it is not claimed as a
cure, because it is not shown to be one.

## The ownership as it stands

The page holds the `CGPDFPageRef` as a **Get** — `CGPDFDocumentGetPage` hands back a page the document
owns and no reference to it — and owns only a `CGPDFDocumentRetain`, released in its own `dealloc`. The
document keeps the pages it handed out. The bisect that found this:

    pageAtIndex:0, page kept          exit=0     a page that outlives its document is fine
    pageAtIndex:0, page dropped first  exit=139   the same call, and 139

Every count in the CF audit was balanced; the **order** was wrong, which is why reading the audit found
nothing. A `CGPDFPageRef` released while its document is alive is the direction CoreGraphics does not
support. Both controls now bite:

    control A, the true inverse (the page retain/release AND pageAtIndex's release re-added)  exit=1
    control B, pageCount planted to answer one more than the release says
      DIFFER  revenant-fixture-3.pdf.pageCount  host='3' port='4'
      COMPARED 10 MISMATCHES 3  (not compared: 15)                                             exit=1

## What -init answers, measured on this host

The three ways the header's own comment names a document being made — "either the init method,
initWithURL:, or initWithData:" — do not agree with each other, and the host says which is which:

    [[PDFDocument alloc] init] -> an object  pageCount=0  document={
    }
    [PDFDocument new]          -> an object  pageCount=0
    -initWithData:nil           -> nil
    -initWithURL:nil            -> nil

So `-init` is a third **designated** initializer that makes an empty document, while nil data and a
nil URL give nil. All three call `[super init]` and none calls another, which is the shape
`-Wobjc-designated-initializers` asks for; the private `-revenant_setUpWithData:` is an ordinary method
for the same reason.

## The fixtures carry text now, and one comparison is owed

`make-pdf.m` selected a font before drawing, so every page of the fixture carries a **literal** string
through a `Tj` - `BT 0.0002 Tc 12 0 0 12 20 752 Tm /TT1 1 Tf (page 1) Tj 0 Tc ET` - and
`check-fixture.m` reads each page's stream back through `CGPDFStreamCopyData` to prove it, because the
file's own bytes hold the compressed form and a grep over them sees nothing.

### The box comparison, and what the host does

`-[PDFPage boundsForBox:]` is now compared on both sides for all five kinds `CGPDFBox` declares, on
three fixtures: one naming every box, one with no `/CropBox`, and one rotated 90. The host's
`-[PDFPage boundsForBox:]` and `CGPDFPageGetBoxRect` were measured to **agree on every kind in every
case**, so the port's one call per kind is already right and it needed no change. What the measurement
shows: a named `/BleedBox` is honoured, a page with no `/CropBox` answers its MediaBox, and `/Rotate 90`
is reported through `rotation` and left out of every box.

The five box kinds are separate registry rows and all of them are `implemented` on that comparison;
`PDFPage.mediaBox` and `PDFPage.cropBox` stay `inert` with the reason the host has neither as a
property, and their row now points at the comparison that does cover the box they wrap.

## The host's `-string`, measured, and why the row is inert

| fixture | content stream | host `-string` |
| --- | --- | --- |
| kern-20 | `BT /F1 12 Tf 72 720 Td [(al) -20 (pha)] TJ ET` | `alpha` |
| kern-50 | `BT /F1 12 Tf 72 720 Td [(al) -50 (pha)] TJ ET` | `alpha` |
| kern-100 | `BT /F1 12 Tf 72 720 Td [(al) -100 (pha)] TJ ET` | `alpha` |
| kern-150 | `BT /F1 12 Tf 72 720 Td [(al) -150 (pha)] TJ ET` | `al pha` |
| kern-250 | `BT /F1 12 Tf 72 720 Td [(al) -250 (pha)] TJ ET` | `al pha` |
| kern-500 | `BT /F1 12 Tf 72 720 Td [(al) -500 (pha)] TJ ET` | `al pha` |
| kern-1000 | `BT /F1 12 Tf 72 720 Td [(al) -1000 (pha)] TJ ET` | `al pha` |
| kern-plus250 | `BT /F1 12 Tf 72 720 Td [(al) 250 (pha)] TJ ET` | `alpha` |
| td-x-only | `BT /F1 12 Tf 72 720 Td (alpha) Tj 72 0 Td (beta) Tj ET` | `alpha beta` |
| td-small-y | `BT /F1 12 Tf 72 720 Td (alpha) Tj 0 -2 Td (beta) Tj ET` | `alphabeta` |
| td-y--0.4 | `BT /F1 12 Tf 72 720 Td (alpha) Tj 0 -0.4 Td (beta) Tj ET` | `alphabeta` |
| td-y--14 | `BT /F1 12 Tf 72 720 Td (alpha) Tj 0 -14 Td (beta) Tj ET` | `alpha\nbeta` |
| td-y--40 | `BT /F1 12 Tf 72 720 Td (alpha) Tj 0 -40 Td (beta) Tj ET` | `alpha\nbeta` |
| op-TD-next-line | `BT /F1 12 Tf 72 720 Td (alpha) Tj 0 -14 TD (beta) Tj ET` | `alpha\nbeta` |
| op-quote-operator | `BT /F1 12 Tf 72 720 Td (alpha) ' ET` | `alpha` |
| op-TD-star-between | `BT /F1 12 Tf 72 720 Td 0 -14 Td (beta) Tj T* (gamma) Tj ET` | `betagamma` |
| size-6 | `BT /F1 6 Tf 72 720 Td [(al) -100 (pha)] TJ ET` | `alpha` |
| size-12 | `BT /F1 12 Tf 72 720 Td [(al) -100 (pha)] TJ ET` | `alpha` |
| size-24 | `BT /F1 24 Tf 72 720 Td [(al) -100 (pha)] TJ ET` | `alpha` |
| op-Tm-set | `BT /F1 12 Tf 72 720 Td 1 0 0 1 72 706 Tm 0 -14 Td ET` | `(nil)` |
| op-TD-star-next-line | `BT /F1 12 Tf 72 720 Td 0 -14 T* ET` | `(nil)` |
| op-dquote-operator | `BT /F1 12 Tf 72 720 Td (alpha) " ET` | `(nil)` |

Reproduce with `tools/make-text-fixtures.py` and `tools/host-string.m` under
`tests/backports/host/pdfkit-document/tools/`, both committed here so this table is not a claim in a
message that scrolls away.

### What the host does, and the region it was measured in

* **A `TJ` kerning inserts exactly one space past a threshold, never more.** Between `-100` (no space)
  and `-150` (one space) at 12pt; `-500` and `-1000` still give ONE space, so magnitude past the
  threshold buys nothing. A positive kerning inserts nothing.
* **Movement down between two shows inserts a newline past a threshold.** `-0.4` and `-2` give nothing,
  `-14` and `-40` give a newline, and `TD` behaves as `Td`. **Horizontal** movement (`72 0 Td`) gives
  a SPACE, not a newline.
* **The thresholds are bracketed, not located.** The kerning threshold is somewhere in `(-100, -150]` and
  the vertical one in `(-2, -14]`, both at one font size.
* **Three cases are void, not measurements.** `op-Tm-set`, `op-TD-star-next-line` and
  `op-dquote-operator` answered nil - the reader rejected those content streams - so nothing is known
  about `Tm`, a leading `T*`, or the double-quote operator here.
* **The font-size question is UNRESOLVED.** The kerning was held at `-100` while the size went 6, 12,
  24, and all three gave no space, which is consistent with BOTH an absolute and an em-relative
  threshold. Separating them needs the kerning to scale with the size, which is not measured.
* **One result does not fit the movement rule.** `T*` between two shows gives `betagamma` - no
  separator - where `Td` between the same two gives a newline.

### Why the row stays inert, with this boundary

Reproducing the host means reproducing a layout heuristic whose two thresholds are bracketed but not
located, on a page that can carry fonts nobody has measured, with three operator cases unread and a
font-size dependence still unresolved. A port that flattens string operands and joins on newlines
would agree on a single `Tj`, on a `Td`-separated pair and on a kerned `TJ` array, and would
disagree on every `Td` threshold case, on horizontal movement, and on the `T*` case - with no way to
say where the agreement stops. So `PDFPage.string` is carried as inert with the measured region in its
effect, and the extraction is owed rather than claimed.

### Owed

**The fixture writer still draws text through the deprecated calls.** `CGContextSelectFont` and
`CGContextShowTextAtPoint` are both marked deprecated and "No longer supported" in the SDK header, so
`make-pdf.m` is on a path that stops working, and `-Wall` now says so on every build of it. The
fixtures should be drawn with CoreText or with the CGPDFContext text operators instead. Not this
slice, and nothing here depends on it: the boxes the run compares come from the page dictionary and
not from what the writer drew.

**Owed, and unchanged: the `-string` extraction** The host's `PDFPage` has `-boundsForBox:` and answers it
(`responds to -boundsForBox:: 1`) while it has no `-mediaBox` or `-cropBox` (`responds to -mediaBox: 0`),
so the run is probing two selectors the host lacks and leaving a fact it can answer on the floor. The
comparison is the next slice, over all five box kinds `CGPDFBox` declares, with the rects compared
numerically.

## What PDFKit still owes from the 26.2 headers

`tools/corpus/surface-diff-latest.py PDFKit --rows` against the 26.2 SDK: **456 declared rows across
163 classes**; 7 answered by this tree, **449 owed**.  This is the shape of the rest of the family and
it is written here so it survives this series.

| class | owed | kinds | | class | owed | kinds |
| --- | ---: | --- | --- | --- | ---: | --- |
| PDFView | 69 | class, method, property | | PDFViewDelegate | 6 | method, protocol |
| PDFAnnotation | 62 | class, method, property | | UICoordinateSpace | 6 | method, property, protocol |
| PDFDocument | 45 | method, property | | PDFActionRemoteGoTo | 5 | class, method, property |
| PDFPage | 26 | method, property | | PDFActionResetForm | 4 | class, method, property |
| PDFSelection | 17 | class, method, property | | PDFPageOverlayViewProvider | 4 | method, protocol |
| PDFOutline | 13 | class, method, property | | PDFActionGoTo, PDFActionNamed, PDFActionURL | 3 each | class, method, property |
| PDFDocumentDelegate | 10 | method, protocol | | PDFAction | 2 | class, property |
| PDFAppearanceCharacteristics | 9 | class, property | | PDFBorder, PDFDestination | 6 each | class, method, property |
| PDFThumbnailView | 7 | class, property | | the rest | 139 classes | 1-4 rows each |

The tail of 139 small classes is the `PDFAction*PrivateVars` and `PDFAnnotation*` internals, the
highlighting-mode constants and the annotation-key constants.

**The order the family is to be taken in, and why.**  PDFDocument and PDFPage first: this tree already
implements both over the release's own `CGPDFDocument` and the harness already compares page count, the
five boxes, rotation and the Info attributes, so those 71 rows are the largest block answered by
EXTENDING A COMPARISON THAT EXISTS rather than building a new one.  PDFView (69) next, which is the one
large class where the host answers much of it without a window - `-document`, `-pageCount`,
`-currentPage`, `-scaleFactor`, `-goToPage:` - and the one where the family's own brief already says the
answer is "state and Apple's answers without a window".  PDFAnnotation and PDFSelection/PDFOutline
last, because they are models over the page dictionary where the appearance and line-style members
will hit the same layout-heuristic wall that put `-string` in `inert` with a measured region.

## PDFView windowless, measured - and the plan's cases corrected by it

`tools/host-view-windowless.m` asks the host's PDFView with NO WINDOW and never shown, which is the
port's position too.  Measured on box-all, revenant-fixture-3 and box-rotated, identical on all three:

    window                 (nil)          document      (nil) before a document, an-object after, (nil) again
    currentPage            an-object as soon as a document is set - no window, no page shown
    scaleFactor 1          minScaleFactor 0.1   maxScaleFactor 100   autoScales 0
    displayMode 1          displayBox 1           displayDirection 0   pageShadowsEnabled 1
    set displayMode=twoUpContinuous reads back 3;  set displayBox=cropBox reads back 1, REJECTED
    document=nil takes currentPage to nil with it
    canDisplayPage: supported=0    goToPage: supported=1    scaleToFit: supported=0

THREE OF THE PLAN'S CASES ARE NOT THE API, and the measurement is what says so: the iOS PDFView.h declares
no -pageCount, no -canDisplayPage:, no -usePageViewController:, no -scaleToFit, and the host's PDFView
answers canDisplayPage: supported=0 and scaleToFit supported=0.  A comparison on them would have been a
comparison of things neither side is asked for.  -goToPage: IS the host's, and it is the one windowful
member here.  The windowless members that are really the API are the ones measured above.

## The host's character count, measured, and why the port cannot match it yet

-numberOfCharacters is NOT behind the wall that put -string in inert, and that is worth saying because I
expected it to be.  Measured on two fixtures that separate the two things:

    kern-150.pdf   numberOfCharacters=6   -string "al pha"    six characters, five drawn glyphs
    kern-20.pdf    numberOfCharacters=5   -string "alpha"     five and five

So the host counts the characters of the same text walk - the kerning separator included - and not a
layout-derived glyph run.  The port cannot obtain it: the token walk that produces those characters
needs CGPDFScannerScanString and CGPDFScannerGetString, and NEITHER 6.1.3 nor 4.3 exports them (both
caches' export tables, read through dyld.load).  The measurement is therefore real and the port's answer
is not obtainable, so the row is inert with the region named, and the run does not compare it.

-dataRepresentation is the same shape of boundary for a different reason: the host REWRITES the document
it hands back, so its byte count is not the file's.  Measured host 886 / 896 / 897 / 805 / 8784 / 10116
against the port's 644 / 655 / 655 / 569 / 8775 / 10105 on the six fixtures - every pair two different
documents, and a count of them is not a fact either side can agree on.

## PDFAnnotation: the host answers over the page dictionary, and ONE of its answers is not understood

`tools/make-annotation-fixtures.py` writes three fixtures with annotations, every xref offset and
/Length measured, and `tools/host-annotation-windowless.m` asks the host about them.  All three OPEN and
the host reports what they carry:

    annot-text.pdf   opened pages=1 annotations=1
        type=-7465777360276108450  subtype=/Text  contents="a note on the page"  userName="the annotator"
        color=Device RGB colorspace 1 0 0 1   modificationDate=2026-09-30 00:00:00 +0000
        border=solid lineWidth:1.0 hCorner:0.0 vCorner:0.0   flags=4   page=an-object
    annot-free.pdf  opened pages=1 annotations=1
        type=-7465777392304208034  subtype=/Link  contents=bare  userName=(nil)  color=(nil)
        modificationDate=(nil)  border=(nil)  flags=4  page=an-object
    annot-two.pdf   opened pages=1 annotations=2     (the two above, in order)

So the COUNT, the SUBTYPE, /Contents, /T, /C, /M, /Border, /F and the page back-reference are all
answered by the host, and the empty case answers nil for exactly the keys the fixture omits - which is
the case worth having, because a member that reads an absent key must say nil and not zero.

BOUNDS IS THE ICON FOR A NOTE AND THE RECT FOR EVERYTHING ELSE, and that is measured on a rect the
rule was NOT fitted to:

    $ python3 tests/backports/host/pdfkit-document/tools/make-annotation-fixtures.py .agent-work/fin/annotfix
    $ .agent-work/fin/ha .agent-work/fin/annotfix/annot-text-holdout.pdf …/annot-link-wide.pdf …/annot-square.pdf …/annot-highlight.pdf

    annot-text-holdout  /Text     /Rect [10 20 500 90]   bounds={{10, 66}, {24, 24}}
        x = 10 = rect minX,  y = 66 = 90 - 24 = rect maxY - 24,  24x24
    annot-link-wide     /Link     /Rect [0 0 600 700]    bounds={{0, 0}, {600, 700}}   the rect
    annot-square        /Square   /Rect [40 40 240 140]  bounds={{40, 40}, {200, 100}} the rect
    annot-highlight     /Highlight/Rect [0 0 200 30]     bounds={{0, 0}, {200, 30}}   the rect

So a /Text annotation is shown as a 24x24 note icon anchored at (rect minX, rect maxY - 24), and
every other subtype answers the rectangle it was written with.  Three subtypes agree on "not a note is
the rect", and the icon rule holds on a rect it was derived from a DIFFERENT one.  This is a rule and
not an accident, and it is a rule about /Text and not about annotations.

TWO DEFAULTS THE HOST SUPPLIES, and both are answers rather than absences:

    /Square with no /Border    answers a DEFAULT border: solid lineWidth 1.0
    /Highlight with no /C      answers an sRGB YELLOW: 0.980392 0.803922 0.352941 1
    /Link and /Highlight with no /Border answer NIL, and /Link with no /C answers nil

So a missing key is not always nil, and a member that reads /Border or /C must say which of the three
it is: the value written, the host's default, or nil.

-type IS A STRING AND NOT AN INTEGER, and the first reading of it here was wrong.  The probe printed
`(long)a.type` and got five large negative numbers, one per subtype, stable across the two fixtures
that share a subtype - which is what a per-subtype constant looks like, and is why this file recorded
them as "per-subtype TYPE constants ... comparable as opaque numbers".  They are not.  PDFAnnotation.h
declares PDFAnnotationSubtype as NSString* const, and the host answers an NSTaggedPointerString, which
packs the characters INTO the pointer, so reading it as a long printed a tagged value and not a type.
Measured, after the type was asked for as an object:

    $ clang -fobjc-arc -framework Foundation -framework AppKit -framework PDFKit \
        -o .agent-work/fin/typeof .agent-work/fin/typeof.m
    $ .agent-work/fin/typeof .agent-work/fin/annotfix/annot-{text,free,square,highlight,noprint}.pdf

    annot-text.pdf       type-as-string=Text       class=NSTaggedPointerString
    annot-free.pdf       type-as-string=Link       class=NSTaggedPointerString
    annot-square.pdf     type-as-string=Square     class=NSTaggedPointerString
    annot-highlight.pdf  type-as-string=Highlight  class=NSTaggedPointerString
    annot-noprint.pdf    type-as-string=Square     class=NSTaggedPointerString

So the answer is the dictionary's /Subtype name with no leading slash, and the stability across
fixtures is interning - which is a property of the runtime, not a constant of the subtype.  A probe
that reads an object and casts it to a number has not measured a type; it has measured a pointer.

## The members this package names and refuses, which are not rows

Three members a plan named are NOT this API and carry NO registry row, because a row records what the
package's surface is and these are not on it.  A reader scanning the registry for a member must not
find one, and a census must not count one:

  -pageCount, -canDisplayPage:, -scaleToFit on PDFView    the 26.2 PDFView.h declares NONE of the
                                                          three, and the host answers canDisplayPage:
                                                          supported=0 and scaleToFit supported=0
  -usePageViewController:                                 the header declares the TWO-ARGUMENT form
                                                          -usePageViewController:withViewOptions:,
                                                          which is a different member from the one a
                                                          plan named; no row for either
  PDFView.pageCount                                        MISATTRIBUTED and the sharpest of them:
                                                          pageCount is PDFDocument's property
                                                          (PDFDocument.h:231) and the same file
                                                          already carries -[PDFDocument pageCount] as
                                                          implemented.  A second row for the name
                                                          would describe a member that class has
                                                          never had.

The port does not implement any of them, and `RevenantPDFKit.h:46-49` says so where a reader looks for
what the port offers.  `tools/declared-check.py` is the mechanical form of that sentence: it reads every
PDFKit registry row against the 26.2 headers of the member's OWN class and names any row that does not
name a declared member, so a row like these cannot be added again by accident.

## The rows

Three are `implemented`, and only those three: `PDFDocument`, `-pageCount`, `-pageAtIndex:` — the facts
the host answers and the run compares. The other seven are `inert` with the reason stated, because the
host answers none of them and a row may not say a host compared something no host fact covers.
`PDFPage.string` is among them, and its effect carries the scanner finding in full.

## PDFSelection: 15 declared, 1 covered, OWED WORK - and the host answers are measured

    # output of the removed count-missing check, as measured:
      PDFSelection                15 declared,  1 covered, 14 missing

PDFSelection is the largest family whose cases the host answers in a process with no window, because a
selection is made by GEOMETRY - a rect or a point in page space - and needs no view.  The host's answers
below are measured, with tools/host-selection-windowless.m.

THE PORT HAS NONE OF IT, and an earlier export claimed otherwise.  An export carried a PDFSelection model
whose four members were marked implemented, and the two-binary differential compared NOTHING about it:
neither side printed a single PDFSelection key, the port had no -selectionForRect:, -selectionForWordAtPoint:
or -selectionForLineAtPoint: to reach a selection through, and the model's own constructor was called from
nowhere.  It was an unreachable model with rows claiming a measurement, and the export was withdrawn.  The
host answers are kept here so the work is specified rather than lost, and the rows that described them are
gone until there is something for them to describe.

THE PAGE'S TEXT IS IN READING ORDER, and every fixture here had ONE show operator on a page until the
selection work needed more.  That is worth writing down because it is the shape of the mistake: the
separator BETWEEN runs was not observable, so the port joined them with nothing and answered
"alphabeta" on a two-run page where the host answers "alpha\nbeta" - and on a three-run page,
"shared oneshared twothird line", 30 characters, where the host answers "shared one\nshared two\nthird
line", 32.  Three fixtures written through the same conforming writer fix both halves:

    cgfixture-pair-down.pdf   "alpha" at y=360 then "beta" at y=340   host: "alpha\nbeta"    (10 chars)
    cgfixture-pair-up.pdf     "alpha" at y=340 then "beta" at y=360   host: "beta\nalpha"    (10 chars)
    cgfixture-pair-same.pdf   both at y=360                             host: "alphabeta"      (9 chars)

So the answer is sorted by y DESCENDING - top of the page first - with a tie keeping DRAWING order, and
consecutive runs are joined with a newline when their y DIFFERS and with NOTHING when it does not.  The
middle row is the one a rule written from the first alone gets wrong: drawn bottom-first, answered
top-first.  `cgfixture-lines.pdf`, three runs at y = 360, 340, 320, is the three-run case, and it found
the defect on its first run.

THE COORDINATES MUST BE DERIVED.  A probe using a fixed rect at y=360 answers "page 1" on revenant-fixture-1
and EMPTY on revenant-fixture-3 - the same text, the same page index, because the two fixtures draw at y=360
and y=752.  A selection is POSITIONAL, and a typed-in coordinate is a fixture that passes for the wrong
reason.  The committed probe reads the text matrix out of the page's own content stream and asks at the
text:

    $ .agent-work/fin/sel-probe3 .agent-work/runs/pdfkit-document/fixtures/revenant-fixture-{1,3,0}.pdf

    revenant-fixture-1.pdf  text at (20,360)  rect=15,355,100,25
      rect -> page 1    word -> page  ranges=1  bounds=20.0000,357.2400,26.6952,12.0000    line -> page 1  byLine=1
    revenant-fixture-3.pdf  text at (20,752)  rect=15,747,100,25
      rect -> page 1    word -> page  ranges=1  bounds=20.0000,749.2400,26.6952,12.0000    line -> page 1  byLine=1
    revenant-fixture-0.pdf  text at (0,0)     rect=-5,-5,100,25
      rect -> (empty)   word -> (empty) ranges=0  bounds=inf,inf,0.0000,0.0000              line -> (empty) byLine=0

FOUR ANSWERS, and each one is a boundary the port will have to meet:

1. AN ABSENT SELECTION IS AN EMPTY ONE, not nil.  A selection made at a point with no text under it
   answers an OBJECT whose -string is "" and whose range count is 0 - measured on revenant-fixture-0, which
   draws no text at all.  "No text here" and "a selection with no text" are the same answer.

2. AN EMPTY SELECTION'S -boundsForPage: IS NOT A RECT.  It answers {inf, inf, 0, 0} - an INFINITE origin
   with a zero size, neither CGRectZero nor CGRectNull.  A port answering zero would differ from the host
   by an infinity, and the harness's 0.001 tolerance would pass it silently.  This is why the harness must
   print those four numbers as text for an empty selection rather than comparing them as a rect.

3. -rangeAtIndex:onPage: ANSWERS A SENTINEL PAST THE END.  {0, 4} for the word "page", and
   {9223372036854775807, 0} for an index past it - NSNotFound's location with a zero length, and NOT a
   zero range, because {0, 0} would name the first character instead of nothing.

4. THE STRING MEMBERS ARE NOT BUILDABLE FROM PUBLIC API.  The host's -attributedString carries NSFont,
   NSColor, CTBaselineOffset and a PRIVATE kCPfillColor key; a port cannot produce that last one with
   public API and there is no measurement that says a public equivalent would do.  -string itself inherits
   the line-break and kerning thresholds -[PDFPage string] does not locate, and that boundary is now
   measured rather than assumed: see below, where the walk IS bounded and DOES agree.

WHAT IS OWED, stated as work rather than as a refusal:

  the three entry points -[PDFPage selectionForRect:], -selectionForWordAtPoint: and
  -selectionForLineAtPoint:, so a selection is reachable at all
  the same keys printed from BOTH sides of the two-binary differential, so the claims above are compared
  rather than probed
  -selectionsByLine needs a MULTI-LINE fixture: it answers 1 on every fixture here and every fixture has
  one line, so "one line" and "always one" fit the data identically
  -color has no measurement to build a default from, the host answering nil on every fixture, and a
  missing key in this dictionary is not always nil - a /Highlight answers a default sRGB yellow and a
  /Square a default border line

## The token walk: the symbols exist, it TERMINATES, and it OVER-READS

The reason above for -[PDFPage string] and -[PDFSelection string] being inert was that the token walk
"needs CGPDFScannerScanString and CGPDFScannerGetString, which are absent".  That is true and it is also
INCOMPLETE - the rest of the door is open:

    $ grep -n "CGPDFScanner" $SDK/System/Library/Frameworks/CoreGraphics.framework/Headers/CGPDFScanner.h
      CGPDFScannerCreate, CGPDFScannerScan, CGPDFScannerPopObject, CGPDFScannerPopString,
      CGPDFScannerPopArray, CGPDFScannerPopDictionary, CGPDFScannerStop        (no ScanString, no GetString)
    $ grep -n "CGPDFOperatorTable" $SDK/.../CGPDFOperatorTable.h
      CGPDFOperatorTableCreate, CGPDFOperatorTableSetCallback

A walk built over the Pop* family and an operator table RECOVERS THE TEXT.  Measured on a fixture written
by a conforming writer, tools/make-text-fixture.m, which is the release's own CGPDFContext:

    $ xcrun clang -fobjc-arc -Wall -framework Foundation -framework CoreGraphics -o walk walk.m
    $ strings .agent-work/runs/pdfkit-document/fixtures/cgfixture-1.pdf | grep -a /Length
      << /Length 82 /Filter /FlateDecode >> << /N 3 /Alternate /DeviceRGB /Length 2612 /Filter /FlateDecode >>
    $ timeout 20 ./.agent-work/fin/walk .agent-work/runs/pdfkit-document/fixtures/cgfixture-1.pdf
      cgfixture-1.pdf   [BUDGET EXHAUSTED]   p1=page 1page 1page 1page 1   rc=0

IT TERMINATES, AND IT OVER-READS.  CGPDFScannerScan does not answer false at the end of a content stream:
past the single Tj it keeps returning true and re-delivering the last operand, so an unbounded
while-loop does not end and a bounded one runs to its budget.  That is the real measured behaviour, and it
is why the two string rows are inert: the walk finds the text but has no end-of-stream signal to stop on,
so "the text of the page" would be "the last operand, repeated".  A walk needs a stop condition of its own
- a count of the stream's own bytes, or the operators that end a text object - and that is owed work, not
a refusal.

WHAT WAS WRONG BEFORE, and it is worth the space because the mistake is reusable.  An earlier version of
this file said the walk "does not return", hung, and blamed a /Length that did not match the stream.  All
three were wrong.  The probe had been compiled with -isysroot pointing at the IOS SDK and then RUN on
macOS, and the resulting binary was killed before it printed its first line - rc 137, a SIGKILL, which I
read as a hang.  The hand-written fixture was blamed because it was the one the walk was run against first,
and CGPDFContext fixtures turned out to carry the SAME /Length 82.  Two things to carry forward: a
host-side probe is built WITHOUT -isysroot, and rc 137 is SIGKILL and not a timeout - `timeout` reports
124 - so a 137 means the process was killed, and the first thing to print is the step it reached.


## The walk is bounded and the string rows are MEASURED, not owed

    $ sh tests/backports/host/pdfkit-document/run.sh
      COMPARED 727 MISMATCHES 0  (not compared: 18, expected to differ: 54)
      agree  cgfixture-1.pdf.page0.string             host='page 1' port='page 1'
      agree  cgfixture-3.pdf.page0.string             host='page 1' port='page 1'
      agree  cgfixture-bare.pdf.page0.string          host='(nil)'   port='(nil)'
      agree  cgfixture-1.pdf.page0.numberOfCharacters host='6'        port='6'
      agree  cgfixture-bare.pdf.page0.numberOfCharacters host='0'      port='0'

THE BOUND IS THE PAGE'S OWN SHOW-OPERATOR COUNT, counted off the decompressed stream's bytes.  It took two
attempts and the first one is the part worth keeping: the first bound was on how many TOKENS the scanner
hands out, which fires at once, because the scanner over-reads and the token count passes the stream
length inside the first page.  The walk was then DISCARDING its own correct answer - nine annotation
fixtures answered nil where the host answered "annotated".  A BOUND ON THE SCANNER'S OWN BEHAVIOUR CANNOT
STOP A SCANNER THAT DOES NOT SIGNAL ITS END; the bound has to be a fact about the DOCUMENT.

The walk terminates, the per-page answers are right, and the three show operators are covered: Tj, TJ, and
the two single-character ones.  A number in a TJ array is a kerning adjustment and is NOT appended, which
is the difference between "page 1" and "page  1" and is measured, not assumed.

AND THE FIXTURE THAT MEASURED IT.  tools/make-text-fixture.m writes through the release's own
CGPDFContext, so the walk is measured on files a conforming writer produced.  Its first version passed one
string for all three pages, so pages 2 and 3 drew "page 1" and the host answered "page 1" for all three -
which looked like the host ignoring the page and was the tool drawing the same words three times.  Each
page now names itself, which is what makes "page 1", "page 2", "page 3" a measurement.  A fixture that
cannot fail is not a fixture, and that one hid for a whole run.

RED CONTROL, the walk unbounded, which is the shape the code had before the bound: the run exits 124,
having run to the wall clock.  That is the over-read, timed.

## Whitespace and control bytes in the page's own text: the walk was joining runs verbatim

The word-boundary family for `PDFSelection` (`Selection11.md`) needed the page's `-string` to be exact,
because a selection's range is an OFFSET into it. Ten new fixtures through the conforming writer, and
three byte-level ones beside them, made the harness red on eight keys that were all this row:

    COMPARED 8106 MISMATCHES 8
      cgfixture-gap.pdf.page0.string              host='alpha bravo'  port='alpha  bravo'
      cgfixture-gap.pdf.page0.numberOfCharacters  host='11'           port='12'
      cgfixture-tail.pdf.page0.string             host='alpha'       port='alpha '
      cgfixture-tail.pdf.page0.numberOfCharacters host='11'           port='12'
      cgfixture-lead.pdf.page0.string             host='alpha bravo\ncharlie'  port=' alpha bravo \ncharlie '
      cgfixture-lead.pdf.page0.numberOfCharacters host='19'          port='22'
      cgfixture-inline.pdf.page0.string           host='alpha'       port='alpha bravo'
      cgfixture-tab.pdf.page0.string              host='alpha'       port='alpha bravo'

**A LINE is trimmed at both ends and the runs of U+0020 inside it are collapsed to one.** Five fixtures
say it, and the fifth is the one that says *line* and not *run*:

    drawn "alpha  bravo"                      answers "alpha bravo"
    drawn " alpha bravo "                     answers "alpha bravo"
    drawn "alpha " then "bravo" on a new line answers "alpha\nbravo"
    drawn "alpha  b   c"                      answers "a b c"
    drawn "alpha " then "beta" at the SAME y   answers "alpha beta"

The last one is the whole of it: the walk joins a tie on y with nothing, so a space at the end of a run
survives when the next run is on the same line and is gone when the next run is on another. The trim is
therefore where the LINE ends, and the collapse is inside the line's own text.

**A control byte in a show string is a NUL in the text, and the release's own decoder is what hid it.**
`CGPDFStringCopyTextString` maps a NUL byte to a space and a tab to a tab, so a run carrying either
arrived here indistinguishable from a run that really drew a space. Both sides' `-numberOfCharacters`
answered 11 on `cgfixture-inline` and the two `-string`s printed differently, because a NUL ends a `%s`:
the host printed its first five characters and the port printed all eleven with a space at index 5.
Measured over a byte-level fixture whose one show string is `a \0 b \1 c \t d \n e \r f \37 g \177 h`:
the host answers 15 characters, `a \0 b \0 c \0 d \0 e \0 f \0 g \0 h`, so the LENGTH is the byte count
whatever the bytes are and only the CHARACTER changes. The characters still come from the release's
decoder, which knows the string's encoding, and the control bytes from the release's byte reader beside
it, and the two are zipped. A UTF-16BE string (a FE FF byte-order mark) is not zipped that way and the
decoder's own characters stand.

What is NOT measured here, and is not claimed: a code at 0x80 or above. The host resolves those through
the FONT's encoding and answers the glyph's Unicode where the font has one - byte 0xE9 in a base-14 font
answers U+00D8 - and a NUL where it has none (0x80, 0x8E, 0xA0, 0xFF all answer NUL). This walk keeps the
decoder's character for those bytes, which is the same character it answered before and is not the host's.
Reading the font's /Encoding and its /Differences is the metrics engine's work, not this walk's.

## Every named red control in this harness was a no-op until 2026-10-03

The controls above caught a defect in the harness itself. `compare()` plants its mutation in a scratch
copy of the port's answers, and it found the line to replace by looking for a `port.` PREFIX - but
`read()` takes a line's key to be its name with the side's prefix removed WHEN THERE IS ONE, because the
class-level facts are printed as `port.<key>` and every per-fixture fact is printed as a BARE `<key>`.
So for every per-fixture key the writer found no line, wrote the file through unchanged, and the
comparison then printed `MUTATION failed: ... the comparison is blind` and exited non-zero - which the
control loop read as a PASS, because it only checked that the log said `MUTATION planted on`.

    116 mutation logs, 116 of them saying "MUTATION failed", 0 of them containing a DIFFER line

The one automatic control was real by accident: the key it picks is `PDFDocument.hasInitWithURL`, which is
one of the prefixed ones. Every control that named a border, an appearance, an action, an outline or a text
key proved nothing for as long as it stood there. Two changes: the line is found by its KEY and keeps
whatever prefix it has, and a key in no line is a refusal rather than a silent no-op; and the control loop
requires a `DIFFER` line, not merely a non-zero exit. All 117 named controls and the automatic one now
report a difference naming their own key.

Self-review's rule - a control that fires - is what this was worth: the check existed, printed "ok", and
had never been asking anything.

## Encryption: the members are a CoreGraphics reading, and the old NO was wrong

The earlier answers of NO for `isEncrypted` and `isLocked` rested on the claim that CGPDFDocument has no
reader for the trailer. That is true of the trailer. It is not true of the question: CoreGraphics exports
`CGPDFDocumentIsEncrypted`, `CGPDFDocumentIsUnlocked` and `CGPDFDocumentUnlockWithPassword` in the 6.1.3
armv7 cache (`xmake l tools/image-exports.lua 6.1.3 armv7 CoreGraphics.framework/CoreGraphics CGPDFDocument`),
and the port reads through those three.

Measured on the host (`tests/backports/host/pdfkit-encryption`, fixtures written by CGPDFContext's own
encryption):

| fixture | isEncrypted | isLocked | unlock with the right password | unlock with a wrong one |
| --- | --- | --- | --- | --- |
| plain | NO | NO | YES, posts nothing | - |
| owner-only (owner password only) | YES | NO | YES, posts nothing | YES (already open) |
| user-locked (user password `secret`) | YES | YES | YES, posts PDFDocumentDidUnlock once, then isLocked NO | NO, posts nothing, stays locked |

- `pageCount` is 2 on the locked document as well as the open one, and the port's CoreGraphics count agrees.
- `unlockWithPassword:nil` on the locked document answers NO and does not crash.
- An empty document (`-init`) answers NO, NO, YES for unlock, and 0 pages.

The port's `-unlockWithPassword:` returns YES when `isLocked` (read through CoreGraphics) is NO, which is the
host's answer for plain, owner-only and empty documents alike. It posts the notification only on
the locked-to-open transition.

The harness has a planted control: a copy of the port in which `isLocked` answers NO goes red on the
`user-locked` fixture.

Not covered: the document-level permissions (`allowsCopying`) for an encrypted file, which still answer YES
on every fixture here, and the page text of a locked document read before unlocking.
