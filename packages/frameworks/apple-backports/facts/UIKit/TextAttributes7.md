# What the release draws of the text attributes of iOS 7

The attribute names of iOS 7 that the port defines (`NSAttributedStringText.md`) are strings the release's text system already reads, for the
most part: UIFoundation of iOS 6 is the Mac's, and these are Mac attributes. The port used to record all six as read and not drawn; a
measurement says otherwise for four.

Source: the host's own UIKit under Mac Catalyst (`host/textattr/run.sh`): the string "Hello, World" in Courier 20 drawn plainly and with each attribute, three ways
- `-drawAtPoint:`, a `UILabel` rendered into a bitmap, and an `NSLayoutManager` drawing its glyphs - and each picture measured: the pixels of the
attribute's own colour, the width and height of the ink and its top and bottom against the plain drawing, how far the top half leans from the
bottom half, the centre of the ink; the text `iiiiiiiiWWWW` for the writing direction. `device/textattr.m` draws the same on iOS 6 and compares
(the counts of coloured pixels to a third, the geometry to three pixels).

## Drawn by the release, so `implemented`

- `NSUnderlineColorAttributeName` and `NSStrikethroughColorAttributeName`: the line is drawn in the colour (272 red pixels of the underline on
  the device, 276 on the host; 286 blue and 290 for the strikethrough), in all three ways.
- `NSExpansionAttributeName`: the glyphs are spaced by that fraction of the font size (the ink is 93 pixels wider on the device, 92 on the host).
- `NSWritingDirectionAttributeName`: an override reverses Latin text, and the centre of the ink moves as the host's does.
- `NSObliquenessAttributeName`: the glyphs are skewed - the ink is 3, 11 and 6 pixels wider than the plain one at 0.4, 1.0 and -0.5 on the device, and 3, 10 and 5 on the host. (How far the top of the ink leans from its bottom, measured from the pixels, differs between the two renderers and is not compared.)
- `NSKernAttributeName`, `NSStrokeWidthAttributeName` with its colour and `NSBaselineOffsetAttributeName` (in a label) agree as well; they are not new.

## Not drawn, so `inert`

- `NSTextEffectAttributeName` with the letterpress style: the text is drawn plainly, in all three ways; the host draws the effect (white text with its shadows).

The test holds this one to what the release does: the picture is the plain one.
