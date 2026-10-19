# The stored settings of the world and body configurations, and the body answer

The configurations' settings are the properties a caller sets before it runs a session: whether the HDR environment
texture is wanted, whether a scene is reconstructed, whether App Clip codes are read, and so on. The release stores
each one; what a session does with it is a separate matter, and the registry rows say what this port does.

## The settings, and what the host answers

Measured on Mac Catalyst ARKit (the iOSSupport copy in the macOS SDK), with `alloc` and `init` of each configuration,
read and then set (a scratch probe, not in the tree):

| setting | default on a fresh configuration | after a set | port |
| --- | --- | --- | --- |
| `ARWorldTrackingConfiguration.sceneReconstruction` | 0 (none) | mesh (1) reads back 1 | stored, `ARConfiguration2.m` |
| `ARWorldTrackingConfiguration.wantsHDREnvironmentTextures` | NO | YES reads back YES | stored |
| `ARWorldTrackingConfiguration.userFaceTrackingEnabled` | NO | stored | stored |
| `ARWorldTrackingConfiguration.collaborationEnabled` | NO | YES reads back YES | stored |
| `ARWorldTrackingConfiguration.appClipCodeTrackingEnabled` | NO | stored | stored |
| `ARWorldTrackingConfiguration.automaticImageScaleEstimationEnabled` | NO | NO reads back NO | stored |
| `ARWorldTrackingConfiguration.detectionObjects` | nil | a mutable set given, then changed: the configuration keeps a copy (count 0) | stored as a copy |
| `ARBodyTrackingConfiguration.wantsHDREnvironmentTextures` | NO | stored | stored, `ARConfiguration4.m` |
| `ARBodyTrackingConfiguration.appClipCodeTrackingEnabled` | NO | stored | stored |
| `ARBodyTrackingConfiguration.automaticImageScaleEstimationEnabled` | NO | stored | stored |
| `ARBodyTrackingConfiguration.automaticSkeletonScaleEstimationEnabled` | NO | NO reads back NO | stored |

The support answers the host gives are NO for every configuration (`isSupported`, and `supportsSceneReconstruction:`,
`supportsUserFaceTracking`, `supportsAppClipCodeTracking`): the host is a Mac, with no camera-and-gyroscope tracking of
the kind an iPhone runs, so these answers say nothing about the iPhone 4S and are not the port's oracle. The port's own
answers come from its tracker (`CharonARTracker.m`) and from the sensors it has.

The defaults are the host's, and a release's defaults are not assumed to differ from them. The port's tests check the
defaults and the round trip on the 4S under 6.1.3, in `tests/backports/device/arkit-config`.

## What a session does with them

Nothing, and the registry says so per row. The tracker builds no mesh, reads no face, takes no collaboration, reads no
App Clip code, matches no reference object, estimates no image scale and no skeleton scale, and renders no HDR
environment texture. A stored setting is therefore the caller's own value read back, and no session acts on it.

## The body answer

`ARBodyTrackingConfiguration +isSupported` is NO. The release estimates a body from the frames with a neural
network. This port builds no estimator, so a session of the configuration would run and never report a body, which
is a fake of the kind the registry forbids. The answer was YES while the port's sessions could not produce a body:
it answered what the front camera gave, not what the port supports. Apple documents body tracking as needing an
A12 chip or later; this device is an A5. That requirement is the documented one and was not measured (the host is a
Mac). A session started with the configuration is refused, through `session:didFailWithError:`, as
`facts/ARKit/ARSession.md` describes for every NO answer.

This NO is the state of the port now, and it is not the end state. The body pose estimator is being built by the
v-impl-vision-models band. When it lands, `ARBodyTrackingConfiguration` is built on that estimator: a session runs the
estimator over the tracker's frames and reports `ARBodyAnchor`s with their skeletons, and `+isSupported` answers from
that estimator's own availability on this device, measured the way the other answers are, and not from a constant.
Until then the body rows stay as they are, and this file is the place that says so.

## The map a configuration starts from

`initialWorldMap` is stored on the world and positional configurations, and a session that starts with one restores the
tracker's world from it before the camera starts (`ARSession.m`, `runWithConfiguration:options:`). The map is an
archive of the tracker's own state, `CharonARTracker`'s `worldState`: the points it has placed, with their positions in
the world, their identifiers, their ages and hits, and the planes the detector found in them, as bytes written
field by field and little-endian, so an archive made on one build reads on another. The anchors the map was saved
with are carried in after the run options have had their say, so they are the world the session starts with.

What a restore is not: a relocalisation. The tracker does not match the live frames against the restored points, so
the restored world is placed from the pose the device has when the session starts, and it is coherent with the room
only where the device stands when the session starts. The archive holds what the tracker had; the tracker does not
yet find itself in it. That is the gap this file names, and the registry rows say the same.

`ARSessionRunOptionResetTracking` starts the tracker again, and that discards the restored world, as it discards every
world. The body configuration's `initialWorldMap` is not stored: a body map comes from the body estimator
(below), which this port does not build.

## Not carried

- The body configuration's `initialWorldMap` (`@dynamic`) is owed with the body estimator, which this port does not
  build. `respondsToSelector:` answers NO for it, and a call raises, which is why it is a crutch and is logged in
  `coordination/crutches.md`.
- `-[ARGeoTrackingConfiguration init]` is owed; the geo configuration itself is not carried.
- The body pose estimator is being built by the v-impl-vision-models band. When it lands, `ARBodyTrackingConfiguration`
  is built on that estimator, its session reports `ARBodyAnchor`s with their skeletons, `+isSupported` answers from the
  estimator's own availability on this device, measured the way the other answers are, and the body rows and this file
  change together. Until then the NO answer above stands.
