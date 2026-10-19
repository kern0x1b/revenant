# Symbol images, iOS 13.0: UIImage, UIImageView and the weight functions

Introduced in iOS 13.0: `UIImage` gets a symbol configuration, `-isSymbolImage`, the three `+systemImageNamed:` forms and
`-imageByApplyingSymbolConfiguration:`; `UIImageView` a `preferredSymbolConfiguration`; and two functions turn a font weight into a symbol weight and back.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by `tests/backports/host/uikit2` (the `symbols` group).

## Symbols the port draws

iOS 6 has no SF Symbols and the port carries none of the system's outlines: each glyph is a script of the port's own, in a small language of paths over a box of 100 by 100 units
(lines, curves, arcs, ellipses, rounded rectangles, stars, gears, arrowheads, dots, glyphs drawn inside another glyph, and a clear mode that cuts a shape out of what is under it), run by
Core Graphics into a bitmap. The naming grammar is the system's: `.fill` fills what is closed, `.circle`, `.square`, `.rectangle` and `.diamond` (and their `.fill`) put the glyph in an
enclosure - cut out of a solid one - `.slash` strikes it through with a gap, `.badge.X` and `.trianglebadge.exclamationmark` put a small badge at a corner, `square.split.AxB`,
`square.grid.AxB` and `gauge.with.dots.needle.NNpercent` are made from their numbers; the rest are scripts of their own. The names that are answered are the 549 of `CharonSymbolMetrics.h`:
the 251 that ten applications of the corpus name, and 298 common ones; `+systemImageNamed:` is nil for every name outside it, as it is for a name the system does not know, and says so once in the log.

What the host's own symbols were measured for, and written into `CharonSymbolMetrics.h` by the `symbols` group (`CHARON_WRITE_SYMBOLS=<directory>` rewrites it): the size of the image, its
alignment insets and its baseline at point sizes 17 and 100, weights 1, 4, 7 and 9 and the three scales, which the port interpolates for other sizes and weights; and the margin between the
image and its drawing. The port's answers are within a point of the host's for all 549 names at eight configurations (17/regular/medium, 34/heavy/large, 12/ultra light/small, 100/black/small,
24/thin/large, 48/semibold/medium, 10/medium/medium and the default scale), which the group checks. The size of the image, the insets and the baseline are the measure of the host's glyph and not
of the drawing: the alignment rectangle is the same height for every name at a point size, 1.174 times it, and the baseline is that above the bottom by 0.2085 times it.

The line is the point size times 0.025, 0.04, 0.07, 0.09, 0.11, 0.13, 0.15, 0.185 and 0.21 for the nine weights, read off the host's minus sign at 100 points; the scale changes the size of the image
and the space around the drawing, not the line. The size comes from the configuration's point size, else from its text style (`UICTFontTextStyle...` sizes of the table in `UIImageSymbolConfiguration.m`), else 17.
The image is made in the scale of the screen (or of the configuration's traits), is a template image (`renderingMode` is `AlwaysTemplate`, where the host's answer is `Automatic`, the port's tint
working on template images), and has its alignment insets. `-imageWithRenderingMode:` of it, in the port, makes an ordinary image, which is no longer a symbol.

### How close the drawings are

The `symbols` group draws each of the 549 names at 12, 17, 32 and 64 points, regular, medium, with the host and with the port, puts the two bitmaps on one canvas by their middles, and takes the
area where both are inked over the area where either is (inked is alpha above one half; the mean of the four sizes is a name's score). The scores, run of 2026-09-20: over the 549 names the
minimum is 0.100 and the median 0.70; over the 251 of the corpus 0.149 and 0.62. A filled or enclosed glyph is above 0.8 (`arrow.left.circle.fill` 0.95, `exclamationmark.circle.fill` 0.98), and a fine
line drawing is where the score is low, since a line one pixel from the host's is no overlap at all: 85 of the corpus names and 133 of all are below 0.5, 22 and 35 below 0.3. The lowest are the
glyphs that are many thin marks at once (the cursor with rays, the gauges, the dotted chevrons, `speaker.zzz`), and those whose form is a guess (`arrow.turn.*`, `arrow.2.squarepath`,
`brain.head.profile`, `externaldrive.badge.*`, whose badge is at the left in the host). The group fails below 0.10 for any name or 0.60 for the median. The device test holds the port to a 16 by 16 grid of
the host's drawing at 17 points, `symbols-expectations.h` (50 of the 549 are below its 0.35, where an eighth, 68, is allowed; the total coverage of the two drawings is within 2 per cent, so the line is no thicker or thinner than the host's).

