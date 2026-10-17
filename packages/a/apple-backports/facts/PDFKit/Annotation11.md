# PDFAnnotation's widget members, and what the rest of the category needs

## What is here

`PDFAnnotation (PDFAnnotationUtilities)` declares 38 members. `annotation11.json` carries **36 rows, 15
implemented and 21 inert** for the batch whose keys are known and whose absent answer is measurable. The
fifteen implemented are the nine **`/Ff` bit reads**, `-buttonWidgetStateString`, `-buttonWidgetState`, and
the **three colours and the font**. (The 38 is the category's total; `PDFAnnotation.destination` landed
with the action family as the 37th, and the 36th of the remainder is `-drawWithBox:inContext:`, which
belongs to the draw family.) Every one is measured on the host over `widget-flags.pdf`, which carries **one
annotation per bit with only that bit set** - thirteen bits, thirteen annotations - plus
`widget-allflags.pdf`, which carries every bit at once. That shape is the whole reason these are
measurable: a fixture with all the bits set answers every member YES and proves nothing.

The fixture table's first version wrote each bit as a **list**, so `str(bits)` produced `"[1]"` and the
dictionaries carried `/Ff [1]` - an array where the format wants an integer - and the host then answered
every flag member NO on every fixture, which read as "the host ignores /Ff". Two more fixture bugs in the
same family, both silent and both looking like a host behaviour:

* `WIDGET_FIELD_TYPES` passed the field type both as the helper's argument and as an extra pair, so every
  dictionary carried `/FT` twice and the host answered three of the four field types rather than four.
* the one-field-type-per-fixture loop named all three `/Ch` fixtures `widget-ftch.pdf`, so each overwrote
  the last and only the first was ever measured.

## The bits, and what the fixtures add to the table

The NAMES below are the format's own, and an earlier version of this page had two of them wrong: it
called bit 16 "RadioInUnison" and bit 26 "RichText" as if each had one name. **Table 8.39's bit 16 is
Radio**, and **bit 26 is RadiosInUnison in the BUTTON field table and RichText in the TEXT field table.**
So two of the three members the earlier version called "not what the table says" ARE the table's rule, and
the claim itself was wrong.

| `/Ff` bit | value | the member that moves | fixture |
| --- | --- | --- | --- |
| 1 ReadOnly | 1 | `readOnly` -> YES | annotation 0 |
| 2 Required | 2 | - no member reads it | annotation 1 |
| 13 Multiline | 4096 | `multiline` -> YES | annotation 2 |
| 14 Password | 8192 | `isPasswordField` -> YES | annotation 3 |
| 15 NoToggleToOff | 16384 | `allowsToggleToOff` -> **NO** | annotation 4 |
| 16 Radio | 32768 | `widgetControlType` -> 1 | annotation 5 |
| 17 Pushbutton | 65536 | `widgetControlType` -> 0, `allowsToggleToOff` -> **NO** | annotation 6 |
| 18 Combo | 131072 | `listChoice` -> **NO** | annotation 7 |
| 19 Edit | 262144 | - | annotation 8 |
| 21 FileSelect | 1048576 | - | annotation 9 |
| 22 MultiSelect | 2097152 | - | annotation 10 |
| 25 Comb | 16777216 | `comb` -> YES | annotation 11 |
| 26 RadiosInUnison (buttons) / RichText (text) | 33554432 | `radiosInUnison` -> YES | annotation 12 |

**Two of the members ARE the table's rule.** `radiosInUnison` reads bit 26, which is RadiosInUnison in
the button table - and the host reads it in a TEXT field too, which is where the same bit is called
RichText (`widget-flags.pdf` is all `/Tx`). `widgetControlType` is the table's mapping of the two bits:
Pushbutton -> 0, Radio -> 1, neither -> CheckBox.

**And what the fixtures add is only two things the tables cannot say:**

* **Both bits at once answer `RadioButton`.** `widget-allflags.pdf` carries bit 16 and bit 17 together and
  answers 1. A two-bit field read as a shift would answer 0, 1, 2 and 3 for the four shapes rather than
  0, 1, 2 and 1, and the **CheckBox default** is what tells the two rules apart.
* **Bit 17 clears `allowsToggleToOff`.** The table says bit 15 NoToggleToOff and says nothing about a
  pushbutton. The bit-15 fixture and the bit-17 fixture each answer NO while the other eleven answer YES.

## `activatableTextField` is not a bit either

It is a **text field that is not read-only**: `/FT` must be `/Tx` *and* bit 1 must be clear. Measured on

* six fixtures with one field type each, alone on its page - `/Tx` YES, `/Btn` NO, `/Sig` NO, a `/Ch`
  with an `/Opt` NO;
* the thirteen `/Tx` fixtures of `widget-flags.pdf`, of which the bit-1 one answers NO and the other
  twelve answer YES;
* every `/Link` in the harness, which has no `/FT` and answers NO.

The first version of this read it as `!readOnly` alone, and the harness found it on the first `/Link` it
met: the port answered YES where the host answers NO.

## A third skip in `-[PDFPage annotations]`, found by the same fixtures

