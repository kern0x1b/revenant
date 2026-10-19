# SKShapeNode (iOS 7, and the points form of iOS 8)

The iOS 7 surface of SpriteKit's `SKShapeNode`: a node that draws a path, with its stroke, fill and line style. The port's
object is `SpriteKit/SpriteKitShape7.m`, declared by `SpriteKit/CharonSpriteKit.h`; the points constructor is in
`SpriteKit/SpriteKit8.m`, since the spec gives it iOS 8. The rows are in `registry/SpriteKit/ios7.json`, `ios8.json` and
`ios10.json`.

## Oracle and what was measured

The oracle is the host's own SpriteKit: macOS 27.0.1 (26A434), arm64. The committed check is
`tests/backports/host/spritekit-shape-label/`: `differential.m` is one runtime-only program built against the host and
against the port's objects (71 lines, identical). The control moves the default stroke width and differs on one line.

## The measured rules

- The defaults: stroke white in the sRGB space; fill clear (sRGB 0, 0, 0, 0); line width 1; glow width 0; miter limit 0.5;
  line cap 0 (butt); line join 2 (bevel); antialiased yes; blend mode 0 (alpha). A shape made with no path has no path.
- The setters store what they are given: the line width (a negative width is stored, measured -4), the glow width, the
  antialiasing flag, the cap, the join, the miter limit and the blend mode (add reads 1).
- The stroke colour is read back in the sRGB space after a set: a device blue set on the host reads back as sRGB blue. The
  fill colour is read the same way. The port converts on set on macOS; the iOS conversion is not measured.
- `shapeNodeWithPath:` keeps the path it is given: the stored path is equal to it (`CGPathEqualToPath`), and setting the path
  to nil reads back nil.
- `shapeNodeWithPath:centered:` with centred NO keeps the path as it is; with YES it shifts the path so that the centre of
  its bounding box is the origin. Measured for a path at the origin: the rectangle (0,0,40,20) becomes (-20,-10,40,20).
- `shapeNodeWithRect:` keeps the rectangle at its own place: (1,2,10,6) gives the bounding box (1,2,10,6), five path
  elements (a move, three lines and a close).
- `shapeNodeWithRectOfSize:` centres the rectangle on the origin: the size (10,6) gives (-5,-3,10,6).
- `shapeNodeWithRect:cornerRadius:` gives the same bounding box as the plain rectangle, with ten path elements. The port's
  corners are quarter arcs of the radius, clamped to half the smaller side; the arcs' control points are not compared.
- `shapeNodeWithRectOfSize:cornerRadius:` centres the rounded rectangle, as the plain form does.
- `shapeNodeWithCircleOfRadius:` gives a circle of bounding box (-r,-r,2r,2r) with six path elements (a move, four curves
  and a close), measured for radius 5.
- `shapeNodeWithEllipseInRect:` gives the ellipse at its own place (measured (1,1,10,4), six elements);
  `shapeNodeWithEllipseOfSize:` centres it (measured (-5,-2,10,4)).
- The points constructor (iOS 8): four points give a closed polyline with the bounding box (0,0,10,10) and five elements;
  one point gives a closed single point (two elements); no points give an empty path (zero elements, bounding box null).
- The spline constructor (iOS 8) is a Catmull-Rom curve through the points, measured element by element with the control
  points (`tests/backports/host/spritekit-shape-label/differential.m`, the lines "spline"). The path is a move to the first
  point, then one curve per point, so n points give n + 1 elements. The sequence of points is the points with the first
  one repeated in front, so the first curve does not move. For the segment from point i to point i + 1 of that sequence,
  the first control point is the start plus a third of the start's tangent, and the second is the end minus a third of
  the end's tangent. The tangent at an index is half the chord between its neighbours, the neighbours clamped at the ends.
  Measured for the square (0,0), (10,0), (10,10), (0,10): the bounding box is (-1.667, -1.667, 13.333, 13.333) and the
  second element's control points are (1.667,0) and (8.333,-1.667). Two points give a first curve that does not move and a
  second that runs to the second point. One point gives one curve that does not move. No points give an empty path.
- The stroke and fill textures (iOS 8) are stored: a texture set reads back as the same object, nil clears it, and setting
  one changes neither the colours nor the other texture (measured). A texture made from a rectangle of half of a 2 by 2
  texture reads size (1, 1), which is the rule of SKTexture. Nothing is drawn yet: the renderer is owed.

## Owed and unmeasured

- `lineLength` is owed. The host reads 0 in every case measured: a shape not yet presented, shapes in a presented SKView
  after 120 frames (the view ran update: 120 times in 2 s, measured), with and without a stroke texture. No non-zero value
  has been found, so the member is not claimed and no formula is written; the condition that makes it non-zero is not known.
- `fillShader` and `strokeShader` (iOS 8) and the attribute members (iOS 10) are owed to the shaders and the attributes.
- Not measured: the iOS colour defaults and the colour conversion on iOS; the exact arc control points of the rounded
  rectangle and the circle (the bounding boxes and element counts are the measured part).

## Device

The path and its style are stored; the stroke and the fill are not drawn yet (the renderer is owed). The iOS 7 object is
compiled for armv7 only.
