# PDFBorder over an annotation's /Border array and /BS dictionary

## What the class is

`PDFBorder` is a class neither band carries: `objc.inventory` reports `PDFBorder` as carried by neither
6.1.3 nor 4.3, with `ZZNotAClassAnywhere` answering "not carried". So it is the port's own class, like
`PDFDocument` and `PDFPage`, and its substrate is the release's own dictionary reader -
`CGPDFDictionaryGetDictionary`, `CGPDFDictionaryGetArray`, `CGPDFDictionaryGetNumber`,
`CGPDFArrayGetCount`, `CGPDFArrayGetNumber`, all exported by both bands.

**`PDFBorder.h:28` declares no initializer of its own**, so `-init` is `NSObject`'s - and the object it
makes is the host's fresh object: style 0, lineWidth 1, a nil pattern and a key-values dictionary of
`{S = 0, W = 1}`. Measured, and the first version of this page said the opposite ("declares no
initializer at all", with the corollary that `-[PDFAnnotation border]` is the only path), which the
coordinator's own measurement on this Mac contradicts: `[[PDFBorder alloc] init]` works and answers
those values. The class is therefore a **mutable value object**, not a window onto the file, and its
three setters are implemented - see "The setters" below.

`-[PDFAnnotation border]` is still how a border is reached from a document, and its absent answer is
still subtype-dependent: it was `inert` on main with the reason "a /Square with no /Border answers a
DEFAULT border (solid, lineWidth 1.0) and a /Link with none answers nil", and both halves of that
sentence are now measured, so the row is `implemented`.

## The oracle, and the three binaries

The host is this Mac's own PDFKit, over the same fixture files the port reads. Two binaries carry the
document and border facts and `dladdr` proves their images differ by construction (one names
`PDFKit.framework`, the other this binary); the reasoning for not putting both in one process is in
`Document11.md` and has not changed.

The appearance block needs a **third** binary. `PDFAppearanceCharacteristics`' two colour members are
`UIColor`, and `UIColor` does not exist in a macOS process - there the host's type is `NSColor`. Mac
Catalyst has both: UIKit backed by AppKit, and the CoreGraphics the port reads a PDF with. `color.m` is
the port's objects built that way, and `run.sh` merges **its** `appearance.` keys into the port's map
and only those: it refuses the merge outright if the Catalyst side prints a key that is not an
`appearance.` key, and refuses it if that side prints nothing at all. The verdict line says how many
compared facts came from the third binary, so a reader can see the size of the move.

No stand-in colour object is involved on either side. The host sets `NSColor redColor` and this port
sets `UIColor redColor`, and both answer `1 0 0 1` through `-getRed:green:blue:alpha:`, which is the
one method the two classes share. What is compared is the colour, not the class.

## `-[PDFAnnotation border]`, the whole rule

A `/Border` array **or** a `/BS` dictionary in the annotation answers a border, for every subtype.
`border-on-nontype` puts a `/Border` on `/Highlight`, `/Text`, `/Link`, `/Stamp` and `/Popup` - the
five subtypes that answer nil without one - and all five answer W 6. `bs-on-nontype` does the same
with a `/BS` on a `/Highlight` and answers a dashed W 6.

With neither, the subtype decides, and each fixture below is one subtype:

| fixture | subtype | answered |
| --- | --- | --- |
| `noborder-none` | `/Square` | default, W 1 |
| `noborder-circle` | `/Circle` | default, W 1 |
| `noborder-freetext` | `/FreeText` | default, W 1 |
| `noborder-ink` | `/Ink` | default, W 1 |
| `noborder-line-l` | `/Line` with `/L` | default, W 1 |
| `noborder-widget-bc` | `/Widget`, `/MK << /BC [0 0 1] >>` | default, W 1 |
| `noborder-widget-bc-gray` | `/Widget`, `/BC [1]` | default, W 1 |
| `noborder-widget-bc-empty` | `/Widget`, `/BC []` | default, W 1 |
| `noborder-widget` | `/Widget`, no `/MK` | nil |
| `noborder-widget-t` | `/Widget`, a `/T` | nil |
| `noborder-widget-tm` | `/Widget`, a `/Tm` | nil |
| `noborder-widget-bg` | `/Widget`, `/BG [1 0 0]` | nil |
| `border-link`, `noborder-text`, `noborder-highlight`, `noborder-underline`, `noborder-strikeout`, `noborder-stamp`, `noborder-popup` | the rest | nil |

The geometry set is the one PDFAnnotation.h:165 names - "the geometry annotations (Circle, Ink, Line,
Square)" - with `/FreeText` measured alongside them. A `/Widget` needs a border **colour**, which is
`/MK`'s `/BC`, and it has to be a colour the format can describe: `widget-bc` writes four widgets whose
`/BC` are `[0 0 0 1]` (CMYK), `(a string)`, `0.5` (a bare number) and `[0.25 0.5 0.75]` (RGB), and the
host answers a border for the first and the last and nil for the middle two. Together with
`noborder-widget-bc*` and `mk-two` that is every component count PDF 1.7 Table 8.40 defines - none,
one, three, four - plus the two it does not. The host's own log while it does this is the reading:
`Cannot create color from given array of component count 2`. A `/BG` is a background colour and is not
a border colour, and `noborder-widget-bg` answers nil.