`-[PDFPage annotations]` already skipped an annotation with no `/Rect` and a `/Line` with no `/L`. The
field-type fixtures found a third: **a choice widget is not surfaced at all.**

    widget-ftbtn0.pdf   /FT /Btn                  one annotation, surfaced
    widget-fttx1.pdf    /FT /Tx                   one annotation, surfaced
    widget-ftch2.pdf    /FT /Ch                   NO annotations
    widget-ftsig3.pdf   /FT /Sig                  one annotation, surfaced
    widget-ftch4.pdf    /FT /Ch  /Opt [(one) (two)]   one annotation, surfaced
    widget-ftch5.pdf    /FT /Ch  /Opt (a string)      NO annotations

So the skip is a `/Widget` whose `/FT` is `/Ch` **unless its `/Opt` is an array** - which is the format's
own requirement (Table 8.39 makes `/Opt` required for a choice field) and the host enforcing it, the same
shape as the `/Rect` skip. Six fixtures, one field type each and alone on its page, because a fixture
carrying all four field types can only say that *one* of them is missing.

## `fieldName`: the `/T` IS read, and the coordinator's challenge is what found it

The previous commit registered this row `inert` on the reading that **the host synthesises the name
rather than reading it**, because a widget with no `/T` answered `"text0"`, `"text1"`, `"button0"` and a
widget that DID carry `/T` answered the synthesised name too. That reading was wrong, and it was a
fixture defect of exactly the kind this family keeps producing.

**The fixture's bytes, as asked.** The first version of `widget-values.pdf`'s first annotation carried:

    /Subtype /Widget /Rect [40 40 240 70] /F 4 /FT /Tx /FT /Tx /V (typed) /DV (preset) /MaxLen 7 /Q 2
      /Opt [(one) (two) (three)] /T (the field) /TU (alternate) /DA /Helv 12 Tf 0 g

and the `/T` is a **literal PDF string**, so "written as a name" was never the cause. Two things in that
line are, and they are the third and fourth fixture bugs of this family:

* **`/FT /Tx` twice** - the helper writes the field type and the fixture's extra pairs wrote it again.
* **`/DA /Helv 12 Tf 0 g`** - and this is the one that mattered, though not for the reason the first
  version of this page said. **`/DA` is a TEXT STRING**, so the format spells it
  `/DA (/Helv 12 Tf 0 g)`, and this fixture wrote the content-stream operators **bare into the dictionary**.
  That is a syntax error rather than a reading: `CG_PDF_VERBOSE=1` says **`encountered unexpected symbol
  'Tf'`** and the host then answers **NO ANNOTATIONS AT ALL** for the page - so the widget carrying `/T`
  was not in `-annotations`, and the two that remained named nothing.

  **Written the way the format makes it, a `/DA` is read like any other key.** `widget-t-extra-DAstring`
  carries `/DA (/Helv 12 Tf 0 g)` beside `/T (the field)`, and the host answers **one annotation and the
  field name "the field"**, with nothing on `CG_PDF_VERBOSE`. And `widget-values.pdf` with its `/DA` as a
  string keeps **all three** of its annotations, and its first - the one carrying `/T (the field)` -
  answers **"the field"**.

  So the earlier sentence here, that a `/DA` is not readable in an annotation dictionary at all, was a
  statement about the fixture and not about the host, and it is withdrawn. The reading the `/DA` rows need
  - `font`, `fontColor` and the `/DA` colour - is measured against this spelling.

With the `/DA` gone, six fixtures fix the rule:

| fixture | what it carries | the host answers |
| --- | --- | --- |
| `widget-t-literal` | `/T (the field)` on the widget | `the field` |
| `widget-t-empty` | `/T ()` | the **empty string** |
| `widget-t-name` | `/T /TheField`, a PDF **name** | not read - it synthesises |
| `widget-t-merged` | the widget's `/Parent` is a field with `/T (parent field)` | `parent field` |
| `widget-t-mergedname` | both, and the widget has `/T (child too)` too | `parent field.child too` |
| `widget-t-extra-*` | `/T (the field)` plus one of `DA`, `TU`, `Opt`, `Q`, `MaxLen`, `V`, `DV`, `F` | `the field` in all nine |

So the `/T` of the merged field and widget is read, **the parent's first and the widget's own appended
with a dot**, both as PDF strings only. The port implements that reading and the harness compares it
over the twelve fixtures that name their widgets.

**And the answer for a widget that names NOTHING is still not implementable** - which is why the row is
inert rather than implemented, and why the reason on it is rewritten rather than removed. The synthesised
name's number is a **process-global counter**. Five fixtures opened in order in one process:

    three widgets alone          text0, text1, text2
    a link then two widgets       text3, text4
    a widget, a link, a widget    text5, text6
    one widget alone              text7
    five annotations, two widgets text8, text9

so the counter does not restart per document and is not a property of any file. The earlier reason said
"by document position", and `widget-mixed.pdf` is the fixture that shows that is wrong: its two widgets
are the **third and fifth** of five annotations and answered `text7` and `text8` in that run, because four
files had been opened before them.

