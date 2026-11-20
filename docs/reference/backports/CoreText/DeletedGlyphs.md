# CoreText: the deleted glyph and the baseline offset in `CTRunDraw`, `CTLineDraw` and `CTFrameDraw` on iOS 6

On iOS 6.1.3 a run whose font deleted a glyph through its `morx` table keeps the glyph 0xFFFF in its glyph array and CoreText
draws it. libCGFreetype cannot load it and logs two `<Error>` lines for every drawing of the run. The backports draw the live
glyphs of the run only, in all three draw entry points, and move a run by its `NSBaselineOffset` in the same three, which the
system's CoreText of that release ignores.

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

`CTDrawBaselineOffset7.m` defines `CTRunDraw`, `CTLineDraw` and `CTFrameDraw` in front of the system's (the three are in
`flat_classes.lua`, so the application's references bind to the library). Each one asks two questions of what it is to draw and
calls the system's function unchanged when both answers are no:

- **A baseline offset.** `NSBaselineOffset` is a run attribute that CoreText of iOS 6 does not read (`revenant_needs_model()`
  probes it once: a line with the attribute and a line without it are drawn by the system's `CTLineDraw` and the ink of the two
  compared). The run is drawn with the text position moved by `(0, offset)` taken through the text matrix, so a flipped context
  lowers the text position and the run still rises on the screen; the position is put back afterwards.
- **A deleted glyph** (`revenant_deleted_glyphs.h`, only before iOS 7). The glyphs of the range are read, and the system's
  `CTRunDraw` draws each stretch of live glyphs by its own call with the range of the stretch, never an empty one. A range
  without the marker goes to the system as one unchanged call. The glyphs keep their positions, since `CTRunDraw` places glyph
  *i* at the text position plus its position in the run and does not advance the text position, so every stretch falls where the
  whole run would have drawn it. The shift of the offset is made once around all the stretches of a run.

The entry points differ in how they reach the runs:

- `CTRunDraw` reads the glyphs of the range it is given (a length of 0 means to the end of the run, as in CoreText) and the
  offset of the run.
- `CTLineDraw` goes to the system's when no run of the line has an offset or the marker; else it draws every run as above, at the
  text position the caller set. The system's `CTLineDraw` also draws what `CTRunDraw` does not, the underline of
  `kCTUnderlineStyleAttributeName` and `NSUnderline` (Measured), so two lines are not drawn run by run: a line with the marker
  and an underline and no offset goes to the system whole, and a line with an offset and an underline gets its underline from
  a second call of the system's `CTLineDraw` made with the text drawing mode invisible and the text position shifted by the
  offset all the runs share (not drawn when the runs differ in offset).
- `CTFrameDraw` goes to the system's when no line of the frame has an offset or the marker; else it sets the text position of
  every line to the line's origin plus the origin of the frame's path box and draws the line as `CTLineDraw` does. The origins are
  the system's (`CTFrameGetLineOrigins`), or, when a line has an offset, the origins of the model that moves the lines to make
  room for the raised or lowered run (the model that the host oracle `baseline_offset_oracle_test.lua` compares with the native
  CoreText of macOS: line, run, frame, metrics, origins, suggested size).

Every release from iOS 7 on is untouched: the marker is looked for only before iOS 7 (`NSFoundationVersionNumber`), and the
offset only where the probe finds that the system ignores it.

The logic of the stretches and of the shift is `revenant_deleted_glyphs.h` (static inline, tested on the host without the library).

## Why they are plain definitions

A `BACKPORT_IMPL(name)` marks an implementation that the generated forwarder of the symbol reaches only when the system lacks
the function (`revenant_impl.h`, commit 10588c08b), and it makes the forwarder a strong definition of its own, so a second
definition of the same name is a duplicate symbol. `CTRunDraw`, `CTLineDraw` and `CTFrameDraw` were written that way, so on 6.1.3,
where the system has them, the baseline-offset model never ran for them. They are plain definitions now, like `CTFontCascade6.m`'s
`CTFontCreateWithName`: a strong definition in the library shadows the weak forwarder. The linked `libCoreTextBackports.dylib`
(armv7) defines each of the three once.

## Not covered

- `CTLineGetTypographicBounds`, `CTLineGetBoundsWithOptions`, `CTLineGetImageBounds`, `CTFrameGetLineOrigins` and
  `CTFramesetterSuggestFrameSizeWithConstraints` are still `BACKPORT_IMPL` in the same file, so on 6.1.3 they answer with the
  system's numbers: a run with an offset is drawn raised or lowered, but the line's height, its bounds and the frame's origins
  and suggested size do not make room for it, apart from the frame that `CTFrameDraw` itself lays out as above.