## Names the host knows and the port does not draw

The absent-symbols list - names the host's `systemImageNamed:` answers, of those tried (the corpus and about 460 common names), that have no script yet, and so are nil - is
`tests/backports/host/uikit2/symbols-absent.txt`, checked by the group (each is the host's and nil in the port). None of the 251 names of the corpus is on it. Adding a script and the name to
`symbols-names.txt` (then `CHARON_WRITE_SYMBOLS`) draws one:

airplane alarm ant antenna.radiowaves.left.and.right applewatch arrow.branch arrow.down.doc arrow.merge arrow.turn.down.right arrow.turn.up.right arrow.up.doc arrow.uturn.down arrow.uturn.up at atom bag bag.fill barcode battery.100 battery.25 bicycle bold bolt.shield books.vertical bubble.right building building.2 building.columns burst bus car car.fill cart cart.fill chart.line.uptrend.xyaxis checklist checkmark.seal chevron.left.2 chevron.right.2 circle.grid.2x2 cloud.bolt cloud.rain cloud.sun cpu creditcard creditcard.fill crown crown.fill decrease.indent desktopcomputer dial.max dial.min ear ellipsis.message envelope.open eyedropper face.dashed face.smiling faxmachine figure.stand figure.walk flashlight.on.fill function gift gift.fill giftcard globe.americas graduationcap hammer hammer.fill hand.point.right hand.thumbsdown hand.thumbsup hand.thumbsup.fill hand.wave hare headphones highlighter increase.indent internaldrive ipad italic ladybug laptopcomputer list.number map map.fill mappin.and.ellipse medal memorychip moon.stars music.note.list newspaper opticaldisc paintbrush paintbrush.fill paragraphsign pawprint pencil.and.outline pencil.line pencil.tip phone phone.circle phone.fill powersleep printer qrcode rays rectangle.and.hand.point.up.left rectangle.compress.vertical rectangle.expand.vertical rectangle.on.rectangle.angled rosette ruler scanner scissors server.rack sidebar.squares.left slider.horizontal.2.square.on.square snowflake sparkles speaker.wave.1 speaker.wave.3 square.and.arrow.up.on.square square.on.circle square.stack square.stack.fill strikethrough sum sun.min text.bubble thermometer togglepower tornado tortoise tray.full trophy umbrella underline wand.and.stars waveform.path wind xmark.shield

## An ordinary image

- `-symbolConfiguration` of an image nobody applied one to is nil, as it is on the host for a bitmap or an empty image.
- `-imageByApplyingSymbolConfiguration:` answers another image of the same bitmap, scale, orientation, animation frames, cap insets, resizing mode, alignment
  insets and rendering mode, whose `symbolConfiguration` is the applied one merged over the image's own, or over the traits alone when it has none; `symbolImage`
  stays NO. Nothing draws by it. With nil it answers the same image when the image has a configuration and a copy without one when it has none, as the host does.
  The host's answer carries the current trait collection, the traits of its idiom, scale, size classes, style, layout direction and content size; the port's is
  `UIScreen.mainScreen.traitCollection`, which has the traits iOS 6 knows, and the applied configuration's own traits win over it in both. A copy loses the flag
  that flips it for a right to left layout, which iOS 6 has no property for.

## UIImageView

`preferredSymbolConfiguration` is nil at first, is kept as given (the object itself, not a copy), is not archived, and setting an equal configuration leaves the first in place. Where a symbol image
is put in the view (`-setImage:` of `UIImageView` is wrapped once, when the library loads) or the configuration changes, the image is drawn again with its own configuration over the preferred one,
and the view's `image` is that drawing; an ordinary image is left as it is. `UIImage.hasBaseline` and `baselineOffsetFromBottom` are carried for the symbols.

## The weight functions

`UIImageSymbolWeightForFontWeight` answers `Unspecified` below the float -0.8, and from there one weight for each float boundary of `UIFontWeight` -
-0.8, -0.6, -0.4, 0, 0.23, 0.3, 0.4, 0.56, 0.62 - the last from 0.62 up, infinity and NaN included; a boundary that is the double 0.4 is below the float 0.4, so
it is Semibold. `UIFontWeightForImageSymbolWeight` is the table the other way with 0 for unspecified: 0, -0.8, -0.6, -0.4, 0, 0.23, 0.3, 0.4, 0.56, 0.62.
For a symbol weight from 10 up both answer 0 as the host does; below zero the host reads the memory beside its table and the port answers 0.