**The harness therefore prints a `fieldName` key only over the fixtures that name their widgets**, and the
list is spelled out in `host.m` rather than being a prefix test. A prefix test swept in
`widget-t-name.pdf`, whose `/T` is a NAME and so names nothing, and the differential caught it - the same
way it catches everything else here.

## The /AS matrix: BOTH members are implemented, and the hypothesis needed one more clause

`-buttonWidgetStateString` is the NAME of the widget's on-state and `-buttonWidgetState` is whether it is
ON. Both are implemented, and the second took the coordinator's hypothesis plus a clause.

**The string is the /AP /N on-state name.** Eighteen fixtures that carry no `/AP` answer `"Yes"` - every
`/Btn` and every `/Tx` shape in the widget fixtures, whatever `/AS` and `/V` say - so `"Yes"` is the
DEFAULT and not the answer. `button-ap-states.pdf` has five annotations whose `/AP` `/N` is keyed on
`/On`, `/Yes` and `/Marked`, and it answers those names:

| `/AS` | `/AP /N` keys | the string |
| --- | --- | --- |
| `/Off` | `/On`, `/Off` | `On` |
| `/On` | `/On`, `/Off` | `On` |
| `/Yes` | `/Yes`, `/Off` | `Yes` |
| `/Yes` | `/Marked`, `/Off` | **`Marked`** |
| `/Marked` | `/Marked`, `/Off` | **`Marked`** |

The last two are what make it a rule and not an echo of `/AS`: an `/N` keyed `/Marked` answers `"Marked"`
beside an `/AS` `/Yes` AND beside an `/AS` `/Marked`. The `/N` keys are walked with
`CGPDFDictionaryApplyFunction` and **not** with `CGPDFDictionaryApplyBlock`, which is
`CG_AVAILABLE_STARTING(10.14, 12.0)` and in neither band of this port - the first version of this used the
block form and would not have linked on 6.1.3.

**The state is 1 when `/AS` or `/V` names that on-state, or when BOTH name a state that is not `/Off`; and
-1 for a widget that is not a BUTTON.** Tested as a table of all 31 shapes before any code:

    1  /AS names the on-state, OR /V names it.
         /AS /Yes with no /V is 1        (button-as-alone)
         /V /Yes with no /AS is ALSO 1    (button-v-only)  <- so neither key may be the only one

    2  BOTH name a state that is not /Off.
         /AS /On with /V /On is 1         (button-as-and-v)
         /AS /On with /V /Yes is 1        (button-asoff-von)
         /AS /On with /V /Off is 0        (button-asoff-von)  <- a /V of /Off does not count

    3  the widget must be a BUTTON, and the /FT must be ON THE WIDGET.
         every /Tx answers -1 whatever it carries           (text-as, four states)
         all six button-merged-* answer -1                  (the /Btn FIELD carries the /FT and the
                                                            widget reaches it through /Parent)

**The coordinator's hypothesis is right in two clauses and short by one, and two fixtures say where.** The
hypothesis - "1 when `/AS` names the on-state, or when `/V` names the same state `/AS` names and that
state is not `/Off`" - is refuted by

* **`button-v-only.pdf`'s fourth annotation**, `/V /Yes` with no `/AS`: measured **1**, and the hypothesis
  says 0 because `/AS` names nothing. Clause 1's second half is the fix.
* **`button-asoff-von.pdf`'s fourth annotation**, `/AS /On` with `/V /Yes`: measured **1**, and the two do
  not name the same state. Clause 2 is the fix, and it is what that fixture is for.

So the implemented rule is the hypothesis with "`/V` names **the** on-state" and "`/AS` and `/V` each name a
state that is not `/Off`" - and both additions are measurements, not repairs.

**One thing this cost, and the differential caught all three at once.** Names carry **no leading slash**:
`CGPDFDictionaryGetName` strips it and `CGPDFDictionaryApplyFunction`'s key has none either, which is why
the string member answers `Yes` and `Marked` and not `/Yes`. The first version of the `/Off` test compared
against `@"/Off"`, never matched, and answered 1 for the three shapes where one of the two keys is `/Off`.


## The colours and the font: read by `/NM`, and TWO of the earlier readings are withdrawn

The section this replaces was a table read by **index**, and it was wrong from the seventh row on. It is
replaced here by a table read by the annotation's own **`/NM`**, and the two rows that were wrong for a
reason nobody had measured are named and withdrawn. Everything below is keyed by a name the fixture writes
into each annotation, so a reading belongs to an annotation rather than to a position.

### The dropped annotation: it is the `/Ch` one, and the skip that drops it was already in the port

`annotation-colours.pdf` writes **48** annotations and the host surfaces **47**. The missing name is
**`bg-ch-noopt`** - the `/Widget` whose `/FT` is `/Ch` and which carries **no `/Opt`**. That is
`-[PDFPage annotations]`'s **choice-widget skip**, which PDFAnnotation11.md records from the field-type
fixtures: Table 8.39 makes `/Opt` required for a choice field, and the host enforces it.