## `-style`, and why it is a table

The enum's five values (`PDFBorder.h:15`) are solid, dashed, beveled, inset, underline **in that
order**, and the format's five `/BS` `/S` names are `/S` `/D` `/B` `/I` `/U` **in the same order**. So
reading the name as its ordinal position fits the data perfectly and is still wrong as a rule - it
would break the moment either list changed. All five names are measured (`bs-s`, `bs-d`, `bs-b`,
`bs-i`, `bs-u`), and so is one the format does not list: `bs-q` carries `/S /Q` and answers
`kPDFBorderStyleSolid`, not an out-of-range value. Hence a five-entry table in `PDFBorder11.m`.

No fixture writes a style anywhere but `/BS`, and every annotation whose `/Border` names three numbers
answers solid on all of them (`border-plain`, `border-radii`, `border-zero`, `border-negative`,
`border-long`), so the array carries no style at all.

## `-lineWidth`

`/BS` `/W` when the dictionary has one, the **third** number of `/Border` when it does not.

* `/W` wins: `bs-width-only` writes `/Border [0 0 7]` beside a `/BS` whose only entry is `/W 5` and
  answers **5**.
* The third element and not the last: `border-long` (`[1 2 3 4]`) answers 3.
* The two corner radii are not read: `border-radii` (`[5 7 2]`) answers 2.
* A negative width is a width: `border-negative` (`[0 0 -2.5]`) answers -2.5.
* A zero is a value and not an absent one: `border-zero` (`[0 0 0]`) answers 0, not the default.
* The default is **1**: `border-short` (`[0 0]`), `border-radii-only` (`[5 7]`) and `bs-no-width` (a
  `/BS` with a style, no `/W` and no `/Border`) all answer 1.
* A `/W` that is not a number is refused, not coerced: `bs-width-string` writes `/W (a PDF string)`
  beside a dashed `/S` and no `/Border`; the width answers the default 1 **and** the style answers
  dashed, so the two keys are read independently and one unreadable key does not lose the other.

## `-dashPattern`, and what `[3 2]` is

`/BS` `/D`, and only when the style is dashed.

* `bs-dash-solid` carries `/S /S` beside `/D [4 1]` and answers **nil**: a pattern is not read from a
  border that is not dashed.
* `bs-dash-custom` carries `/S /D` with `/D [7 5]` and answers `[7 5]`. This is the fixture that shows
  the array is read at all.
* `bs-d` carries `/S /D` and no `/D` and answers `[3 2]`; `bs-dash-string` carries `/S /D` with a `/D`
  that is a PDF string and answers the same `[3 2]`. So `[3 2]` is the measured **default** for a
  dashed border whose `/D` is not an array of numbers, and `charonDefaultDashPattern()` is where it is
  written down.

## `-borderKeyValues`

