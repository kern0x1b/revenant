# CoreText: the deleted glyph, the baseline offset and the underline in the draw and metrics entry points on iOS 6

On iOS 6.1.3 a run whose font deleted a glyph through its `morx` table keeps the glyph 0xFFFF in its glyph array and CoreText
draws it. libCGFreetype cannot load it and logs two `<Error>` lines for every drawing of the run. The backports draw the live
glyphs of the run only, in all three draw entry points, and move a run by its `NSBaselineOffset` in the same three and in the five
metrics entry points, which the system's CoreText of that release ignores. A line that cannot go to the system whole draws its own
underline, by the rules the system's `CTLineDraw` follows on the device (Underline).

## The fault

AAT's `morx` has a delete action: a glyph a ligature or a substitution consumed is replaced by the deleted-glyph marker 0xFFFF.
The current AppleColorEmoji (3844 glyphs) uses it for a variation selector after a text-default emoji and for the tail of a
sequence. CoreText of iOS 6.1.3 leaves the marker in `CTRunGetGlyphs` and `CTRunDraw` passes it on to libCGFreetype, which asks
FreeType for a glyph index past the font's glyph count. FreeType answers `FT_Err_Invalid_Argument` (6) and libCGFreetype logs

    AppleColorEmoji: FT_Load_Glyph failed: error 6.

twice per drawing (two `asl` lines, 108 bytes each on stderr). Measured on the iPhone 4S, iOS 6.1.3:

| text | run | glyphs | lines per drawing |
| --- | --- | --- | --- |
| `Hi ` U+2764 U+FE0F | AppleColorEmoji | 338, 65535 | 2 |
| `1` U+FE0F U+20E3 (keycap) | AppleColorEmoji | 139, 65535 | 1 |
| U+1F3F3 U+FE0F U+200D U+1F308 (rainbow flag) | AppleColorEmoji | 990, 65535 | 1 |

Telegram's first chat list drew three such runs and logged 6 lines. The marker has no ink and no advance: leaving it out of the
drawing changes no pixel.

## What the backports do

`CTDrawBaselineOffset7.m` defines `CTRunDraw`, `CTLineDraw`, `CTFrameDraw`, `CTLineGetTypographicBounds`,
`CTLineGetBoundsWithOptions`, `CTLineGetImageBounds`, `CTFrameGetLineOrigins` and `CTFramesetterSuggestFrameSizeWithConstraints` in
front of the system's (the eight are in `flat_classes.lua`, so the application's references bind to the library). Each one asks what
it is to draw or measure and calls the system's function unchanged when the answer is that nothing is to be changed:

- **A baseline offset.** `NSBaselineOffset` is a run attribute that CoreText of iOS 6 does not read (`revenant_needs_model()`
  probes it once: a line with the attribute and a line without it are drawn by the system's `CTLineDraw` and the ink of the two
  compared). The run is drawn with the text position moved by `(0, offset)` taken through the text matrix, so a flipped context
  lowers the text position and the run still rises on the screen; the position is put back afterwards.
- **The offset seen.** Every line, typesetter and framesetter of an application is made by one of four creation functions that
  `CTEmojiClusters6.m` shadows (`CTLineCreateWithAttributedString`, `CTTypesetterCreateWithAttributedString`,
  `CTTypesetterCreateWithAttributedStringAndOptions`, `CTFramesetterCreateWithAttributedString`). Each one first calls
  `revenant_note_baseline_offset` (hidden, `revenant_baseline_offset_seen.h`), which looks through the attributed string, run by run
  (`CFAttributedStringGetAttributeAndLongestEffectiveRange`), for an `NSBaselineOffset` that is not 0 and sets a process-wide flag
  when it finds one. Until the flag is set, no line of the process has an offset, so the five metrics entry points are one call of
  the system's, and the three draw entry points skip the lookup of the offset in the attributes of every run
  (`revenant_may_offset()`). Once it is set (the first string with an offset), every entry point looks at the runs of its line or
  frame, and a line or a frame without an offset still goes to the system whole.
- **A deleted glyph** (`revenant_deleted_glyphs.h`, only before iOS 7). The glyphs of the range are read, and the system's
  `CTRunDraw` draws each stretch of live glyphs by its own call with the range of the stretch, never an empty one. A range
  without the marker goes to the system as one unchanged call. The glyphs keep their positions, since `CTRunDraw` places glyph
  *i* at the text position plus its position in the run and does not advance the text position, so every stretch falls where the
  whole run would have drawn it. The shift of the offset is made once around all the stretches of a run.
