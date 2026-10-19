# PDFAction and its five subclasses, and PDFDestination

## What the seven classes are

Neither band carries any of them: `objc.inventory` reports `PDFDestination`, `PDFAction`,
`PDFActionGoTo`, `PDFActionNamed`, `PDFActionURL`, `PDFActionRemoteGoTo` and `PDFActionResetForm` as
carried by neither 6.1.3 nor 4.3, with `ZZNotAClassAnywhere` answering "not carried". So all seven are
the port's own, like `PDFDocument`, `PDFPage`, `PDFBorder` and `PDFAppearanceCharacteristics`.

They are read out of an annotation's `/A` action dictionary (PDF 1.7 Table 8.44) and its `/Dest`, through
`tests/backports/host/pdfkit-document`, the same harness the first two families use: one verdict line, a
red control per rule, and every fixture a file whose dictionaries this repository writes.

**All six designated initializers are implemented.** That is not padding - the coordinator sent the first
commit back for asking about `PDFBorder`'s, and the answer was measured before any of this code was
written: `[[PDFDestination alloc] init]`, `-initWithPage:atPoint:`, `-initWithDestination:`,
`-initWithName:`, `-initWithURL:`, `-initWithPageIndex:atPoint:fileURL:` and `-init` on the reset form all
work on the host, and the harness compares each of them in its own `init.*` keys.

## The page a destination names, and the one API this SDK does not have

A destination is `[pageRef /XYZ left top zoom]`, so something has to turn `3 0 R` into a `PDFPage`. **This
SDK's C API has no object-number accessor at all** - `CGPDFDictionary` and `CGPDFArray` expose no way to
ask an indirect reference for its number. What it does have is `CGPDFArrayGetDictionary`, which *follows*
the reference, so the port takes the pointer that comes back and matches it against `CGPDFPageGetDictionary`
over the document's pages.

That was measured before it was relied on, because it is the load-bearing step of every destination:

    element 0 resolves to a dictionary: 1  page1=0 page2=1

on a two-page fixture whose `/D` names object 4 - the pointer equals page 2's dictionary and not page
1's. And `act-goto-page2` is the fixture that shows it end to end: the host answers page index 1 and so
does the port.

**That needed a fix in `PDFDocument`.** `-[PDFDocument pageAtIndex:]` built a *fresh* `PDFPage` on every
call, so the differential - which finds a destination's page by asking the document for each of its pages
and seeing which one is that object - never matched, and answered the page count instead of the index. The
host answers the **same object** on two calls. The pages are now built once and kept, the same fix
`-[PDFPage annotations]` got in the previous commit and for the same reason.

## `-[PDFAction type]`, and the class each `/S` builds

`-type` is the `/S` **name**, not a string fixed by the class, and it is nil on a freshly allocated action.

| `/S` | the host builds | fixture |
| --- | --- | --- |
| `/GoTo` | `PDFActionGoTo`, even with no `/D` | `act-goto-xyz`, `act-goto-no-d` |
| `/Named` | `PDFActionNamed`, for eight of the twelve names only | `act-named-all` |
| `/URI` | `PDFActionURL`, even with no `/URI` | `act-uri` |
| `/GoToR` | `PDFActionRemoteGoTo`, even with no `/F` | `act-gotor` |
| `/ResetForm` | `PDFActionResetForm` | `act-reset` |
| `/Bogus` | **`PDFAction`**, the base class, with `-type` "Bogus" | `act-unknown-s` |
| *no `/S`* | **nothing at all** | `act-no-s` |

So an action dictionary without an `/S` answers nil, and an `/S` the format does not list answers the base
class. Both are absences with an object behind them, and both are in the harness.

## `PDFActionNamed`: the host's eight names, not the enum's twelve

`act-named-all.pdf` carries **all twelve** names the 26.2 enum declares plus one it does not list, one
annotation each, and the host answers an object for exactly eight:

| `/N` | enum | the host builds |
| --- | --- | --- |
| *none* | None 0 | **no action** |
| `/NextPage` | 1 | yes, `-name` 1 |
| `/PreviousPage` | 2 | **no action** |
| `/FirstPage` | 3 | yes, `-name` 3 |
| `/LastPage` | 4 | yes, `-name` 4 |
| `/GoBack` | 5 | yes, `-name` 5 |
| `/GoForward` | 6 | yes, `-name` 6 |
| `/GoToPage` | 7 | yes, `-name` 7 |
| `/Find` | 8 | yes, `-name` 8 |
| `/Print` | 9 | yes, `-name` 9 |
| `/ZoomIn` | 10 | **no action** |
| `/ZoomOut` | 11 | **no action** |
| `/NotAName` | - | **no action** |

