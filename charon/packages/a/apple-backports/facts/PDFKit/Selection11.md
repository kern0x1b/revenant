# PDFSelection: the text a search answers, and the ranges it answers it in

Every number on this page was measured on this Mac's own PDFKit, through `tools/host-find.m`, over
fixtures that `make-text-fixture.m` writes with the release's own `CGPDFContext` - a conforming writer,
so the content streams carry a correct `/Length`. The run output the numbers come from is
`.agent-work/runs/v-pdfsel/host-find-final.txt` in the branch that measured them, and the predictions
that were written BEFORE each round of it asked the host are in
`.agent-work/runs/v-pdfsel/find-predictions.md`, in the same directory.

## The rule `-findString:withOptions:` answers, and how it was pinned

The starting point was eight observations that no rule over the characters explains: `shared` took no
trailing space while `third` did, and both are followed by one space and then a letter in the same
fixture. So a family of fixtures was built first - `cgfixture-words`, `cgfixture-gap`,
`cgfixture-lines2`, `cgfixture-tail`, `cgfixture-cross`, and later `cgfixture-blank`,
`cgfixture-inline`, `cgfixture-lead`, `cgfixture-tailpair`, `cgfixture-tab` - and every one of the 136
rows was predicted before it was asked. The rule that came out of them:

> **`findString:withOptions:` answers one selection per occurrence, and each selection's range is the
> matched substring in the page's own `-string` coordinates - extended by ONE character when the
> character after the match is a line break.**

Every part of that is measured:

| what | measured | where |
| --- | --- | --- |
| no snapping backward | `pha` in `alpha` is `{7,3}` and not `{5,5}` | cgfixture-words |
| no snapping forward | `al` is `{5,2}`, `alph` `{5,4}`, `bra` `{11,3}`, `charli` `{17,6}`, `ze` `{0,2}` | cgfixture-words |
| no extension over a space | `zero` `{0,4}`, `bravo` `{11,5}`, `charlie` `{17,7}`, `shared` `{0,6}` and `{11,6}`, `third` `{22,5}` | cgfixture-words, cgfixture-lines |
| ONE extension, over a line break | `two` `{4,4}`, `four` `{14,5}`, `one` `{7,4}`, `shared one` `{0,11}`, `alpha` `{0,6}` on the blank fixture, `bravo` `{6,6}` on the tab fixture | cgfixture-lines2, cgfixture-lines, cgfixture-blank, cgfixture-tab |
| and nothing else is taken | `alpha` `{0,5}` where the character after it is a NUL, not a break | cgfixture-inline, cgfixture-tab |
| one occurrence per match, in order | three `alpha` -> three selections at `{5,5}`, `{25,5}`, `{31,5}` | cgfixture-words |
| the same answer wherever the same word is | the three `alpha` ranges are three different offsets and one shape: the extension is a function of the match, not of where it sits | cgfixture-words |
| not found is an EMPTY array | `nothing here`, `o t`, `a  b`, `al.ha` -> `count=0` | several |
| a needle never spans a page | `bravo charlie` over two pages -> `count=0` | cgfixture-cross |
| a case-insensitive match answers the DOCUMENT's spelling | `ALPHA` with `NSCaseInsensitiveSearch` -> three selections, each `string` = `alpha` | cgfixture-words |
| `.` is literal either way | `al.ha` finds nothing with options 0 and nothing with `NSLiteralSearch` | cgfixture-words |
| `NSBackwardsSearch` reverses the array, not the ranges | `alpha` -> `{31,5}`, `{25,5}`, `{5,5}` | cgfixture-words |

`findString:fromSelection:withOptions:` carries on from a selection and starts at the document's
beginning when the selection is nil, which is `PDFDocument.h:277` in prose:

| call | answers |
| --- | --- |
| `alpha` from nil, fresh document | `{5,5}`, the first match |
| `page` from nil on the three-page fixture | `{0,4}`, page 0's match |
| `alpha` from nil, `NSBackwardsSearch` | `{31,5}`, the last match |
| from the match at `{5,5}` | `{25,5}`; from `{25,5}` -> `{31,5}`; from `{31,5}` -> nil |
| backwards, on the three-page fixture | page 2's match -> page 1's -> page 0's, so a search crosses PAGES even though a needle does not |
| a search before it | changes nothing: `findString:` then `from=nil` answers the first match again |