- **An underline.** The system's `CTLineDraw` draws what `CTRunDraw` does not, the underline of `kCTUnderlineStyleAttributeName` and
  of `NSUnderline`. A line that is drawn run by run (it has an offset or the marker) gets its underline drawn by the backports.

The entry points differ in how they reach the runs:

- `CTRunDraw` reads the glyphs of the range it is given (a length of 0 means to the end of the run, as in CoreText) and, once an
  offset was seen, the offset of the run.
- `CTLineDraw` goes to the system's when no run of the line has an offset or the marker; else it draws every run as above, at the
  text position the caller set, and then the underlines of the line (Underline). A line with the marker and an underline is drawn
  like any other line with the marker: every run through the stretches, then the underline by the backports; the system is not
  called a second time for the underline, so a colour emoji is painted once and the log lines stay gone.
- `CTFrameDraw` goes to the system's when no line of the frame has an offset or the marker; else it sets the text position of
  every line to the line's origin plus the origin of the frame's path box and draws the line as `CTLineDraw` does. The origins are
  the system's (`CTFrameGetLineOrigins`), or, when a line has an offset, the origins of the model that moves the lines to make
  room for the raised or lowered run (the model that the host oracle `baseline_offset_oracle_test.lua` compares with the native
  CoreText of macOS: line, run, frame, metrics, origins, suggested size).
- The five metrics entry points are the system's own answer unless an offset was seen and the line (or frame) has a run with one.
  `CTLineGetTypographicBounds` then returns the system's width and the ascent and descent of the model (the largest of each run's
  ascent plus its offset and descent minus its offset), `CTLineGetImageBounds` and `CTLineGetBoundsWithOptions` (with
  `kCTLineBoundsUseGlyphPathBounds`) the union of the runs' ink moved by their offsets, `CTFrameGetLineOrigins` the origins of
  the model, and `CTFramesetterSuggestFrameSizeWithConstraints` the system's width and the height of a frame it makes of the same
  framesetter, constraints and attributes when the offset was seen (a second layout, so it costs about twice the system's once the
  offset was seen; before that it is one system call).

Every release from iOS 7 on is untouched: the marker is looked for only before iOS 7 (`NSFoundationVersionNumber`), and the
offset only where the probe finds that the system ignores it.

The logic of the stretches and of the shift is `revenant_deleted_glyphs.h`, and the geometry of the underline is
`revenant_underline.h` (both static inline, tested on the host without the library).

## Underline

Measured on the iPhone 4S, iOS 6.1.3, by drawing lines with the system's `CTLineDraw` into a bitmap and reading the bar:

- the font's underline position and thickness the API reports are synthetic (`CTFontGetUnderlinePosition` is `-size/8`,
  `CTFontGetUnderlineThickness` is `0.05 * size`); the bar the system draws is not those numbers but their rounding:
  a single bar is `max(1, ceil(thickness))` thick, centred on `round(position)` below the baseline, `ceil(width)` wide, starting at
  the run's position, drawn in the underline colour (`kCTUnderlineColorAttributeName`, `NSUnderlineColor`, else the foreground
  colour, else black);
- a double underline (style value 9) is two bars, each `round(0.75 * thickness * 64) / 64` thick, centred at `centre + 0.5` and
  `centre - 1.5`;
- consecutive runs with the same style, colour and offset are one underline, from the first run's position to the end of the last
  one; at the end of the line the trailing whitespace is not underlined;
- a raised or lowered run takes its underline with it, and a raised run's underline stops at the baseline (the centre is
  `min(centre + offset, 0)`); this is what the host's native CoreText does (`baseline_offset_oracle_test.lua`);
- the bar is in the text matrix's space: its position moves with the text matrix's translation and, when the text matrix is
  not the identity, a text position whose `ty` is fractional snaps the bar by `floor(ty) - ty` through the matrix (in a flipped
  context the bar moves twice the distance of the text); the thickness is not scaled by the text matrix's scale (a bar is one pixel
  across under a matrix that scales by 1.25 and rotates), the centre offset is; the context's own scale (retina) scales both;
