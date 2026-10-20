# Text styles and font weights, iOS 7 and 8.2

Source: the host's own UIKit, under Mac Catalyst, asked for every text style and weight and held against the
backport by `tests/backports/host/uikit2/run.sh` (the `misc` group); and iOS 6.0 in the emulator and 6.1.3
on an iPhone 4S and an iPad 2, through `tests/backports/device/uikit2.m`.

## Text styles

`+preferredFontForTextStyle:` answers a font whose size belongs to the style, at the default content size
category, which is the only one iOS 6 has:

| style | points |
|---|---|
| headline | 17, semibold |
| subheadline | 15 |
| body | 17 |
| footnote | 13 |
| caption 1 | 12 |
| caption 2 | 11 |
| callout (private name) | 16 |
| title 1, 2, 3 (private names) | 28, 22, 20 |
| title 0 (private name) | 34 |

A style the system does not know, and the empty string, answer the system font at 12 points. A nil style
answers nil: not a font, and not an exception.

The constants are strings, and their values are the release's own: `UIFontTextStyleSubheadline` is
`UICTFontTextStyleSubhead`, the others carry the name of the style after `UICTFontTextStyle`. Code that
compares them with a string it read from an archive or from the system keeps working.

The newest system answers its own system font; the backport answers the system font of the release, and the
headline the bold one, because iOS 6 has no semibold face. That is the only difference in the answers, and
the host test reports it as known rather than hiding it.

## Weights

The nine `UIFontWeight` constants are the release's floats: ultra light -0.8, thin -0.6, light -0.4,
regular 0, medium 0.23, semibold 0.3, bold 0.4, heavy 0.56, black 0.62.

In the newest system `+systemFontOfSize:weight:` answers a face for any weight at all, and a weight
between two of the constants is a font between two faces. iOS 6 has three faces of the system font, so the
backport takes the nearest one:

- above medium (semibold, bold, heavy, black): the bold system font;
- from just under regular to medium: the regular system font, and a weight of -0.1 is that;
- at light and below, that is at or under -0.2 - halfway between regular and light - the light face.

The size is always kept.

## Where iOS 6 answers differently

The light face is the system font's family name with `-Light`, taken only when it exists in the same family.
The iPad 2 has `Helvetica-Light`, so a light weight there is a lighter font than the regular one. The
iPhone 4S has none for `.HelveticaNeueUI`, and neither does the emulator's iPhone: there a light weight
answers the regular font, which is the nearest face the device has and not an omission of the backport.
Medium and semibold are likewise not distinct from regular and bold; that is the ceiling of the release's
fonts, not of the backport.

The four `UIFontWidth` constants are the host's floats: standard 0, expanded 0.2, condensed -0.2, compressed -0.3.
`systemFontOfSize:weight:width:` answers the font of the weight: no font of iOS 6 has another width, so the width is
read and does not change the choice, and a descriptor that carries `UIFontWidthTrait` is matched as a standard one.