So the drop was not a mystery and it was not about colours: it is a rule the port already implements, and
the port surfaces the same 47 names. That is asserted on both sides on every run by one key,
**`<fixture>.colours.names`**, which prints the `/NM` values in the order `-annotations` returns them. It is
one of the run's named red controls, so a skip list that stopped matching would go red on it and not only
on a count.

**Two readings of the old table are withdrawn, and both were the same mistake.**

1. **"`/Ch` with `[0 0 1]` answers `0.1353, 1.0000, 0.0249` - a GREEN THE ARRAY DOES NOT CONTAIN."** It does
   not: that annotation is not surfaced at all. The green belongs to **`bg-bc-beside`**, the next one, whose
   `/MK` carries `/BC [1 0 0] /BG [0 1 0]` - which is what the very next row of the old table said, so the
   table contradicted itself one row apart.
2. **"the host makes a DeviceRGB colour, so `[1 0 0]` answers `0.9860, 0.0000, 0.0269`".** No conversion
   happens. Measured through `-[NSColor CGColor]`, the host's colour for `[1 0 0]` is
   **`kCGColorSpaceDeviceRGB` carrying components `1.000000, 0.000000, 0.000000, 1.000000`** - the array's own
   numbers. The old figures were the sRGB *rendition* of that DeviceRGB colour, produced by the probe
   converting before printing, and they were a reading of the probe. The same goes for `[0 0 0 0]`, which
   the old table called **white**: it is **`kCGColorSpaceDeviceCMYK` carrying `0, 0, 0, 0, 1`**, not a
   colour converted to anything.

This is why a colour is printed as a **space name and its components in that space**, on both sides, rather
than as four RGBA numbers: a gray answers two components, a CMYK five, and `-[NSColor
getRed:green:blue:alpha:]` is **void** on macOS and raises on a space with no RGB. Both sides read the two
facts off CoreGraphics, which is the one thing they share.

### `-backgroundColor` reads `/MK` `/BG` - in the DEVICE space its component count names

`/BC` is the **border** colour of Table 8.40 and is the key `-[PDFAnnotation border]` reads;
`bg-bc-beside` carries both and answers the `/BG`. `PDFAnnotationUtilities.h:280` names the member
"Background color characteristics. Used by annotations type(s): /Widget".

| `/NM` | `/MK /BG` | the host answers |
| --- | --- | --- |
| `bg-rgb` | `[1 0 0]` | `kCGColorSpaceDeviceRGB`, `1, 0, 0, 1` |
| `bg-gray` | `[0.5]` | `kCGColorSpaceDeviceGray`, `0.5, 1` |
| `bg-cmyk-none` | `[0 0 0 0]` | `kCGColorSpaceDeviceCMYK`, `0, 0, 0, 0, 1` |
| `bg-cmyk` | `[0.1 0.2 0.3 0.4]` | `kCGColorSpaceDeviceCMYK`, `0.1, 0.2, 0.3, 0.4, 1` |
| `bg-notarray` | `(a string)` | **nil** - the wrong type is refused |
| `bg-btn` | `[0 0 1]`, `/FT /Btn` | `kCGColorSpaceDeviceRGB`, `0, 0, 1, 1` |
| **`bg-ch-noopt`** | `[0 0 1]`, `/FT /Ch`, no `/Opt` | **not surfaced at all** - see above |
| `bg-bc-beside` | `/BC [1 0 0] /BG [0 1 0]` | `kCGColorSpaceDeviceRGB`, `0, 1, 0, 1` - the `/BG` |

**One is DeviceGray, three is DeviceRGB, four is DeviceCMYK, the components are the array's own, and the
alpha is 1.** Nothing converts, and the three `CGColorSpaceCreateDevice*` spaces are iOS 2.0 - which is why
the member is implemented (`PDFAnnotationColours11.m`) rather than deferred.

### `-interiorColor` reads the annotation's OWN `/IC`, on more subtypes than the header names

`/IC` is not an `/MK` key. `PDFAnnotationUtilities.h:131` names "/Circle, /Line, /Square"; the host answers
it on **every** subtype measured, `/Link` and a `/Tx` `/Widget` included.

| `/NM` | `/IC` | the host answers |
| --- | --- | --- |
| `ic-square-rgb` | `[0 1 0]` | `kCGColorSpaceDeviceRGB`, `0, 1, 0, 1` |
| `ic-square-gray` | `[0.25]` | `kCGColorSpaceDeviceGray`, `0.25, 1` |
| `ic-square-none` | absent | **nil** |
| `ic-circle-cmyk` | `[0.1 0.2 0.3 0.4]` | `kCGColorSpaceDeviceCMYK`, four components and alpha 1 |
| `ic-link` | `[1 0 0]` | `kCGColorSpaceDeviceRGB`, `1, 0, 0, 1` |
| `ic-widget` | `[1 0 0]`, `/FT /Tx` | `kCGColorSpaceDeviceRGB`, `1, 0, 0, 1` |

### `-fontColor`: the `/DA`'s FIRST fill operand, in the GENERIC spaces - and the member is NOT carried

