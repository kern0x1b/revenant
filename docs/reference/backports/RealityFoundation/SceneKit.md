# RealityFoundation and RealityKit below iOS 8.0

Both overlays are not yet backported below iOS 8.0. Their packages refuse on load at a lower deployment target, rather than link an image that loads a framework the release lacks; the open gap is listed in [the Backports README](../../../../frameworks/Backports/README.md).

## What was measured

- Both libraries load SceneKit.framework: libswiftRealityFoundation imports 13 symbols of it and libswiftRealityKit 3
  (SCNGeometry, SCNGeometryElement, SCNGeometrySource, SCNMaterial, SCNNode, SCNScene, three semantics constants, three
  lighting models, SCNMatrix4Identity, SCNHitTestResult, SCNView).
- A byte search of the armv7 dyld caches this tree holds finds no SceneKit in those of iOS 6.1.3, 7.0 and 7.1.2, and
  finds it in those of 8.0 and 8.1. `dyld.check` refuses an install whose library loads an image the release lacks.
- The backports' SceneKit (the SceneKitBackports target, libSceneKitBackports.dylib) exports the classes and
  constants above except SCNHitTestResult, and has no -[SCNView hitTest:options:]
  (`grep -rn "hitTest:options" frameworks/Backports/src/SceneKit` finds nothing; its only mention of the type is the
  return type of a physics ray test in SCNPhysicsWorld.m). RealityKit's ARView asks that hit test for every gesture on
  an entity (files/RealityKit/ARView.swift, gestureRecognizerShouldBegin), so a link ahead of SceneKit would load and
  then answer no gesture. It also uses +[SCNNode nodeWithGeometry:], which the backport lacks
  (files/RealityFoundation/SceneKitBridge.swift, SCNNode(geometry:)).

## What brings it back

A registry row and an implementation for SCNHitTestResult and -[SCNView hitTest:options:] (and
+[SCNNode nodeWithGeometry:]) in the Backports' SceneKit, then the overlays linked ahead of the framework with a weak
load of it.
