# SKEffectNode (iOS 7)

The iOS 7 surface of SpriteKit's `SKEffectNode`: a node that draws its children through a filter, and the superclass of
`SKScene`. The port's object is `SpriteKit/SpriteKitEffect7.m`, declared by `SpriteKit/RevenantSpriteKit.h`. The rows are in
`registry/SpriteKit/ios7.json` (with the shader owed) and `ios10.json` (the attributes, owed).

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64. The check is in
`tests/backports/host/spritekit-shape-label/differential.m`, which uses a real `CIFilter` (the Gaussian blur, from CoreImage,
linked on both sides) for the filter.

## The measured rules

- A new effect node has no filter (nil), centres the filter (yes), enables its effects (yes), does not rasterise (no), and has
  the alpha blend mode (0).
- The flags are stored as set: rasterisation to yes, effects to no, and the centring stays yes.
- The filter is stored and read back as the same object.

## Owed and unmeasured

- The effect itself: the children are not run through the filter or the rasterisation yet. That is the renderer's and the
  effects step, which is owed.
- `shader` (SKShader, owed with the shader step), and the attribute members of iOS 10 (owed with SKAttribute).
- Not measured: the effect's output for any filter.

## Device

The effect node stores its filter and flags; it runs nothing yet. The iOS 7 object is compiled for armv7 only.