Measured, keyed by name:

| `/NM` | `/DA` | the host answers |
| --- | --- | --- |
| *(every `/NM` with no `/DA`)* | absent | `kCGColorSpaceGenericGrayGamma2_2`, `0, 1` |
| `da-fill-gray-0` | `(/Helv 12 Tf 0 g)` | `kCGColorSpaceGenericGray`, `0, 1` |
| `da-fill-gray-1` | `(/Helv 12 Tf 1 g)` | `kCGColorSpaceGenericGray`, `1, 1` |
| `da-fill-rgb` | `(/Helv 12 Tf 1 0 0 rg)` | `kCGColorSpaceGenericRGB`, `1, 0, 0, 1` |
| `da-fill-cmyk-red` | `(/Helv 12 Tf 0 1 1 0 k)` | `kCGColorSpaceGenericGray`, `0, 1` |
| `da-fill-cmyk-cyan` | `(/Helv 12 Tf 1 0 0 0 k)` | `kCGColorSpaceGenericGray`, `0, 1` |
| `da-stroke-rg` / `-k` / `-g` | `0 1 0 RG` / `K` / `G` | `kCGColorSpaceGenericGray`, `0, 1` |
| `da-nooperand` | `(/Helv 12 Tf)` | `kCGColorSpaceGenericGray`, `0, 1` |
| `da-fill-gray-then-rgb` | `(/Helv 12 Tf 0.5 g 1 0 0 rg)` | `kCGColorSpaceGenericGray`, **`0.5, 1`** |
| `da-fill-rgb-then-gray` | `(/Helv 12 Tf 1 0 0 rg 0.5 g)` | `kCGColorSpaceGenericRGB`, **`1, 0, 0, 1`** |
| `da-fill-gray-twice` | `(/Helv 12 Tf 1 g 0.25 g)` | `kCGColorSpaceGenericGray`, **`1, 1`** |
| `da-fill-badcount` | `(/Helv 12 Tf 0.5 0.25 g)` | `kCGColorSpaceGenericGray`, **`0.25, 1`** |

Five things are now settled, and three of them the old table listed as open:

* **`k` is not read.** Both CMYK values, whose conversions are red and cyan, answer the gray default - and
  so do all three **stroke** operands, which is the format's own rule rather than a gap: text is painted
  with the fill colour.
* **The operand's POSITION does not decide; being FIRST does.** `0.5 g 1 0 0 rg` answers the gray and
  `1 0 0 rg 0.5 g` answers the RGB, so this is a defaults read and not a replay of a content stream.
* **A colour operator with the wrong operand count is not refused; it reads the numbers in FRONT of it.**
  `0.5 0.25 g` answers 0.25.
* **No `/DA` and a `/DA` with no fill operand are TWO DIFFERENT DEFAULTS**: `kCGColorSpaceGenericGrayGamma2_2`
  against `kCGColorSpaceGenericGray`.

**The three colour-space NAMES this needs are marked `API_AVAILABLE(ios(9.0))` in this SDK, and the port's
`minimum` is 6.0 - and the annotation is not the export.** Measured, and the row's minimum stands:

    $ xmake l tools/cache-index/first-rung.lua _kCGColorSpaceGenericGray
    _kCGColorSpaceGenericGray	3.0
    _kCGColorSpaceGenericGray	3.0        (the three: GenericGray, GenericRGB, GenericCMYK)
    _kCGColorSpaceGenericRGB	3.0
    _kCGColorSpaceGenericCMYK	3.0
    _kCGColorSpaceGenericGrayGamma2_2	4.0
    _CGColorSpaceCreateWithName	3.0

and confirmed in the two releases that matter, out of their own armv7 caches' **CoreGraphics export tries**
through the repository's own reader, `tools/corpus/cache-value.lua`, walking each cache's CoreGraphics image export
trie - not through a header and not through a scan of the cache's bytes:

    4.3    armv7  CoreGraphics: 8 of 8 names exported
    6.1.3  armv7  CoreGraphics: 8 of 8 names exported

(the eight being the three Generic names, `GenericGrayGamma2_2`, `GenericCMYK`, `CGColorSpaceCreateWithName`
and the three `CGColorSpaceCreateDevice*`). **`GenericGrayGamma2_2` measures 4.0 and not 3.0**, and it is
the default for an annotation with no `/DA` at all, so it is the one that had to be checked. There is no
availability test and no fallback: the deployment target makes the imports weak and the gate checks that
they resolve, which is the mechanism this repository already uses for every weak import.

An earlier version of this page said the member could not be carried because of that annotation. It was
wrong, and the mistake was reading a header's `API_AVAILABLE` as an export table - which is the one thing
`tools/cache-index/first-rung.lua` exists to stop.

### `-font`: the name as written, then an EXACT table of THREE abbreviations