There is **no state left behind by a search**. An earlier draft of this page claimed a find cursor,
because the probe's own label printed `match#0` for both "the first match" and "no selection" and the two
were read as one; the label is now a named constant and the claim is retracted.

## What the page's own text is, which the ranges are offsets into

The ranges above are offsets into the page's `-string`, so the walk that produces it is part of this
family. Two things the host does that a walk which joins runs verbatim does not:

- **each LINE is trimmed and its interior whitespace is collapsed.** `alpha  bravo` (two drawn spaces)
  reads `alpha bravo`; `" alpha bravo "` reads `alpha bravo`; `"alpha "` on one line and `bravo` on the
  next reads `alpha\nbravo`, so the trailing space is gone; and `"alpha "` followed by `"beta"` at the
  SAME y reads `alpha beta`, so the trim is of the LINE and not of each run.
- **a control byte is a NUL, not whitespace.** `CGContextShowTextAtPoint` writes a newline or a tab in a
  show string as `(\000)`, and the character reaches the text as a NUL: cgfixture-inline's `-string` has
  length 11 and prints as its first five characters, and the search does not extend over it.

And the seams that were already there, still true: runs at the same y join with nothing, runs at
different y join with one newline and come out sorted by y descending with a tie in drawing order, and a
show that draws nothing is not written at all - cgfixture-blank's three drawn lines produce two
operators and a `-string` of 11 characters, not 12.

## The other members this family needs

| member | the host answers | what it takes |
| --- | --- | --- |
| `pages` | `[the page]`, and for a page the selection does not cover the selection has **no** text range on it | the page a match was found on |
| `rangeAtIndex:onPage:` | the match's own range, per page | the walk's characters |
| `numberOfTextRangesOnPage:` | 1 for a match inside one line, 0 for a page the selection does not cover | the same |
| `boundsForPage:` | `20.0000,357.2400,36.7080,12.0000` for `page 1`; `+inf,+inf,0,0` for a page the selection does not cover | per-character ADVANCES: 36.7080 is six Helvetica glyphs at 12pt and the y is the font's ascent below the baseline, not the 360 the text was drawn at |
| `selectionsByLine` | one selection per line the match covers; each line's `string` is the line's text WITHOUT the break that ends it, while the line's RANGE carries that break | the walk's lines |
| `attributedString` | the selection's own string with a font attribute over the whole of it: `Helvetica` at 12pt | the name `Tf` names and the size beside it |
| `color` | nil for every selection a find returns | nothing; the header's own default drawing colours are the host's |
| `initWithDocument:` | a fresh object: nil string, 0 pages, nil color | nothing |
| `copy` | a NEW object with the same string | `NSCopying` over the ranges |

## The write and draw methods

`addSelection:`, `addSelections:`, `extendSelectionAtEnd:`, `extendSelectionAtStart:` and
`extendSelectionForLineBoundaries` mutate a selection the caller holds, and `drawForPage:active:` and
`drawForPage:withBox:active:` draw into a context. A selection built by a find is exactly the object
those five mutators are documented for (`PDFSelection.h:66-79`: "Add the selection to this selection",
"Selections can be extended right off onto neighboring pages"), so they are reachable and are not the
write-into-the-file paths that `PDFOutline`'s two were: what they need is a real range list a selection
can grow, which is what the range model above is. `drawForPage:` needs a `CGContext` and a
`PDFDisplayBox`, which a port that reads documents has no way to be handed; those two are the same shape
as the outline's write paths and say so.
## The five mutators, and the two shapes the header's prose did not settle

`PDFSelection.h:66-79` is the whole of what is known about these before measuring, and the family added the
fixtures. Every row is on a FRESH document, for the reason the seventh round found: **the array a search
answers is the document's own** - a document searched for `alpha` answers an array of 3, searching the same
document for `alpha alpha` afterwards leaves that same array object holding 1, and searching it for `alpha`
again answers the same object again. A second document's search does not touch it. Asking for four needles
in a row gave every row the answers of the last one.

On `cgfixture-words.pdf`, one line of 36 characters, and `cgfixture-3.pdf`, three pages of `page N`:

| call | the host answers |
| --- | --- |
| `{5,5}` + `{5,19}` (one contains the other) | ONE range `{5,19}` - the overlap is removed and the longer survives |
| `{5,5}` + `{25,11}` | two ranges `{5,5}` `{25,11}` |
| `{25,11}` + `{25,5}` (inside) | one range `{25,11}`, unchanged |
| `{25,11}` + `{5,9}` (crossing) | two ranges `{5,9}` `{25,11}` - and they do NOT merge |
| `{5,5}` + `{10,3}` (adjacent, one space between) | two ranges `{5,5}` `{11,3}` - **adjacent ranges are not merged either**, only overlapping ones are |
| `addSelections:` with three at once | three ranges, all applied, in order |
| `-string` of two ranges on one page | the two texts **concatenated with nothing between**: `zero` + `alpha bra` is `zeroalpha bra` |
| `-string` of ranges on two pages | the pages joined with `"\n"`: `page 2` + `page 3` is `page 2\npage 3` |
| `extendSelectionAtEnd:3` on `{5,5}` | `{5,8}` |
| `extendSelectionAtStart:2` on `{5,5}` | `{3,7}` |
| `extendSelectionAtEnd:0` | unchanged |
| `extendSelectionAtEnd:-1` / `extendSelectionAtStart:-1` | `{5,4}` / `{6,4}` - a negative count SHRINKS, which is the only reading an `NSInteger` has |
| `extendSelectionForLineBoundaries` inside one line | the whole line, `{0,36}` |
| the same across two lines already whole | unchanged |
| `extendSelectionAtEnd:20` from page 2 of 3 | **crosses onto page 3**: page 1 `{0,6}`, page 2 `{0,6}`, string `page 2\npage 3` |
| `extendSelectionAtStart:20` from page 2 | crosses back onto page 1: page 0 `{0,6}`, page 1 `{0,4}` |
| `extendSelectionAtEnd:20` from the LAST page | unchanged: there is no page 4 and the page's own text is already covered |
| `initWithDocument:` | nil string, 0 pages, nil colour, `selectionsByLine` 0 |
| `initWithDocument:` then `addSelection:` | the selection the empty one becomes: `alpha`, one range `{5,5}` |

Two more measured facts about the objects themselves:

- **`-[PDFSelection copy]` is a DEEP copy**: extending the copy left the original at `{5,5}` and the copy at
  `{5,8}`, and two copies are two objects.
- **`-[PDFSelection addSelection:]` raises `NSGenericException`, reason `addSelection: selection document
  mismatch`**, when the selection comes from a different `PDFDocument` - even one opened on the same file.
  So the document is compared by identity and not by content, and a caller that opens the file twice cannot
  add across the two.

### The host's own defect, which the port does not copy

**After ONE add, the selection stops answering any further mutation.** Measured, five shapes: an add
followed by an extend (the extend is dropped), an extend followed by an add (the add is dropped), two
extends (both apply), `addSelections:` with three selections in one call (all three apply), and an add
followed by `addSelections:` (the `addSelections:` is dropped). The add path replaces the range storage and
the object keeps a reference to the old one.

The port applies **every** add, which is `PDFSelection.h:69`'s own sentence ("Add the selection to this
selection"), so the two sides differ from the second add onwards and the rows say so. The differential
compares ONE add per selection for that reason and the reason is written next to the comparison, not left
for a reader to infer.

## `-[PDFSelection boundsForPage:]`: the rule, and the three fixtures that fixed it

The row is `implemented`. What follows is what the host answers and where each part of the answer comes
from; the run output is `.agent-work/runs/v-pdfsel2/bounds-measurement.txt` and the predictions written
BEFORE each round asked the host are `.agent-work/runs/v-pdfsel2/bounds-predictions.md` and
`bounds-predictions-2.md`, in the branch that measured them.

### /Widths is what is read, and the two things that are not

The starting point was one number that no arithmetic over the file reproduced: cgfixture-1.pdf's `/Widths`
sum to 3058 per 1000 em (36.6960pt at 12pt), its embedded `/FontFile2` program's own advances sum to 6264
units per 2048 em (36.7031pt), and the host answered **36.7080** - a third number. Two candidates 0.0071pt
apart cannot say which is read, because a rounding step in either explains the gap.

So the disagreement was made enormous instead of delicate, in three fixtures built by
`tools/make-font-fixtures.py`, which lifts the REAL font program verbatim out of the `/FontFile2` stream of
a fixture the conforming writer wrote and writes the `/Widths` beside it:

| fixture | `/Widths` on the six | the program says | **the host answers** | so |
| --- | --- | --- | --- | --- |
| `widths-vs-program-wide` | 1000 each (72.0000pt) | 36.7031 | **72.0000, 717.2400, 12.0000** | `/Widths` |
| `widths-vs-program-narrow` | 250 each (18.0000pt) | 36.7031 | **18.0000, 717.2400, 12.0000** | `/Widths` |
| `no-font-program` | 1000 each, NO `/FontFile2` | - | **72.0000, 717.2400, 12.0000** | `/Widths` |
| `broken-font-program` | 1000 each, program unreadable | - | **72.0000, 717.2400, 12.0000** | `/Widths` |

Three fixtures, both directions, and the third question of the hand-over map - does the host fall back to
the font by NAME - answered: it does not. The two `CGFont` readers the map named are therefore **not
used**, and the map's list of them was written before the measurement that removed them:

- `CGFontCreateWithDataProvider` + `CGFontGetGlyphAdvances` over `/FontFile2` answers 36.7031 where the
  host answers the `/Widths`, and the last fixture is the same one with the program zeroed: the host does
  not notice.
- `CGFontCreateWithFontName` over `/BaseFont` answers **43.2070** for "page 1" in Courier where the host
  answers **43.2000**, so it is not a substitute for the standard metrics either.

`/FirstChar` is read with them: a code outside the `/Widths` span has no width, and that is what
`/LastChar` does without being read.

### The base fourteen, which is the one case /Widths cannot answer

A document relying on one of the standard fourteen carries NO `/Widths`, and the metrics that answer it are
normative data of PDF 1.7 Annex F - which no API on this release hands over (the `CGFont` answer above is
the proof). So they are **measured**, one character at a time, and generated into
`packages/a/apple-backports/PDFKit/Base14Widths11.m` by `tools/make-base14-table.py` from a run of
`tools/host-base14.m`; `--check` says whether the file still matches the measurement. Both halves:

- **the advances**, codes 32..126 of all fourteen, in thousandths of an em. Measured over two fixtures per
  face plus a third, because the host STOPS at 83 characters in one show operator - all 95 codes in one
  give a `-string` of 83 ending at 's' - and because the space is a leading character that the line rule
  trims, so its width is derived as `whole - 2 * w(A)` over two numbers already measured. Every code is
  measured; none is transcribed. The measurement reproduces Helvetica's and Courier's published widths
  exactly, and it CORRECTED one of them: Times-Roman's `t` is 278 here, where a published table says 333.
- **the descent** per face, which is what puts the bottom of a rect when there is no `/FontDescriptor` to
  read one from - every fixture `make-object-fixtures.py` writes has none, and the host answers 717.2402 for
  a line drawn at 720 where a descent of 0 would answer 720.0000. Measured per face, and the measurement
  is again not what a published table says: Courier answers **-246** where the AFM says -157.

Symbol and ZapfDingbats read ZERO for almost every code, and that is measured rather than a gap: their
built-in encodings are not WinAnsiEncoding, so a code written for another face resolves to no glyph in
them. Code 32 is the exception - 250 and 278 - because the space resolves in every one of the fourteen.

### The other three numbers, each measured

| number | what it is | measured |
| --- | --- | --- |
| the x | the text matrix's translation | 20, 72, 360 - every fixture |
| the y | the baseline plus the font's `/Descent` x size / 1000 | 360 - 230 x 12 / 1000 = 357.24, exact, and 717.24 for the base fourteen |
| the height | the EFFECTIVE size, which is `Tf`'s operand TIMES the text matrix's scale | `12 0 0 12 ... Tm` with `/F1 1 Tf` answers the same as an identity matrix with `/F1 12 Tf` - 36.6960 by 12.0000 on `cgfixture-text-matrix-scale.pdf` |

**The effective size is not `Tf`'s operand**, and that was wrong in the first round's model: the text
rendering matrix of Section 9.4.4 multiplies it by the text matrix's scale. The walk therefore reads `Tm`'s
`a` and `d` as well as its translation, and `Td`, `TD`, `T*`, `TL` and `BT` besides - `72 720 Td` is what
every conforming-writer fixture positions its text with, and a walk without `Td` laid all of them out at
the origin.

