# ARSession, ARFrame, ARCamera, and the anchors

What a session is: a camera, a gyroscope and a tracker, handing the application one frame at a
time. `ARSession.m`, `ARFrame.m` and `ARAnchor.m`.

## The run loop

`ARSession` owns the release's own `AVCaptureVideoDataOutput` and `CMMotionManager` — both measured
present in the armv7 shared cache of iOS 6.1.3, the first with 26 instance methods and the second
with 74 — and asks the tracker for a pose per frame. Delegate calls are made on
`delegateQueue` when the caller named one and on the main queue when it did not, which is what the
SDK's header says.

`run(_:options:)` behaves as the header says: a session already running transitions to the new
configuration, `ARSessionRunOptionResetTracking` restarts the tracker, and
`ARSessionRunOptionRemoveExistingAnchors` drops the anchors. `ARSessionRunOptionResetSceneReconstruction`
is accepted and does nothing, because there is no scene reconstruction here to reset: there is no
depth sensor to reconstruct a scene from.

A session run with a configuration whose `+isSupported` is NO **does not start**. The application is
told through `session:didFailWithError:`, with the reason the hardware gave, rather than being
allowed to run a session that could never track.

## Frames

`ARFrame` carries the camera's transform and the device's transform, the time each was true, the
image size, the light estimate, the anchors that were in the world, and what a frame does **not**
have:

- `capturedDepthData` answers an empty dictionary. A depth photograph is a depth sensor's output and
  this device has none; an empty dictionary is the contract's own answer for a frame without one.
- `hasCapturedDepthData` and `hasDisplayGeometry` answer NO, for the same reason.
- `update(withDictionary:)` answers NO: a frame from another run cannot be applied to this one.
- `worldMappingStatus` answers the framework's "not available" until a world map is added.

`ARCamera` reports the pose, the image size, the light estimate read from the frame, the focal
length from the image size, the tracking state, and `hasDepth` NO — again because there is no depth
sensor behind it.

## Anchors

An `ARAnchor` is a name, a transform and nothing else, so an anchor an application adds survives
into every frame at the pose it was added at, and is found again by its identifier. `ARAnchor` is
`NSObject` with a copy and a `isEqualToAnchor:` that compares the identifier and the transform, and
`ARAnchorCopying` is carried with it.

`ARPlaneAnchor` and `ARPlaneGeometry` are the detector's output, and they are **detections**: a
detected plane has a centre, an extent, an alignment that says what the detector found, and **no
vertex, texture-coordinate or triangle-index arrays**, because there is no mesh to give. See
`ARKit.md`.

`ARPointCloud` gives its points as `NSData` of three floats each and answers NO for
`identifier:atIndex:`, because a monocular system has no stable point indices to give back.

## Hit test and raycast

Both go against the planes the detector found, and both are in `ARAnchor.m`. A hit test prefers a
tracked feature within five centimetres of the ray and otherwise reports a plane; a raycast
substitutes into the plane equations and keeps the nearest. `ARRaycastQuery` is in the SDK's own
spelling — a world `origin`, a world `direction`, a `target` and an `alignment` — and
`ARTrackedRaycast` keeps its result, stopping in Apple's own rule: it stops being reported once the
camera has moved further than the ray's own length, because past that the result no longer describes
this frame.

`ARSessionDelegate` and `ARSessionObserver` are carried: the frame and anchor callbacks, and the
session's own state changes, which the tracker raises as it starts and stops. `ARTrackable` is
carried with them — an anchor that follows a thing in the world is what an anchor added at a pose
does here.

## Frames, orientation, and the world map

Frames. A world session starts the release's own `AVCaptureVideoDataOutput` and its `AVCaptureSession`, with the tracker as
the sample-buffer delegate on a queue of its own. Each camera frame is processed with the attitude the gyroscope last
reported, and the tracker then calls the session, which hands the application a frame (`session:didUpdateFrame:`) and makes
it the session's `currentFrame`. Before this, the session started no capture: no frame reached the tracker, so no frame
was delivered.

Orientation. `AROrientationTrackingConfiguration` starts the gyroscope alone (`CMMotionManager`'s device motion, in the
arbitrary-yaw, z-vertical reference frame, which is the tracker's own world convention: gravity is along -z). Each motion
update is a frame whose camera pose is the device's attitude, with the position at the origin and no picture (the image
resolution is empty). Its `+isSupported` asks `deviceMotionAvailable` on a `CMMotionManager` instance; before this it
called `isAvailable` on the class, which the class does not answer.

World map. `getCurrentWorldMapWithCompletionHandler:` returns the anchors, the feature points and the tracker's own world
(`worldState`). `initialWorldMap` on the world and positional configurations is restored into the tracker before the
camera starts. Not a relocalisation: see `facts/ARKit/ConfigurationSettings.md`.

Verification. The emulator has no camera and no gyroscope, so on it a world session and an orientation session are
refused (`session:didFailWithError:`) when their `+isSupported` is NO, and the probe in `tests/backports/device/arkit-config`
checks that answer. The camera frames and the gyroscope's attitude are not measured on this device by that probe; they
are measured on a device, and until that run is recorded here the frame path is built and unverified on hardware.