- A line with the marker and an underline is drawn by the system: its pixels are the system's and the two log lines stay.
- A line with an offset and an underline: the underline is drawn by the invisible second call, which does not stop a colour
  emoji (a bitmap glyph) from being painted again, so such a line with an emoji and an underline and an offset has the emoji
  painted twice. On macOS the native underline of a run raised by 6 at 24 points sits 2 points lower than the one the
  shift draws (for a run lowered by 4 the two are equal), so the underline of a raised run is approximate.
- `NSStrikethrough` is drawn by neither CoreText of 6.1.3 nor the backports (UIKit draws it).
- Text that UIKit draws itself (`UILabel`, `drawInRect:`) calls CoreText inside the system and is not reached.

## Measured

`tools/ctprobe` of the build repository links `CTFontCascade6.m`, `CTDrawBaselineOffset7.m` and `CTEmojiClusters6.m` into a tool and
draws the same lines through the system's functions (taken with `dlsym`) and through the linked ones, as Telegram's `TextNode`
does (a text position per line, `CTRunDraw` per run) and through `CTLineDraw` and `CTFrameDraw`. The `draw` item runs 120
configurations: 20 texts (plain, coloured, `kCTUnderlineStyleAttributeName`, `NSUnderline`, `NSStrikethrough`, both, raised by 6,
lowered by 4, raised with an underline of either kind, `Hi ` U+2764 U+FE0F alone, coloured, with each underline, with all of
them, raised, two stretches in one line, and four wrapped frames) in line, runs and frame mode, each under an identity, a flipped
(CTM and text matrix) and a rotated and scaled text matrix. After every drawing a plain line is drawn by the system's `CTLineDraw`
into the same bitmap, so a fill colour or a text matrix that the first drawing leaked changes the hash. On the 4S, iOS 6.1.3, 200x40
bitmaps, FNV hash of the pixels:

- without an offset (81 configurations): the bitmap of the backports is equal to the system's, to the byte, in all of them, and so
  are the text position and the text matrix after the drawing (the system's `CTFrameDraw` leaves the text position at the origin
  of the last line, and so do the backports); stderr is 0 bytes with the backports in 69 of them and 108 in the 12 that hold the
  marker and an underline, which are handed to the system (the system writes 108 or 216 bytes in all 51 configurations that hold
  the marker);
- the underline: the system's `CTLineDraw` of `kCTUnderlineStyleAttributeName` and of `NSUnderline` draw the same underline, and
  the system's own `CTRunDraw` loop over the runs of the same line draws none (its bitmap is the plain text's, in 6 of 6 matrices);
  a first version that drew the runs of a line with the marker and then the line again with the text invisible painted the colour
  emoji twice (the bitmaps differed in every configuration with the marker, in line and in frame mode) and left the log lines,
  and was dropped for those lines;
- with an offset (36 configurations): the system draws the plain text, as `NSBaselineOffset` is not read; the backports draw the run
  moved, and the bitmap is equal to the system's drawing of the same line without the attribute with the text position moved by
  the offset through the text matrix, in all 36, under the three matrices and in line and runs mode, with an underline of either
  kind or none, and with the marker (the marker lines write 0 bytes); the raised wrapped frame lays its lines out by the model
  (the text position after it is the model's, not the system's);
- time of a synthetic chat list, best of three, microseconds per round on the A5 (the third column is the cascade of
  `FontFallbackCascade.md` alone):

| text | system | cascade only | backports | backports / cascade only |
| --- | --- | --- | --- | --- |
| plain, line made and drawn | 159.9 | 161.7 | 167.6 | 1.036 |
| plain, line made | 109.6 | 109.6 | 111.8 | 1.020 |
| a family and a heart with VS16, made and drawn | 2937.1 | 2977.3 | 1318.3 | 0.443 |
| `Hi ` U+2764 U+FE0F, made and drawn | 1410.5 | 1439.9 | 755.0 | 0.524 |

  Plain text pays 2 us per line made and 6 us per line made and drawn: the typesetter check, and for every run drawn the lookup
  of the offset in its attributes and the scan of its glyphs (the drawing of a one-run line is about 50 us); a line with the marker is
  cheaper than before because the drawing no longer logs.

The saved time of a line with the marker is the logging.

Tests: `frameworks/Backports/tests/CoreText/deleted_glyphs_test.m` (host, 20 checks: the stretches of a glyph array, the shift of the
text position through an identity, a flipped and a scaled text matrix, the stretches drawn at the shifted position and the position
put back; `--negative` is the unfixed answer, which draws every glyph in one piece and ignores the offset) and the macOS oracle
`baseline_offset_oracle_test.lua` (the model against the native CoreText of the host: a line, its runs and a frame with an offset,
the layout, the bounds, and the underline of a plain and of a lowered line).