### The union, and the two shapes that break a naive implementation

- **over two lines**: the union of the per-character rects, and because every rect runs from its own
  baseline's descent up by the size, the rect starts at the LOWER line's descent and ends at the UPPER
  line's top. Measured already and reproduced: "two\nthree" on cgfixture-lines2 answers **42.0384 by
  32.0**, and 32 = 20 + 12 exactly.
- **a page the selection does not cover**: `+inf,+inf,0,0`, which is `CGRectNull`, measured and unchanged.
- **a run whose text the line rule changed**: see the boundaries below.

### The character spacing, measured and not reproduced

`Tc` is the last text-state operator this row carries, because CGPDFContext - the conforming writer every
text fixture here is drawn by - writes `0.0002 Tc` into them. The host's answer then carries a term this
row has measured and **not** reproduced:

- it is non-zero: on the same six glyphs with `/Widths` 556 and 278 at 12pt, `0.0002 Tc` answers 36.6970
  and `0.002 Tc` answers 36.7060, against 36.6960 for no `Tc`;
- it is exactly LINEAR in `Tc` - 0.0010 and 0.0100, five and fifty times 0.0002, and 60 x Tc and 600 x Tc
  under a `12 0 0 12` matrix;
- its per-glyph distribution over "page 1" is 0.0001, 0.0002, 0.0002, 0.0001, 0.0004 and 0.0000, which is
  0.5, 1, 1, 0.5, 2 and 0 multiples of `Tc` - summing to five, which is n - 1 - and the same ratios at ten
  times `Tc`. **The distribution is not explained**, so it is not fitted.

The port applies the format's own rule instead: `Tc` after every glyph but the last, since the spacing after
the final glyph moves the pen on and the pen past the last glyph is not inside any of its rects. That makes
the TOTAL exact and each glyph exact to within one `Tc`, 0.0002pt.

### A TJ array's numbers, which the STRING rule and the GEOMETRY rule disagree about

A number in a `TJ` array is not a character - the host's `-string` does not turn one into a space, which is
why "page 1" does not become "page  1" - but it IS a movement of the pen, and Section 9.3.3 subtracts it in
thousandths of a text-space unit. CGPDFContext writes a `TJ` array rather than a plain show whenever a
string is long enough, and "zero alpha bravo charlie alpha alpha" arrives as one. A geometry that ignored
the adjustments put every element of the array at one x: measured on cgfixture-words.pdf, where the host
answers **23.3424** for "zero" and the `/Widths` come to 23.3400. The walk now reads them.

### The boundaries, each named where the differential accounts for it

| boundary | what | where |
| --- | --- | --- |
| a `/BaseFont` outside the fourteen with no `/Widths` | no advances this port can reach; the fourteen's own are carried | `run.sh`'s stated boundary, second reason |
| a character spacing | the term above, bounded and named, not fitted | `run.sh`'s stated boundary, first reason, list computed over the fixtures |
| a run the line rule changed | a trimmed leading space, collapsed spaces, or a control byte: the rule is measured for the STRING and only in part for the PEN. Worst deviation 10.0152pt on cgfixture-lead (one space and its rounding), the rest 0.0012 and under | `run.sh`'s stated boundary, third reason |
| a composite (Type0) font | NOT MEASURED and not claimed. The fixture for it is written by `make-font-fixtures.py` and switched off: with `/Identity-H`, a `/CIDFontType2` descendant, `/W` and `/CIDToGIDMap /Identity`, the HOST's own page text is "page" for one of them and "pag" for the other where the stream draws "page 1", so there is no selection over those glyphs to ask. `/W` and `/CIDToGIDMap` are therefore not read | `make-font-fixtures.py`, the comment above the switched-off `build_cid` |
| `Tz`, `Ts`, and a `Tm` that is not the first operator in a `BT` | not measured and not claimed | - |
| a code at 0x80 or above | MEASURED, partly: `cgfixture-high-byte.pdf` draws `caf\351` and the host's `-string` keeps the byte as `caf<E9>` of length 4, and the widths still come from `/Widths` - 'a' sits at 78.0000 with width 6.6720, which is 500 + 556 over 12pt. What the CHARACTER is, and what a code outside the `/Widths` span answers, are not measured | - |
