# CoreText: the deleted glyph in `CTRunDraw` and `CTLineDraw` on iOS 6

On iOS 6.1.3 a run whose font deleted a glyph through its `morx` table keeps the glyph 0xFFFF in its glyph array and CoreText
draws it. libCGFreetype cannot load it and logs two `<Error>` lines for every drawing of the run. The backports draw the live
glyphs of the run only.

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

`CTDeletedGlyphs6.m` defines `CTRunDraw` and `CTLineDraw` in front of the system's (both are in `flat_classes.lua`, so the
application's references bind to the library):

- `CTRunDraw` reads the glyphs of the range it is given (a length of 0 means to the end of the run, as in CoreText). A range
  without the marker goes to the system's `CTRunDraw` as one unchanged call. Otherwise each stretch of live glyphs is drawn by
  its own call with the range of the stretch, never an empty one. The glyphs keep their positions, since `CTRunDraw` places
  glyph *i* at the text position plus its position in the run.
- `CTLineDraw` goes to the system's when no run of the line has the marker; else it draws every run as above.
- Every release from iOS 7 on is untouched: each entry point checks `NSFoundationVersionNumber` and calls the system.

The logic is `revenant_deleted_glyphs.h` (static inline, tested on the host without the library).
`CTDrawBaselineOffset7.m` no longer defines `CTRunDraw` and `CTLineDraw`: a `BACKPORT_IMPL` of a name makes the generated
forwarder of that symbol a strong definition, so a second definition in the library is a duplicate symbol. Those two bodies
were fallbacks the forwarder reaches only when the system lacks the function, which no release does (the baseline-offset model
is therefore not applied to `CTRunDraw` and `CTLineDraw` on 6.1.3, before and after this change; `CTFrameDraw` and the metrics
are still the system's with the same fallback arrangement).

## Not covered

A line that holds the marker is drawn run by run. What `CTLineDraw` may draw beside the glyphs of its runs (a decoration such as an underline) is not measured on 6.1.3 and not reproduced for such a line; a line without the marker is the system's call.

`CTFrameDraw` draws through the system's code and still logs the lines for a frame with such a run. Text that UIKit draws itself
(`UILabel`, `drawInRect:`) calls CoreText inside the system and is not reached.

## Measured

`tools/ctprobe` of the build repository links `CTFontCascade6.m`, `CTDeletedGlyphs6.m` and `CTEmojiClusters6.m` into a tool and
draws the same lines through the system's functions (taken with `dlsym`) and through the linked ones, as Telegram's `TextNode`
does (a text position per line, `CTRunDraw` per run). On the 4S, iOS 6.1.3, 160x40 bitmaps, FNV hash of the pixels:

- the three cases above, and the other controls: the bitmaps are equal to the system's, to the byte;
- stderr: 0 bytes with the backports, 216 / 108 / 108 bytes with the system's functions (the `CTLineDraw` of the first case writes
  108);
- drawing time of `Hi ` + U+2764 U+FE0F (a line made and its runs drawn, best of three, 1500 rounds, stderr to `/dev/null`):
  1406 us with the system's functions, 751 us with the backports. The saved time is the logging.
- plain text (Latin or Cyrillic, no marker): the check costs between 0.2 and 1 us per run drawn, against about 54 us for the whole drawing of a one-run line (the difference of two measurements of the same size, so it has that noise).

Tests: `frameworks/Backports/tests/CoreText/deleted_glyphs_test.m` (host; `--negative` is the unfixed answer, which draws every
glyph in one piece).
