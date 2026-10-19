# SKCropNode (iOS 7)

The iOS 7 surface of SpriteKit's `SKCropNode`: a node whose children show where its mask node has content. The port's
object is `SpriteKit/SpriteKitCrop7.m`, declared by `SpriteKit/RevenantSpriteKit.h`. The row is in `registry/SpriteKit/ios7.json`.

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64. The check is in
`tests/backports/host/spritekit-shape-label/differential.m`.

## The measured rules

- A new crop node has no mask node (nil).
- The mask node is stored and read back as the same object (measured with a white sprite of size 4 by 4).

## Owed and unmeasured

- The crop itself: the children are not clipped to the mask yet. The mask is the renderer's, which is owed.
- The mask's own drawing is the renderer's too; the port keeps the node as the mask and draws nothing.

## Device

The crop node stores its mask. It clips nothing yet. The iOS 7 object is compiled for armv7 only.
