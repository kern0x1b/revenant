# CoreText: emoji clusters typeset whole on iOS 6

CoreText of iOS 6.1.3 cuts a text into runs by the coverage of the primary font, so an emoji sequence is split at its joiner and
its variation selectors and the ligatures of the emoji font never see it. The backports put AppleColorEmoji over each emoji
cluster before CoreText lays the text out, as CoreText of iOS 9 and later and WebKit do by segmenting into extended grapheme
clusters.

## The fault

AppleColorEmoji's `morx` table ligates a ZWJ sequence, a base with a skin tone, a flag and a keycap into one glyph, but only when
the whole cluster is typeset by that font. The run cutter of iOS 6.1.3 gives U+200D to HelveticaNeue (glyph 842) and U+2642 to
HiraKakuProN, so the cluster is several runs of several fonts. Measured on the iPhone 4S, iOS 6.1.3 (runs as font:glyphs):

| cluster | runs with the system's CoreText | with the backports |
| --- | --- | --- |
| man U+200D woman U+200D girl | AppleColorEmoji:1193, HelveticaNeue:842, AppleColorEmoji:1366, HelveticaNeue:842, AppleColorEmoji:1187 | AppleColorEmoji:1544 |
| man, light skin tone, U+200D, laptop | AppleColorEmoji:1194, HelveticaNeue:842, AppleColorEmoji:1850 | AppleColorEmoji:1266 |
| blond man, tone, U+200D, U+2642, U+FE0F | AppleColorEmoji:1608, HelveticaNeue:842, HiraKakuProN-W3:705 | AppleColorEmoji:1609, 65535 |
| white flag, U+FE0F, U+200D, rainbow | AppleColorEmoji:990, 65535, HelveticaNeue:842, AppleColorEmoji:649 | AppleColorEmoji:992, 65535 |
| England's flag (a tag sequence) | LastResort:8 (the "no glyph" box) | AppleColorEmoji:993 |

(65535 is the deleted glyph, which `CTRunDraw` leaves out: `DeletedGlyphs.md`.) A cluster that the system already typeset whole
(a flag of two regional indicators, a thumb with a tone, a keycap) is unchanged.

## The segmentation

`revenant_emoji_clusters.h` (static inline, tested on the host without the library) reads UTF-16 and reports the clusters the
emoji font must typeset whole, by the rules of UAX #29 (GB9, GB9a, GB11, GB12, GB13) and no list of sequences:

    cluster = pictographic Extend* (ZWJ pictographic Extend*)*  |  regional regional  |  keycap-base VS16? U+20E3
    Extend  = VS15, VS16, an emoji modifier (U+1F3FB..1F3FF), U+20E3, a tag (U+E0020..E007F)