| `/NM` | `/DA` name | the host answers |
| --- | --- | --- |
| `font-courier-7` | `/Courier` | **Courier** at 7 - the PostScript name, used as written |
| `font-size-only` | *(none)* | Helvetica at **12** |
| `font-name-only` | `/Helv`, no size | Helvetica at **12** |
| `font-unknown` | `/Nonexistent` | **Helvetica at 9** - the SIZE IS KEPT |
| `font-abbrev-helv` | `/Helv` | Helvetica at 21 |
| `font-abbrev-hebo` | `/HeBo` | **Helvetica-Bold** at 11 |
| `font-abbrev-cour` | `/Cour` | **Courier** at 14 |
| `font-full-oblique` | `/Helvetica-Oblique` | **Helvetica-Oblique** at 25 |
| `font-full-roman` | `/Times-Roman` | **Times-Roman** at 26 |
| `font-abbrev-heob`, `-hebo-bi` | `/HeOb`, `/HeBO` | **Helvetica** |
| `font-abbrev-cobo`, `-coob`, `-cbo-bi` | `/CoBo`, `/CoOb`, `/CBO` | **Helvetica** |
| `font-abbrev-tiro`, `-tibo`, `-tiit`, `-tibi` | `/TiRo`, `/TiBo`, `/TiIt`, `/TiBI` | **Helvetica** |
| `font-abbrev-symb`, `-zadb` | `/Symb`, `/ZaDb` | **Helvetica** |
| `font-prefix-h`, `-co`, `-ti` | `/H`, `/Co`, `/Ti` | **Helvetica** - not a prefix match |
| `font-case-upper`, `-mixed` | `/HELV`, `/Hebo` | **Helvetica** - not case-insensitive |

**All fourteen abbreviations of the standard fourteen are measured, and exactly THREE of them resolve**:
`Helv` to Helvetica, `HeBo` to Helvetica-Bold and `Cour` to Courier. The other eleven answer Helvetica with
the size kept. That is the whole of the map, and it is a fact about PDFKit rather than about the format:
PDF 1.7 9.6.2.2's fourteen would have `/TiRo` as Times-Roman, and it does not.

**The platform's own font lookup is not what does this.** `-[NSFont fontWithName:size:]` is **nil for every
one of the fourteen**, and answers the full PostScript names, which is clause one. Measured on this Mac with
a fifteen-line probe over the fourteen abbreviations and the fourteen PostScript names: nil for all fourteen
abbreviations, and the name itself for each of `Helvetica`, `Helvetica-Bold`, `Helvetica-Oblique`,
`Helvetica-BoldOblique`, `Courier`, `Courier-Bold`, `Courier-Oblique`, `Courier-BoldOblique`, `Times-Roman`,
`Times-Bold`, `Times-Italic`, `Times-BoldItalic` and `Symbol`. The one full name that answers **nil** is
`ZapfDingbats`, which is worth knowing and is not load-bearing here: no fixture of this family names it, and
`ZaDb` reaches clause three whatever the platform does with it.

**The probe is not committed and its path is not the citation** - it was scratch under this worktree's
`.agent-work/`, which a worktree sweep removes, so the measurement is written out here in full instead. A
fact that can only be checked by a file the reader does not have is not a fact they can check.

The table is **exact and case-sensitive**, pinned by the three prefix names and the two wrong-case ones.

So `-font` is three clauses and 24 named fixtures: the name **as written** when the platform has a font of
that name; else the exact table of three; else **Helvetica**, with the size read independently of the name
and defaulting to **12**. It is implemented in `PDFAnnotationColours11.m`, which needs only `UIFont`
(iOS 2.0) and `-[UIFont fontWithName:size:]` (iOS 2.0).

### The wall was in the harness, and it is answered with a SEAM and not with a skip list

The first version of this family ended with a skip list: 329 keys printed as `not compared`, with a reason on
the line. That was the wrong shape, and this is why.

**The cause is real and it is not the port.** The harness has three binaries: the host's, the port's on
macOS, and - because a macOS process has no `UIColor` - the port's again under **Mac Catalyst**. The
Catalyst binary **links no PDFKit** (`otool -L` lists UIKit, Foundation, CoreGraphics and nothing else) and
still loads `/System/iOSSupport/System/Library/Frameworks/PDFKit.framework` at run time: `color.txt`
carries **14** `Class PDFDocument is implemented in both ...` lines. A **category** on a class is *replaced*
when the image holding it loads later, and the platform declares these same selectors on its own
`PDFAnnotationUtilities` category - so the port's four members are shadowed there and anything printed
through those selectors is the platform's.

That it is the **category** and not a broken port is measured, not argued: a `-777` sentinel planted in
`PDFAppearanceCharacteristics`' own `-init` answered `appearance.fresh.controlType=-777` in that same
binary, so the **class's own** members there do run - which is also why that block's keys are the port's.

**The answer is a seam.** The derivation of all four members now lives in
**`CharonPDFKitColours.h`** as `static inline` functions over the annotation's `CGPDFDictionary`, which is
`CharonLists.h`'s shape and for `CharonLists.h`'s reason: a C symbol in a `.m` is a symbol a host
differential that compiles the port's objects with its own sources cannot link. `PDFAnnotationColours11.m`
is four one-line members over that seam, and the harness's Catalyst side calls the seam **directly**, on
the same `CGPDFDictionary` the port read:

    CGPDFDictionaryRef dictionary = [annotation charon_CGPDFDictionary];
    printAnnotationColour(label, "backgroundColor", charon_annotation_background_colour(dictionary));
    ...