- dotted, dashed and mixed patterns of the style value are drawn solid by the backports, and `NSStrikethrough` is drawn by neither
  CoreText of 6.1.3 nor the backports (UIKit draws it).

## Why they are plain definitions

A `BACKPORT_IMPL(name)` marks an implementation that the generated forwarder of the symbol reaches only when the system lacks
the function (`revenant_impl.h`, commit 10588c08b), and it makes the forwarder a strong definition of its own, so a second
definition of the same name is a duplicate symbol. The three draw functions and the five metrics functions were written that way,
so on 6.1.3, where the system has them, the baseline-offset model never ran for them. They are plain definitions now, like
`CTFontCascade6.m`'s `CTFontCreateWithName`: a strong definition in the library shadows the weak forwarder. The linked
`libCoreTextBackports.dylib` (armv7) defines each of the eight once (`nm`).

## Not covered

- A line with an offset or the marker whose underline has a pattern other than solid or double has it drawn solid.
- `NSStrikethrough` is drawn by neither CoreText of 6.1.3 nor the backports (UIKit draws it).
- The system's rasterisation of a bar that covers a pixel partly differs from the backports' by one level of alpha at some
  fractional text positions, by two in the rows of a double underline, and by up to 12 at its edges under a rotated and scaled text
  matrix; the
  bars' geometry (position, thickness, width, colour) is equal, and the pixels are equal to the byte at whole positions
  (Measured).
- A line whose runs differ in offset is underlined run group by run group; the underline of a raised run that the system would
  draw lower than the baseline (in the region where macOS's own answer is not monotonic) stops at the baseline.
- Text that UIKit draws itself (`UILabel`, `drawInRect:`) calls CoreText inside the system and is not reached.
- Once an offset was seen, `CTFramesetterSuggestFrameSizeWithConstraints` costs about 2.2 times the system's.

## Measured

`tools/ctprobe` of the build repository links `CTFontCascade6.m`, `CTDrawBaselineOffset7.m` and `CTEmojiClusters6.m` into a tool and
draws the same lines through the system's functions (taken with `dlsym`) and through the linked ones, as Telegram's `TextNode`
does (a text position per line, `CTRunDraw` per run), through `CTLineDraw` and `CTFrameDraw`, and through a loop over the live
runs. The `draw` item runs 474 configurations (texts with and without underline, colour, double underline, offset, the marker,
two stretches in one line and wrapped frames, in line, runs, live-run and frame mode, under an identity, a flipped (CTM and text
matrix) and a rotated and scaled text matrix, at whole and at fractional text positions). After every drawing a plain line is
drawn by the system's `CTLineDraw` into the same bitmap, so a fill colour or a text matrix that the first drawing leaked changes
the hash. On the 4S, iOS 6.1.3, 200x40 bitmaps, FNV hash of the pixels:

- text position and text matrix after the drawing equal the system's in 465 of 474 (the nine are wrapped frames with a raised run,
  whose lines the model lays out); stderr is 0 bytes in all 474 with the backports, 108 or 216 bytes in the 156 that hold the
  marker with the system;
- without an offset the bitmap is the system's, to the byte, at whole text positions, and the underline layer (the drawing
  minus the same line drawn without underline) equals the system's in 124 of the 204 underline layers measured; the other 80
  are the residue above: one level of alpha at partly covered pixels (the single bar at a fractional position, in all three
  matrices), two levels in the rows of a double bar, and up to 12 levels at the edges of a double bar under the rotated matrix;
  geometry (rows, columns, thickness) equal;
- the system's own `CTRunDraw` loop over the runs of an underlined line draws no underline (its bitmap is the plain text's), so a
  line that is drawn run by run needs the backports' own underline; a first version that drew the runs of a line with the marker
  and then called the system's `CTLineDraw` with the text invisible painted the colour emoji twice and left the log lines;
- with an offset, the system draws the plain text, as `NSBaselineOffset` is not read; the backports draw the run moved, and the
  bitmap equals the system's drawing of the same line without the attribute with the text position moved by the offset through
  the text matrix in 47 of the 63 configurations that compare it; the other 16 are lines with an underline at a fractional
  position (the same residue) and the rotated matrices;
- the host oracle (`baseline_offset_oracle_test.lua`, native CoreText of macOS): an underline of a run lowered by 8, 4, 2 and
  raised by 2 moves exactly as the native one does, and raised by 6 the native bar moves 4.00 rows and the backports' 4.04;