- **Pictographic** is a code point that AppleColorEmoji's own cmap covers (`CTFontGetGlyphsForCharacters`) and that is not a
  letter or a mark of any script (`kCFCharacterSetLetter`; the Unicode tables of iOS 6 do not know the emoji of later versions,
  so a property test would miss them, and the font's cmap knows exactly what the installed font can draw). It is looked up next
  to a joiner, a mark or a regional indicator only. The joiner, the marks and the regional indicators are covered by the font too
  and are not taken for pictographics.
- A cluster is reported when the emoji font has something to do with it: a ZWJ that joins a pictographic, VS16, a modifier, a tag,
  the keycap mark or a pair of regional indicators (three regional indicators are a flag and a lone indicator). A lone pictographic, or one with VS15
  (text style), is left to the cascade as before. A joiner in Arabic or Indic text, a joiner followed by a letter, a dangling joiner,
  a digit without the keycap mark and a lone `©` are not clusters.

## What the backports do

`CTEmojiClusters6.m` defines `CTTypesetterCreateWithAttributedString`, `…AndOptions`, `CTLineCreateWithAttributedString` and
`CTFramesetterCreateWithAttributedString` in front of the system's. Each one:

1. takes the UTF-16 of the string (the string's own buffer, else a copy), and hands the attributed string to the system as it is
   when no code unit could belong to a cluster (U+200D, U+FE0F, U+20E3 or the surrogates D83C and DB40: every Latin, Cyrillic,
   Arabic and CJK text without emoji marks, and every eight-bit ASCII string, stops here);
2. else finds the clusters and, for each, sets `kCTFontAttributeName` over its range to AppleColorEmoji at the size of the font that
   was there (a `CTFont`; a UIKit font of iOS 6 through `pointSize`, which the device runs above did not exercise, since the tool has only `CTFont`s; 12 when there is none) in a mutable copy of the attributed
   string. The caller's string, the characters and their indices are not changed: only the font attribute of the cluster's range;
3. gives the copy to the system.

The emoji fonts are made once per size. The font is made when the first code point needs it, not before: making it maps the font
file (+64 MiB of address space on the 4S), which a text of Arabic letters with a joiner must not cost (measured below). Every
release from iOS 7 on is untouched.

## Measured

`tools/ctprobe` of the build repository links the library's CoreText sources into a tool and runs the same lines through the
system's functions and through the linked ones, as Telegram's `TextNode` draws (a text position per line, `CTRunDraw` per run).
On the 4S, iOS 6.1.3, FNV hash of 200x40 bitmaps:

- the 11 cluster cases (family, tone and profession, rainbow flag, blond man, keycap with and without VS16, tag flag, two
  regional indicators, thumb with a tone, a family inside Latin text, a family inside Cyrillic text): the bitmap of the backports
  is equal, to the byte, to the one that the system's functions draw when the cluster has AppleColorEmoji set by hand. The system's
  own bitmap differs from it in 7 of them;
- the 6 controls (Latin, Cyrillic, an Arabic joiner, a lone emoji, `(©)`, digits): the bitmap of the backports is equal to the
  system's, and the runs are the same;
- address space mapped by making one line (a fresh process each): Arabic with a joiner +21.0 MiB with the backports and with the
  system's function; Latin or Cyrillic +2.2 MiB; a lone emoji +66.5 MiB with both; a family +64.3 MiB;
- time of a synthetic chat list (a line made from an attributed string and its runs drawn, best of three, microseconds per round on
  the A5, the third column is the cascade of `FontFallbackCascade.md` alone):

| text | system | cascade only | backports | backports / cascade only |
| --- | --- | --- | --- | --- |
| plain, line made and drawn | 162.4 | 164.1 | 171.0 | 1.042 |
| plain, line made | 109.2 | 109.6 | 114.7 | 1.047 |
| a family and a heart with VS16, made and drawn | 2953.5 | 2990.1 | 1330.5 | 0.445 |
| a family and a heart with VS16, made | 589.6 | 629.4 | 363.7 | 0.578 |
| a heart with VS16, made and drawn | 1423.5 | 1440.6 | 755.2 | 0.524 |

Plain text pays 5.5 us per line made (the scan of the UTF-16 for a cluster, about 2 us, and the scan of the attributed string for a
baseline offset until one was seen, `DeletedGlyphs.md`) and 8.6 us per line made and drawn (that, and for every run drawn the
scan of its glyphs); these two figures were taken with the first version of the offset scan, which `DeletedGlyphs.md` (Measured,
creation) replaced with a per-run scan that costs 0.4 to 1 us less per line made; text with a cluster is cheaper than before because
its runs are fewer and the deleted glyph is not logged.

## Not covered

- Text that UIKit lays out itself (`UILabel`, `UITextView`, `drawInRect:`) is laid out inside the system.
- A lone pictographic of the default text style (U+2764 without VS16) and a sequence of two emoji with no joiner are left to the
  cascade, which already chooses AppleColorEmoji for them.
- A string that a caller changes after making the typesetter is of course not re-clustered.

Tests: `frameworks/Backports/tests/CoreText/emoji_clusters_test.m` (host, 43 checks; a coverage predicate stands in for the font's
cmap and, like the font, covers the joiner, the selectors, the modifiers, the tags, the regional indicators and the keycap bases;
`--negative` is the unfixed answer, which finds nothing).
