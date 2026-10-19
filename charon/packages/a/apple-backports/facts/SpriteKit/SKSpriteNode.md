# SKSpriteNode (iOS 7)

The iOS 7 surface of SpriteKit's `SKSpriteNode`: a sprite made from a colour or a texture, with its size, anchor point,
centre rectangle, colour blend and blend mode. The port's object is `SpriteKit/SpriteKitSprite7.m`, declared by
`SpriteKit/CharonSpriteKit.h`. The rows are in `registry/SpriteKit/ios7.json` (with the owed image and archive
constructors), `ios8.json` (the normal-map, lighting and shader members) and `ios10.json` (scale to size, attributes).

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64. The differential is
`tests/backports/host/spritekit-sprite/differential.m` (42 lines, identical on both sides); `crash.m` holds the crash
cases, one process each. The control moves the default anchor point of the port's sprite and differs on one line.

## The measured rules

- `spriteNodeWithColor:size:` gives a sprite of that size, with the colour given, an anchor point of (0.5, 0.5), a centre
  rectangle of (0, 0, 1, 1), a colour blend factor of 0, the alpha blend mode, and no texture (measured).
- `spriteNodeWithTexture:` gives a sprite of the texture's size, with the colour white with no alpha
  (`NSDeviceRGBColorSpace 1 1 1 0` on the host), a blend factor of 0, and the texture (measured). `spriteNodeWithTexture:size:`
  gives the size given, the same colour, and the texture (measured).
- `spriteNodeWithTexture:nil` gives a zero-size sprite with no texture (measured). With a size, a nil texture gives the size
  given (measured: 3 by 3).
- `initWithTexture:color:size:` gives the texture, colour and size given (measured: a size of (9, 1) and red).
- The setters store what they are given: the colour, the colour blend factor (0.5 reads 0.5), the blend mode (add reads
  1), the anchor point (0, 1 reads (0, 1)), the centre rectangle, and the size. The size setter stores a negative size
  (measured: (-5, 2) reads (-5, 2)).
- Setting the texture on a colour sprite leaves its size and colour; clearing it does too (measured: a size of 5 by 5
  stays 5 by 5 through both).

## Crash cases (host, one process each; crash.m and run.sh)

The host raises `NSInvalidArgumentException` for a negative width or height in the initialisers and in
`spriteNodeWithTexture:size:`. The reasons differ by the path (measured):

- `spriteNodeWithColor:size:` with (-2, 3): `Invalid size specified: {-2, 3}`.
- `initWithColor:size:` with (0, -4): `Invalid size specified: {0, -4}`.
- `initWithTexture:color:size:` with (2, -2): `Invalid size specified: {2, -2}`.
- `spriteNodeWithTexture:size:` with (-1, 1): `Invalid bounds specified: {-1, 1}`; with (0, -3): `Invalid bounds
  specified: {0, -3}`.

The port raises the same exception name and reason in each of those paths.

## Owed and unmeasured

- The image constructors (`spriteNodeWithImageNamed:`, `initWithImageNamed:`): owed to the image loader.
- The archive (`initWithCoder:`): owed with the archive of the node tree.
- The normal-map members (`normalTexture`, `spriteNodeWithTexture:normalMap:`, `spriteNodeWithImageNamed:normalMapped:`), the
  bit masks, and `shader`: owed to iOS 8 and the lighting and shader steps. The spec row of `spriteNodeWithTexture:normalMap:`
  carries no availability; it is owed to the iOS 8 object, and the iOS 7 claim is not made.
- `scaleToSize:`, `attributeValues` and the attribute methods: iOS 10, owed.
- Not measured: the rendering of any of these sprites, and the colour of a texture sprite on iOS (the host's white with no
  alpha is the port's value; the iOS value is not measured on a device).

## Device

The sprite draws nothing: its colour and texture are carried for the renderer, which is owed. The iOS 7 object is compiled
for armv7 only.