- the metrics (`metrics` item, A5, best of five, nanoseconds per call; a one-run and a three-run line, a one-run and a three-run
  frame; "system" is the system's function taken with `dlsym`):

| call | offset not seen: system | backports | backports / system | offset seen (3 runs, one raised): backports / system |
| --- | --- | --- | --- | --- |
| `CTLineGetTypographicBounds` | 33 | 65 | +32 ns | 2815 ns (85x) |
| `CTLineGetBoundsWithOptions` | 420,479 | 421,613 | 1.003 | 1.016 |
| `CTLineGetImageBounds` | 421,260 | 421,480 | 1.001 | 1.015 |
| `CTFrameGetLineOrigins` | 97 | 123 | +26 ns | 3936 ns (41x) |
| `CTFramesetterSuggestFrameSizeWithConstraints` | 67,061 | 67,297 | 1.004 | 2.22 |

  With no offset seen the three calls that do work are within noise (0.1 to 0.4 %), and the two that cost 33 and 97 ns are a
  call and a flag test more (+32 and +26 ns, a thousandth of the 78 us the line or the frame took to make). Once an offset was
  seen, a line with a raised run answers `CTLineGetTypographicBounds` in 0.8 us (one run) to 2.8 us (three runs) and a frame
  `CTFrameGetLineOrigins` in 1.9 to 3.9 us: the model measures every run; a line without an offset still costs one system call
  and a lookup in the attributes of each of its runs;
- creation (`create` item, A5, 2000 calls, best of five): `CTLineCreateWithAttributedString` 78.5 us system and 83.9 us linked
  for a one-run string (+5.3 us, 6.8 %), 216.4 and 223.9 us for three runs (+7.5 us, 3.5 %); the typesetter and the framesetter
  creation differ by the same amounts. The 5 to 7 us are the offset scan of the attributed string
  (`CFAttributedStringGetAttributeAndLongestEffectiveRange`, an Objective-C message to the string on iOS 6; the same scan costs
  42 ns of a 2.5 us line creation on the host) and the cluster check of `EmojiClusters.md` (about 2 us of them); once an offset
  was seen the scan is skipped;
- time of a synthetic chat list, best of three, microseconds per round on the A5 (the third column is the cascade of
  `FontFallbackCascade.md` alone):

| text | system | cascade only | backports | backports / cascade only |
| --- | --- | --- | --- | --- |
| plain, line made and drawn | 162.4 | 164.1 | 171.0 | 1.042 |
| plain, line made | 109.2 | 109.6 | 114.7 | 1.047 |
| a family and a heart with VS16, made and drawn | 2953.5 | 2990.1 | 1330.5 | 0.445 |
| a family and a heart with VS16, made | 589.6 | 629.4 | 363.7 | 0.578 |
| `Hi ` U+2764 U+FE0F, made and drawn | 1423.5 | 1440.6 | 755.2 | 0.524 |
| `Hi ` U+2764 U+FE0F, made | 315.3 | 347.4 | 262.2 | 0.755 |

  Plain text pays 5.5 us per line made (the offset scan and the cluster check) and 8.6 us per line made and drawn (the draw
  adds the typesetter check and, for every run, the glyph scan; a one-run line's drawing is about 50 us); a line with the marker is
  cheaper than the system's because the drawing no longer logs.

Tests: `frameworks/Backports/tests/CoreText/deleted_glyphs_test.m` (host, 20 checks: the stretches of a glyph array, the shift of the
text position through an identity, a flipped and a scaled text matrix, the stretches drawn at the shifted position and the position
put back; `--negative` is the unfixed answer, which draws every glyph in one piece and ignores the offset),
`tests/CoreText/underline_test.m` (host, 24 checks: the bars of a single, thick, double, coloured, raised and lowered underline
against the measured values, the placement through an identity, a flipped and a rotated text matrix, a line with the marker whose
underline is drawn once and whose runs are drawn through the live stretches, a line of mixed offsets keeping its underline; the
`--negative` mode fills the unrounded bars and fails every geometry check) and the macOS oracle `baseline_offset_oracle_test.lua` (the
model against the native CoreText of the host: a line, its runs and a frame with an offset, the layout, the bounds, and the
underline of a plain, a lowered and a raised line).