Reading the name as its enum value would answer an object for all thirteen, four of which the host never
builds - so this is an eight-entry table mapping each name to the value it answers, not the enum.

`-initWithName:` keeps whatever it is given, and so does the host's: 0 and 99 both come back as 0 and 99
(`init.namedNone.name`, `init.named99.name`).

## `PDFDestination`: four ways to get no destination, and one that looks like a fifth

The reader refuses, and every refusal below is a fixture in `act-goto-shapes`:

* the `/D` is not an array - `/D 3` and a `/D` that is a dictionary both answer **no destination**;
* the array has no second element - `[3 0 R]` answers **no destination**;
* the second element is a name the format does not list - `[3 0 R /Zoom 3]` (a PDF 1.0 name the format
  dropped) and `[3 0 R /Bogus 1 2]` both answer **no destination**;
* the **first** element is a *name* - `[/XYZ 1 2 3]` answers **no destination** on the host with a
  perfectly good `/XYZ` behind it. That one needed measuring the SDK's own reader to tell apart, because it
  is not "no page named" but "no page wanted": `CGPDFArrayGetName(array, 0, ...)` succeeds for that element
  and fails for every page reference, which every `/D` fixture in the run confirms.

And the case that looks like all four but is none of them: a **named** destination - the format's other
spelling, `[page /XYZ]` against `(aName)` - answers a `PDFDestination` whose **page is nil**, over both of
the `/Dests` spellings this harness writes (a name tree and a plain dictionary, `act-goto-named` and
`act-goto-named-dict`). So the port builds the object with nothing in it and does not resolve the name:
the host does not resolve it either on these fixtures, and a name it *did* resolve would be a second answer
nothing here has measured.

## `PDFDestination`'s three members

**`-page`** is weak, as `PDFDestination.h:19` declares, and nil in the two cases above. It is a page and
not an index - `act-goto-page2` answers page index 1 for a `/D` naming object 4.

**`-point`** is the `/XYZ` left and top, read by position and each independently: `/XYZ 5 6` answers
`(5, 6)` with an unspecified zoom, `/XYZ 7` answers `(7, unspecified)`, `/XYZ` with no numbers answers
unspecified for both. **Every other fit name answers an unspecified point** - `/Fit`, `/FitB`, `/FitH`,
`/FitBH`, `/FitBV`, one fixture each - and the last three carry numbers of their own, which are the box to
fit and not a position.

**`-zoom`** is the `/XYZ` zoom, and **a zero is not a value**: `/XYZ 0 0 0` answers an unspecified zoom
while its point answers `0,0`, and `/XYZ -1 -2 -3` answers zoom `-3`. So the point reads a zero and the
zoom does not - measured both ways rather than assumed.

The unspecified answer is `kPDFDestinationUnspecifiedValue`, which the port already exported as
`(CGFloat)FLT_MAX` - **the host's own value, and not `CGFLOAT_MAX`**, already recorded in
`registry/PDFKit/constants.json`. It is compared as the number it is, not symbolically, and that matters:
`FLT_MAX` is the same number on a 32-bit and a 64-bit `CGFloat`, while `CGFLOAT_MAX` would not be.

**The page and the numbers are read independently.** `act-goto-badpage-xyz`'s `/D` is
`[99 0 R /XYZ 1 2 3]` where object 99 is not a page, and the host answers page nil **and** point `1, 2` with
zoom `3`. An earlier version of the reader returned at the failed page lookup and answered the unspecified
sentinel for all three.

## `PDFActionURL.URL`, and `PDFActionRemoteGoTo.URL`

`-URL` on a `/URI` action is the string read out of the dictionary handed to `NSURL`. The host answers
`https://example.com/a b` as `https://example.com/a%20b`, a relative `/URI` as itself, and keeps a fragment
(`act-uri`, `act-uri-shapes`). That percent-encoding is `NSURL`'s own, which both sides share, so what the
comparison establishes is that the port read the right string out of the dictionary - not that the port has
its own URL parser.

`-URL` on a `/GoToR` action is the `/F` **resolved against the document's own directory, as a relative name
whatever it looks like**:

| `/F` | the host answers |
| --- | --- |
| `other.pdf` | `file:///.../fixtures/other.pdf` |
| `https://example.com/other.pdf` | `file:///.../fixtures/https://example.com/other.pdf` |