`W` and `S` are always there - both members always answer a value - and `D` is there exactly when
`-dashPattern` answers one. `border-plain` (`/Border [0 0 3]`, no `/BS`) and `bs-dash-solid` answer two
keys each; `bs-d` and `border-bs` answer three.

## The setters

The host's `PDFBorder` is a value object and its setters change **the object**. Measured, each with the
sequence that fixes it:

| sequence | answered |
| --- | --- |
| `[[PDFBorder alloc] init]`, nothing set | `style` 0, `lineWidth` 1, `dashPattern` nil, `{S = 0, W = 1}` |
| `style = Inset` only | `S = 3`, `W = 1`, no `D` |
| `lineWidth = 7` only | `W = 7`, `S = 0`; and `0` and `-3.5` are both kept, not clamped |
| `style = Dashed; lineWidth = 5; dashPattern = @[@7, @5]` | reads back `1`, `5`, `(7 5)`, `{D = (7,5); S = 1; W = 5}` |
| `dashPattern = @[@7, @5]` alone | **`style` becomes 1** - a pattern means a dashed border |
| `dashPattern = @[]` | **`style` becomes 0**, `dashPattern` answers an empty array, `D = ()` |
| `dashPattern = @[]` on a border whose style was dashed | `style` becomes 0 as well, so the setter SETS the style rather than leaving it |
| `dashPattern = nil` on a fresh object | the same as `@[]`: `style` 0, `D = ()`, and `-dashPattern` answers an **empty array, not nil** |
| any of the three, then `dashPattern = nil` | `lineWidth` is **untouched** |

That last row is worth the detail, because the width was the one thing this page first got wrong: an
early probe appeared to show `setDashPattern:` resetting the width to 1. It does not. The probe's own
source had lost its `lineWidth = 5` line, and with it restored the width reads 5 in every arrangement -
four arrangements measured, `W = 5` then a pattern then `nil`; a pattern with no style set then `nil`;
a style then `W = 5` then a pattern then `nil`; and a style then `W = 5` with no pattern, then a pattern,
then `nil`. Ten runs of the same sequence in one process and ten across processes agree.

So the object is one dictionary in the header's own key names - `S` and `W` from `-init`, `D` when a
pattern is set - and `-setDashPattern:` is the only setter that touches more than its own key: it
publishes `D` (an empty array for both `@[]` and `nil`) **and** sets `S` to dashed for a non-empty array
and to solid for an empty one or nil.

## `-[PDFAnnotation border]` identity, and `-[PDFAnnotation setBorder:]`

`PDFAnnotation.h:167` declares the property readwrite, and the host's setter stores the object **by
reference**:

* `-border` answers the **same object** on every call (measured on every fixture, `identity.same` 1).
* A change made through that object is visible through `-border` (`identity.mutated` 9).
* `-setBorder:` makes `-border` answer the very object that was set, `==` (`set.same` 1), a change to that
  object afterwards is visible through the annotation (`set.mutated` 12), and `nil` makes it answer nil
  (`set.nil` 1).
* And a border that was set is **final**: on a `/Square`, whose dictionary answers a default border, the
  host answers nil after `-setBorder:nil` and does not build one again. So the port keeps a flag for
  "a border was set", including to nil, rather than testing the pointer.

**Which needs `-annotations` to hand back stable objects.** Two calls to `-[PDFPage annotations]` answer
two **different arrays** whose elements are the **same objects** (`arrays-same` 0, `objects-same` 1 on
every fixture), and a change made through one is visible through the other. The port rebuilt the whole
array of `PDFAnnotation` objects on every call, which made `-setBorder:` unobservable through the API:
the harness set a border on one array's annotation and read a freshly built, untouched one back. So
`PDFPage11.m` builds the annotations once and hands out a copy of the array each call, which is the host's
own shape rather than a new rule.

## What is NOT here, and why

* **`-drawInRect:`.** It draws, and this port has no context to draw into.
* **`-copyWithZone:` and `-initWithCoder:`** (the `NSCopying`/`NSCoding` conformances). Neither release
  asks for them; nothing in the port copies or codes a border.

## Three defects the fixtures found, in rows this series does not own

The border fixtures needed annotations the port had never been asked about, and three of the answers
were wrong on main. All three are measured, all three are fixed, and none of the fixtures was removed.