**No selector is dispatched anywhere in that path**, so nothing a later image loads can take it over, and
both sides wrap the returned `CGColorRef` in their OWN platform's colour class - which is the whole of the
platform difference `color.m`'s header already describes. The keys went back into the comparison and the
skip list is gone: `not compared` is back to the **173** it was before this family, and the four rows are
`implemented` on **179 named red controls**, fourteen of which name a colour or font key and one of which
names the `/NM` list itself.

The three cannot be moved into the class's own `@implementation`, and that is worth recording because it
looks like the obvious alternative: `PDFPage`'s and `PDFAnnotation`'s ivars are declared in
`PDFAnnotation11.m`, a class has one `@implementation`, so a second object can only add a **category** -
and it needs UIKit, which the macOS port side has not got. The seam sidesteps the dispatch entirely rather
than fighting for the class.

### Two traps in CoreGraphics that each cost this family a whole run

Both are in `CharonPDFKitColours.h` and both are about reading a PDF colour array:

1. **`CGPDFArrayGetObject` is ZERO-BASED.** Its index runs `0 .. count-1`, the way `PDFKit11.m`,
   `PDFPage11.m` and `PDFAction11.m` already read arrays in this library - so reading component `i` as
   `i + 1` walks off the end **on the last component and no other**. That is the worst shape a bug can
   have: `[1 0 0]` reads two components and then refuses, and a one-component `[0.25]` refuses outright.
   It is how `backgroundColor` and `interiorColor` answered nil for every fixture while the host answered
   all of them.
2. **`CGColorCreate` reads the space's component count PLUS ONE**, and that last value is the **alpha**. A
   PDF colour array has no alpha component - Table 8.40's shapes are gray, RGB and CMYK - so the array's
   components go in and a **1** goes after them. Zero-initialising the tail instead answers every
   background and interior colour with the right hue and a **zero alpha**: an invisible colour, which is not
   the host's answer to any of them and which the differential caught as eleven differences on one run.

A third, quieter one, and it is the reason the array components are read by their object **type** rather
than through `CGPDFArrayGetNumber`: **`CGPDFArrayGetNumber` does not fail on an integer, it answers ZERO.**
It returns `true` for an integer component whose value is 1 or 0 and writes 0 either way, so `[1 0 0]` read
through it is a *black* colour rather than a refusal - worse than the refusal, because it looks like an
answer. CoreGraphics types a bare `1` as `kCGPDFObjectTypeInteger` and a bare `0.5` as
`kCGPDFObjectTypeReal`, so the object's own type is what says which reader to use.

### The rows

All four are **`implemented`**, and none of them is a constant or a stand-in:

* **`backgroundColor`, `interiorColor`, `fontColor`, `font`** - four members in
  `PDFAnnotationColours11.m`, one line each, over five `static inline` seams in `CharonPDFKitColours.h`
  that decide the key, the colour space, the components, the alpha and the font name and size. Compared
  against Apple's own members over 48 named fixtures through the seam, with 179 named red controls, of which
  fourteen name a colour or font key: `nmbg-rgb.backgroundColor.space` and `.components` (the DeviceRGB
  space and the array's own values), `nmbg-cmyk.backgroundColor.space` (four components choose CMYK),
  `nmbg-notarray.backgroundColor` (the wrong type is nil), `nmic-square-gray.interiorColor.space` and
  `nmic-circle-cmyk.interiorColor.components`, `nmda-fill-rgb.fontColor.space` and `.components` (generic,
  not device), `nmda-fill-badcount.fontColor.components` (the operand-count rule), `nmda-stroke-k.fontColor
  .space` (k is not read), `nmfont-courier-7.font.name` and `.size`, `nmfont-abbrev-hebo.font.name` (the
  HeBo rule) and `nmfont-unknown.font.size` (the size is kept).

## The 21 rows that are not implemented, and why each one waits

Each carries the host's measured answer in its `reason` in `registry/PDFKit/annotation11.json`. Grouped:

* **`buttonWidgetState`**, above - the /AS matrix is measured and one combination does not derive.
* **`buttonWidgetState`** is NOT in this list any more: the hypothesis and one more clause now predict all
  31 shapes, and it is implemented above.
* **the `/V` and `/DV` pair.** `widget-values.pdf`'s first annotation carries `/V (typed)` and `/DV
  (preset)`; the host answers **nil** for the string value and an **empty string** for the default. One
  fixture, two different shapes, neither of them a reading of the key - so these wait for a measurement
  that says what the host reads instead.
* **`buttonWidgetState` and its string.** So far: `/AS /Yes` on a `/Btn` answers 1, `/AS /Off` answers 0,
  `/AS /On` answers **0**, and a `/Tx` widget with `/AS /Yes` answers -1. The mapping is not the format's
  off/on pair, and it needs a fixture per (`/FT`, `/AS`) combination before it is a rule.
* **the keys whose effect is not established** - `maximumLength` (`/MaxLen 7` -> 0), `alignment`
  (`/Q 2` -> 0), `choices` and `values` (`/Opt [(one) (two) (three)]` -> empty), `open`, `caption`, `URL`.
  Each is written in a fixture and the host does not answer it from there, which says the key or the scale
  is something else and not what I assumed.
* **the three colours and the font** are NOT in this list any more: they are implemented, measured and
  compared through the seam, and the section above carries the table, the export measurement and the two
  CoreGraphics traps that each cost a run.
* **the geometry six** - `startPoint`, `endPoint`, `startLineStyle`, `endLineStyle`, `paths`,
  `quadrilateralPoints`. `/InkList` is a list of variable-length point runs and needs a bezier-path object
  the port does not carry; `PDFLineStyle` is a class the port does not carry; `/QuadPoints` is a flat array
  of eight numbers and no fixture writes one.
* **the two write paths**, `addBezierPath:` and `removeBezierPath:`, which need `-paths` first and then
  write to the document.
* **`iconType`, `markupType`, `stampName`**, whose keys are name strings no fixture writes.

## The run

    $ sh tests/backports/host/pdfkit-document/run.sh
      images differ by construction: host=/System/.../PDFKit.framework/.../PDFKit
                                      port=.../runs/pdfkit-document/port-side
      COMPARED 14725 MISMATCHES 0  (not compared: 173, expected to differ: 519, of which 411 compared from the Catalyst side)
      RED CONTROL ok: the comparison goes red on a mutated port, and names the key

178 fixtures. **179 named red controls, 179 of them with a `DIFFER` line in their own log**, among them one
per member over `widget-flags.pdf`'s first annotation, the three fixtures that pin
`widgetControlType`'s priority (`noflags`, bit 16, bit 17, `allflags`), the two that pin the inversions
(bit 15 and bit 18), the one that pins `radiosInUnison` off bit 26, the field-type fixtures that pin
`activatableTextField`, the three annotation **counts** that pin the choice-widget skip -
`widget-fttx1` (1), `widget-ftch2` (0) and `widget-ftch4` (1) - `annotation-colours.pdf.colours.names`,
which is the one control that names **the /NM list itself** and so pins the dropped annotation rather than a
count of it, and **fourteen that name a colour or font key**, one per rule of this family.

**The 173 `not compared` lines are all pre-existing** and none of them is this family's: an earlier version
of this page had 519, of which 346 were the four colour and font members that the seam now brings back into
the comparison.

The harness prints the nine members one key per line, for the reason the outline facts were lost the first
time round: a line carrying several `key=value` pairs registers as one key and drops the rest. The colour
and font keys go under `.colours.` and **not** `.page0.` for the same reason and one more: `compare()`
reads any `.page0.` key of four numbers as a **rectangle** and gives it a 0.001 tolerance, which is right
for a rectangle and would hide the third-decimal difference this family is about.

## hasAppearanceStream, open and URL: read from the annotation's own dictionary

These three were `inert` on the reading that no fixture wrote the key. The annotation fixtures are now written
byte by byte (`tests/backports/host/pdfkit-annotations/make-annotations.m`, since CGPDFContext cannot put an
annotation on a page), so each key can be set and measured on the host.

- **`hasAppearanceStream`** is YES when `/AP` carries an `/N` **stream**. `/AP` with only a `/D` (down)
  appearance answers NO, and so does an annotation with no `/AP`. The `/N` of a plain annotation is a stream
  reference, so it is read with `CGPDFDictionaryGetStream`; the button-state reader uses the dictionary form
  because a button's `/N` is a dictionary of states.
- **`open`** is the `/Open` flag. It answers YES for `/Open true` on every subtype measured (Text, Square, Link)
  and NO for `/Open false` or no key. It has no subtype-dependent default.
- **`URL`** is the `/URI` of a URI action, as an NSURL. A `/Link` with `/A << /S /URI >>` answers the URL, with or
  without `/H`. A `/Link` whose only target is a bare `/Dest` (a GoTo) answers nil, as does one with no `/A`. It is
  read through the port's own `-action`, so it is the same `PDFActionURL` the action row measures.

`highlighted` stays inert: it answers NO on all nine original fixtures and also on a `/Link` with `/H /I` and one
with `/H /N`, and on a `/Highlight`. `/H` is therefore not what answers it, and no measured key does. Left
`inert` with that reason rather than answered with a constant.

The harness (`tests/backports/host/pdfkit-annotations/run.sh`) compares 120 facts over eighteen fixtures, the same
probe source built against the host's PDFKit and against the port, with a planted control in which `/Open` is read
under a key nothing writes; the control goes red.

`URL` also answers the file of a `/Launch` action, because the host's `-action` for one is a `PDFActionURL` (see
`facts/PDFKit/Action11.md`): `annot-launch.pdf` answers `file://…/other.pdf`, and `annot-launch-win.pdf` (a `/Win`
with no top-level `/F`) answers nil. A remote GoTo (`annot-gotor.pdf`) answers nil, as the host does.