That second row is why the resolution is a string concatenation of a **path**, not of a URL's
`absoluteString`: concatenating the URL string gives `file:/...` - one slash - where the host answers
`file:///...`, and `act-goto-page2` is the fixture that showed it. An action with no `/F` answers nil, and so
does a document opened with no URL of its own.

## `PDFActionRemoteGoTo.pageIndex` and `.point`

`-pageIndex` is **0 on every `/GoToR` fixture measured, and that is not a constant standing in for
behaviour.** The host's own `-initWithPageIndex:atPoint:fileURL:` keeps the index it is given and answers 2
for 2 (`init.remote.class`). The 0s are a *reading* result: `act-goto-page2`'s `/D` names object 4, which
**is** the second page of that document, and the host still answers 0 - because a remote action's page
belongs to the *other* file, which is the whole point of a remote action. A `/D` that is a page index
rather than a page reference answers 0 as well.

`-point` is **unspecified on every `/GoToR` fixture**, including the two whose `/D` is an `/XYZ` with
numbers in it. So a remote action's position is not read out of its `/D` either, and
`-initWithPageIndex:atPoint:fileURL:` is what puts a point on one.

## `PDFActionResetForm`: `-fieldsIncludedAreCleared` is about BOTH keys

`act-reset-flags.pdf` carries seven combinations of PDF 1.7 Table 8.44's two keys, one annotation each:

| `/Flags` | `/Fields` | `-fieldsIncludedAreCleared` |
| --- | --- | --- |
| *absent* | present | **YES** |
| 0 | present | **YES** |
| 1 | present | **NO** |
| 2 | present | **YES** |
| 3 | present | **NO** |
| 1 | absent | **NO** |
| 2 | absent | **NO** |

So it is YES exactly when `/Fields` is present **and** the `/Flags` bit of value 1 is clear. The last two
rows are what make it a rule about both keys rather than about the bit: `/Flags 2` alone would answer YES
if only the bit mattered, and it answers NO.

`-init` - the header's own designated initializer - answers **YES** with no fields, which is the header's
default and *not* what a dictionary carrying neither key reads as (`act-reset`'s second annotation answers
NO). Both are in the harness, because "the default" and "the read" are two different answers.

## `-[PDFAnnotation action]` and `-[PDFAnnotation destination]`

These are the two ways a program reaches the family, and both were `inert`/`missing` before it.

**`-action`** is the `/A` dictionary through the factory above, with one more measured shape: a **bare
`/Dest` produces an action.** The format's own rule is that a `/Dest` without an `/A` is a `/GoTo` to that
destination, and the host builds one (`ann-dest-array`, `ann-dest-named`). It is built through the header's
own `-initWithDestination:` over the very object `-destination` answers, so the two are one object and not
two reads of one array.

**`-destination` is the destination of the action, not the `/Dest` read on its own** - and that is the
opposite of what this first did. `ann-dest-and-a` carries **both** a `/Dest` whose `/XYZ` names `(1, 2)`
with zoom `3` and an `/A` whose `/D` is a `/Fit`, and the host answers point **unspecified** - the `/A`'s.
So `-destination` is one line over `-action`: the destination of a `/GoTo`, nil for every other action.

Which also means the earlier version of `-destination` and `-action` were **infinite recursion** - each
reached the other - and that showed up as a `SIGSEGV` on the first run, not as a wrong answer. The
destination is now read through a private builder that `-action` calls directly.

The `NSCopying` conformances the headers declare (`PDFAction.h:29` and each subclass) are **not**
implemented: nothing in this port copies an action, a destination or a border, and neither release asks for
`-copyWithZone:`.

## `-copy`, which the header's `NSCopying` makes reachable

`PDFAction.h:29` and `PDFDestination.h:24` both declare `NSCopying`, so a caller can write `[action copy]`.
"Not implemented, nothing in this port copies an action" is not a defence: the caller is not this port.
Measured on the host, in the harness's own `copy.*` keys:

| | answered |
| --- | --- |
| the copy's class | the original's own class, every one of the seven |
| the copy IS the original | **no** - `copy.action.same` 0 for a bare `PDFAction` too |
| `PDFDestination`'s **page** | **the same object** - a destination names a page and does not own it, and the page is weak here as `PDFDestination.h:19` declares |
| `PDFDestination`'s zoom | copied, and **independent**: 9 on the copy leaves 2.5 on the original |
| `PDFActionGoTo`'s destination | a **new** object - the copy's destination is not the original's, and its page is again the same page |
| `PDFActionNamed`'s name | copied and independent - 9 on the copy leaves 8 on the original |
| `PDFActionURL`'s URL, `PDFActionRemoteGoTo`'s three members | copied |
| `PDFActionResetForm`'s `-fields` | **the same array**, `copy.reset.fields.same` 1 - the one shallow member in the family |
| a destination with **no page**, copied | an object, `copy.nopage` - so `-copyWithZone:` cannot be built through `-initWithPage:atPoint:`, which answers nil for a nil page |

## `-initWithPage:atPoint:` answers no object for a nil page

Found by the harness rather than asked for. The copy block was written against
`initWithPage:nil atPoint:(3, 4)` and the host answered **nil** for it, so every read off that object
answered nil or zero and `[made copy]` answered nil as well - nine differences that all said the same
thing. The SDK does not say why; the measurement is that a caller who passes no page gets nothing back,
and the port does the same.

So `PDFDestination`'s plain `-init` cannot reach its state through `-initWithPage:atPoint:`, and sets the
three members itself: no page, and an unspecified point and zoom.

## The four subclasses have no `-init`, and the cache says so

`[[X alloc] init]` works on the host for all four and answers a **nil `-type`** for each - measured:

| | `-type` | members |
| --- | --- | --- |
| `[[PDFActionGoTo alloc] init]` | nil | destination nil |
| `[[PDFActionNamed alloc] init]` | nil | name `kPDFActionNamedNone` |
| `[[PDFActionURL alloc] init]` | nil | URL nil |
| `[[PDFActionRemoteGoTo alloc] init]` | nil | index 0, point **unspecified**, URL nil |

(`[[PDFActionResetForm alloc] init]` is the exception and not an `-init` override: `-init` **is** that
class's designated initializer, so it answers `-type` "ResetForm" - measured.)

A nil `-type` is the point: a type name belongs to a dictionary the object was not built from.

**Which of these classes defines `-init` of its own is a question about metadata, and the answer is read
from the iOS 16.0 arm64e cache** with the tree's own census (`modules/apple/objc.lua`, the reader the
registry's class census uses), by `.agent-work/v-pdfkit/own-inits.lua`, run through
`coordination/heavy.sh`:

    PDFAction                own -init: 1     16 instance methods of its own
    PDFActionGoTo            own -init: 0     12 instance methods of its own
    PDFActionNamed           own -init: 0     11 instance methods of its own
    PDFActionURL             own -init: 0     11 instance methods of its own
    PDFActionRemoteGoTo      own -init: 0     16 instance methods of its own
    PDFActionResetForm       own -init: 1     14 instance methods of its own
    PDFDestination           own -init: 1     17 instance methods of its own
    PDFBorder                own -init: 1     31 instance methods of its own

So the four subclasses have **no** `-init` and `[[X alloc] init]` reaches `PDFAction`'s - which is why a
fresh action's `-type` is nil - while `PDFAction`, `PDFActionResetForm`, `PDFDestination` and `PDFBorder`
each have one. Apple's headers declare `-init` for **none** of the eight: they declare only each class's
designated initializer (`PDFActionGoTo.h:25`, `PDFActionNamed.h:45`, `PDFActionURL.h:22`,
`PDFActionRemoteGoTo.h:27`, `PDFActionResetForm.h:26`, `PDFDestination.h:29`), so a class that has an
`-init` implements one its header does not declare and the four that do not, do not.

**One measurement went wrong before it went right, and it is worth recording.** The first version of the
script asked `entry.instance["init"]` and reported `own -init: 0` for **all eight** classes - which would
have "confirmed" that none of them has one and removed `PDFBorder`'s and `PDFAction`'s along with the
four. The keys are **spelled** selectors with a leading dash for an instance method: `PDFBorder`'s own
list is `-.cxx_destruct`, `-_isRectangular`, `-_setDashFromArray:`, `-init`,
`-initWithAnnotationDictionary:forPage:`, `-lineWidth`, and a bare `init` is nowhere in it. The table
above asks for `-init`.

**The fresh state comes from storage, not from an initializer.** `PDFActionRemoteGoTo`'s fresh point is
the *unspecified* sentinel while `alloc` zeroes the ivars, so the class carries `BOOL _pointIsSet`:
`-point` answers the sentinel while it is clear, and `-initWithPageIndex:atPoint:fileURL:` sets it
whatever point it was given, so a point that *was* set is answered as set - including the origin. The
dictionary reader clears it again, because a remote action's `/D` is not read for a point (measured:
unspecified on every `/GoToR` fixture, `/XYZ` included).