1. **`-[PDFAnnotation shouldPrint]` for a `/Popup`.** `popup-flags` carries four `/Popup` annotations
   with `/F 4`, `/F 0`, `/F 2` and no `/F` at all. The host answers **NO for all four**, so no reading
   of the Print bit fits. The same fixture carries a `/Square` and a `/Stamp` with `/F 4`, and both
   answer YES, so the exception is the subtype and not the file.
2. **`-[PDFAnnotation userName]` for a `/Widget`.** `widget-names` carries five `/Widget` annotations -
   one `/FT /Btn` with a `/T`, one with a `/T` and no `/FT`, one `/FT /Tx` with a `/T`, one `/FT /Tx`
   with a `/TU` (PDF 2.0 Table 227's alternate field name) and one with neither - and the host answers
   nil for **all five**, while the same `/T` on a `/Square` answers `square T`. `/TU` is measured
   separately so that "a widget reads a different key" is not left standing unmeasured.
3. **`-[PDFPage annotations]` skips what the host skips.** The `drops` fixture holds thirteen
   annotations and the host hands back two. Dropped: a `/Line`, `/Square`, `/Text`, `/Popup`, `/Ink`,
   `/Circle`, `/FreeText`, `/Stamp` and `/Link`, each with a `/Contents` and **no `/Rect`** - `/Rect`
   is what PDF 1.7 Table 164 makes required of every annotation - and a `/Line` with a `/Rect` and no
   `/L`, whose endpoints are as required for a `/Line` as the rectangle is for everything. Kept: a
   `/Widget` with no `/FT`, which is what stops the rule from being "an annotation missing a required
   key is dropped", since `/FT` is required of a widget by Table 8.39 and the host does not enforce it.
   So the two shapes above are the measured rule and not the format's.

## The run

    $ sh tests/backports/host/pdfkit-document/run.sh
      images differ by construction: host=/System/.../PDFKit.framework/.../PDFKit
                                      port=.../runs/pdfkit-document/port-side
      COMPARED 3632 MISMATCHES 0  (not compared: 73, expected to differ: 219, of which 72 compared from the Catalyst side)
      RED CONTROL ok: the comparison goes red on a mutated port, and names the key:
        MUTATION planted on 'PDFDocument.hasInitWithURL', ...
      RED CONTROL ok for border-plain.pdf.page0.annotation0.border.lineWidth:
      RED CONTROL ok for border-bs.pdf.page0.annotation0.border.style:
      RED CONTROL ok for border-bs.pdf.page0.annotation0.border.dash.values:
      RED CONTROL ok for border-none.pdf.page0.annotation0.border.lineWidth:
      RED CONTROL ok for border-link.pdf.page0.annotation0.border:
      RED CONTROL ok for noborder-widget-bc.pdf.page0.annotation0.border.lineWidth:
      RED CONTROL ok for noborder-widget.pdf.page0.annotation0.border:
      RED CONTROL ok for appearance.full.key.BG:
      RED CONTROL ok for appearance.fresh.key.R:
      RED CONTROL ok for appearance.cleared.keys:
      RED CONTROL ok for appearance.controlType2.keys:

The automatic control plants on the first key the two sides agree on, which is a *document* fact and
would go red even if the border comparison were blind. So the named controls are the ones that say
something about this family - twenty-four of them now, eleven of them border or appearance keys: each names a border or appearance key, `compare()` refuses any key the two
sides do not already agree on, and the mutation is written into a **scratch copy of whichever side
printed that key** - the macOS port side for the border keys, the Catalyst side for the appearance ones
- because a mutation written into `port.txt` would never be read for a key `port.txt` does not hold.

The 73 fixtures the run walks are 3 box, 3 hand-written text, 9 annotation and 3 conforming-writer text
ones from before, plus 55 from `tools/make-object-fixtures.py` - the file this series added, which
writes every xref offset measured from the object bytes as they are written, for the same reason the annotation fixtures measure theirs: a fixture
whose offsets are wrong is a fixture neither side can read, and it would compare as "nothing to say"
rather than as "the same nothing".