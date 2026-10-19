# SKLabelNode (iOS 7)

The iOS 7 surface of SpriteKit's `SKLabelNode`: a text in a font, with its colour, alignment and line layout. The port's
object is `SpriteKit/SpriteKitLabel7.m`, declared by `SpriteKit/CharonSpriteKit.h`. The rows are in `registry/SpriteKit/`
`ios7.json`, and the attributed text is in `ios11.json`.

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64. The label is in the same differential as the shape
node: `tests/backports/host/spritekit-shape-label/differential.m`, which prints the label's values line by line (identical
on the host and the port).

## The measured rules

- `labelNodeWithText:` gives a label with the text given, in the host's default font `HelveticaNeue-UltraLight`, at size 32,
  with the font colour white in the sRGB space and the colour white in the device space (`NSDeviceRGBColorSpace 1 1 1 1`),
  colour blend factor 0, blend mode 0 (alpha), centred horizontally (0), on the baseline vertically (0), one line (1), truncating
  at the tail (lineBreakMode 4), and a preferred width of 0.
- `labelNodeWithFontNamed:` and `initWithFontNamed:` give a label in the font named, with no text (nil).
- The text is stored, and setting it to nil reads back nil.
- The font size, the font colour, the alignments (left reads 1, top reads 2), the number of lines (3) and the preferred
  width (99) are stored as set.
- The font colour is read back in the sRGB space after a set: a device red set on the host reads back as sRGB red. The port
  converts on set on macOS; the iOS conversion is not measured.
- The attributed text of a new label is nil. It is an iOS 11 member (the spec gives it `ios=11.0`) and is owed.

## Owed and unmeasured

- The rasterised text: the glyphs, their layout and their size are the renderer's and are owed. Nothing is drawn.
- `labelNodeWithAttributedText:` and `attributedText` (iOS 11): owed to the text layout (registry/SpriteKit/ios11.json).
- The iOS default font: the host's `HelveticaNeue-UltraLight` is the port's default (measured on macOS only); the device
  default is not measured.

## Device

The label stores its text and its members; it draws nothing yet. The iOS 7 object is compiled for armv7 only.