**The warning is scoped away per class, with the measurement above named in the comment.** clang asks for
the `-init` override because the header marks each subclass's own initializer
`NS_DESIGNATED_INITIALIZER`, which makes the inherited `-init` a *convenience* initializer.
`PDFDestination` is the same case for its own reason: the cache gives it an `-init` (`own -init: 1`) while
`PDFDestination.h` declares none, so its `-init` is implemented and the diagnostic about the shape is
scoped away. Each is a `#pragma clang diagnostic push` / `ignored` / `pop` around one `@implementation` -
the arrangement `PKPaymentRequestStatus11.m`, `MTLRasterizationRate13.m` and `PHObject8.m` already use
for this diagnostic.


## What is NOT here, and why

* **`-[PDFDestination compare:]`** (`PDFDestination.h:26`). No ledger row names it and no fixture in this
  harness reaches it; it is left out rather than guessed at.
* **Resolving a named destination.** Measured to answer a nil page on the host for both `/Dests`
  spellings, so the port does not resolve it and says so in the row.
* **A colour parser for the `/BC` arrays of a widget's `/MK`.** That belongs to `-[PDFAnnotation color]`,
  which is `inert` on main; what this family needed of it - a component count - is measured in
  `Border11.md`.

## The run

    $ sh tests/backports/host/pdfkit-document/run.sh
      images differ by construction: host=/System/.../PDFKit.framework/.../PDFKit
                                      port=.../runs/pdfkit-document/port-side
      COMPARED 6403 MISMATCHES 0  (not compared: 105, expected to differ: 315, of which 72 compared from the Catalyst side)
      RED CONTROL ok: the comparison goes red on a mutated port, and names the key
      RED CONTROL ok for act-goto-xyz.pdf.page0.annotation0.action.class
      RED CONTROL ok for act-goto-badpage-xyz.pdf.page0.annotation0.actionGoTo.destination.zoom
      RED CONTROL ok for act-goto-page2.pdf.page0.annotation0.action.URL
      RED CONTROL ok for act-named-all.pdf.page0.annotation1.action.name
      RED CONTROL ok for act-named-all.pdf.page0.annotation0.action
      RED CONTROL ok for act-reset-flags.pdf.page0.annotation2.action.cleared
      RED CONTROL ok for ann-dest-and-a.pdf.page0.annotation0.destination.point.x
      RED CONTROL ok for init.remote.class
      ... 68 red controls in all, 51 of them naming an action, destination, initializer or copy key -
      among them initdest.nilpage, initgoto.class, initnamed.class, copy.destination.same,
      copy.destination.page.same, copy.destination.zoomAfterSet, copy.destination.zoomOriginal,
      copy.nopage, copy.goto.destination.same, copy.goto.destination.page.same,
      copy.named.nameAfterSet, copy.remote.pageIndex, copy.reset.fields.same and copy.action.class

105 fixtures, 88 of them this series' - 3 box, 3 hand-written text, 9 annotation and 2 conforming-writer
text from before, plus 88 from `tools/make-object-fixtures.py`, each with every xref offset measured from
the object bytes as they are written.
## /Launch: the host's PDFActionURL, typed Launch, with the /F as its URL

Measured by `tests/backports/host/pdfkit-annotations` (annot-launch, annot-launch-spec, annot-launch-win):

- `-class` is `PDFActionURL` and `-type` is `Launch`. The port answered the base `PDFAction` until this change,
  because the chooser had no case for `/Launch`; no earlier fixture carried one, so nothing measured it.
- `-URL` is the top-level `/F` resolved against the document's directory, as `-[PDFActionRemoteGoTo URL]` resolves
  its own `/F`: `file://<document directory>/other.pdf`.
- A file specification in place of the string (`/F << /F (other.pdf) >>`) gives the same URL.
- A `/Launch` with no top-level `/F` (only `/Win << /F (other.exe) >>`) answers a `PDFActionURL` whose URL is nil.

The port reads the `/F` the same way and sets the type name to `Launch`. Where the document has no URL the file is
not resolved, which is the rule the `/GoToR` path already keeps; no fixture here opens a document without a URL.
The `/Win` platform dictionary is not read: the host answers nil for it, and the port does too.
