# SKScene (iOS 7 and 8), SKEffectNode and SKView

The iOS 7 surface of SpriteKit's `SKScene`, the `SKEffectNode` it derives from (its own file is SpriteKitEffect7.m), and `SKView` that presents a scene, plus
the iOS 8 delegate and hooks of the scene. The port's objects are `SpriteKit/SpriteKitScene7.m` (SKScene,
and SKNode's `scene`), `SpriteKit/SpriteKitScene8.m` (the delegate and the two hooks), and `SpriteKit/SpriteKitView7.m`
(SKView, iOS only). They are declared by `SpriteKit/RevenantSpriteKit.h`. The rows are in `registry/SpriteKit/ios7.json`,
`ios8.json`, `ios9.json` and `ios10.json`.

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64. The committed check is
`tests/backports/host/spritekit-scene/`: `differential.m` is one runtime-only program built against the host framework and
against the port's objects (SpriteKit7, 8 and 9, SpriteKitScene7 and 8), and the stdout of the two runs is compared line
by line. The framework's refusals (NSLog, on stderr) are compared with their timestamp removed. The control reverses the
sign of the anchor in the frame; it differs on four lines. The run passes with 36 lines identical and two refusals
identical. The SKView is iOS only and is not part of the host differential: it is compiled for armv7 by the gate.

The measured rules:

- `sceneWithSize:` gives a scene of that size. Its scale mode is Fill (0), its anchor point is (0,0), its name is nil, it
  has no children, its delegate is nil, and `scene` answers the scene itself.
- The background colour of a new scene is `RGB(0.15, 0.15, 0.15, 1)` on macOS. The iOS value is not measured on a device;
  the port uses the same components.
- `init` gives a scene of size (1,1).
- The frame is `(-anchor.x * width, -anchor.y * height, width, height)`. Anchor (0.5, 0.25) on 100 by 50 gives
  `(-50, -12.5, 100, 50)`; with the anchor at zero the origin is `-0`, which is the same value.
- Setting the size calls `didChangeSize:` with the size the scene had before, and it does so even when the size does
  not change. `sceneWithSize:` calls it once from the initialiser, with the initial size as the old one.
- Setting the position of a scene has no effect: the host logs `SKScene: Setting the position of a SKScene has no
  effect.` and the position stays at (0,0). The same holds for `xScale`, `yScale` and `setScale:` (each logs `SKScene:
  Setting the scale of a SKScene has no effect.`), for `zRotation` and for `zPosition` (each logs the same form with its
  own name). Measured on the host: the scales stay 1, the rotation and depth stay 0.
- `alpha`, `hidden` and `speed` are stored as set (measured: 0.25, YES, 2).
- `scaleMode` and `anchorPoint` store what they are given (a scale mode of 3 reads back 3).
- A child in a scene has the scene from `scene`, and a grandchild has it through its parent. A node removed from the
  scene has no scene. A plain node outside any scene answers nil.
- The delegate is weak: once the delegate object is released, `delegate` reads nil.
- The scene answers `didApplyConstraints` and `didFinishUpdate` (iOS 8), and `update:`, `didEvaluateActions` and
  `didSimulatePhysics` (iOS 7).

## Ordering of the frame

The host's frame order is not measured. SKView has no public step that runs a frame in a test, so the order the port
uses is the documented one: `update:`, the delegate's `update:forScene:`, `didEvaluateActions`, `didSimulatePhysics`, the
constraints, and `didFinishUpdate`, with each delegate call after its scene method. The port calls the iOS 8 hooks and
the delegate only where the scene answers them, since a release below 8 has none of them.

## Owed and unmeasured

- The physics world: the host gives every scene a non-nil `physicsWorld` (measured). The port has no physics until
  step 4, so the property is an owed row.
- `camera`, `listener` and `audioEngine` (iOS 9): owed with the camera, the audio and the rendering.
- `sceneDidLoad` (iOS 10): owed with the file loader.
- `convertPointFromView:` and `convertPointToView:`, and the view's `convertPoint:toScene:` and `convertPoint:fromScene:`:
  owed, since they go through the scale mode, which is owed to the rendering step.
- The view's `textureFromNode:` and its crop form: owed to the textures (step 2).
- `presentScene:transition:` and `SKTransition`: owed with the actions.
- The SKView's overlays (`showsFPS`, `showsDrawCount`, `showsNodeCount`) are stored and draw nothing; `showsPhysics`,
  `showsFields`, `showsQuadCount`, `allowsTransparency` and `shouldCullNonVisibleNodes` (iOS 8) are owed rows.
- The scale mode's mapping of the scene into the view is owed to the rendering step: the port stores the mode.
- Unmeasured: the scene's frame when it has a non-zero position (the host refuses positions, so only the anchor moves
  it); the background colour on iOS; the frame order.

## Device

The SKView is device-unverified. It is compiled for `armv7-apple-ios6.1.3` with `-Wall -Wextra -Werror` against the 26.2
SDK, and the gate compiles it with the rest of the library. It is not run on any device: the CAEAGLLayer, the OpenGL ES 2
framebuffer and the display link have not been exercised on an iOS 6 device. The scene's logic is run on the host (the
differential above); the view's clearing to the background colour is the one thing the view does with a scene that a
device run would show.
