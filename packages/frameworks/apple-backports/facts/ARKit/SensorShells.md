# The sensor-data classes: carried whole, and never produced on this device

Six classes of ARKit whose instances need a sensor the iPhone 4S does not have: a depth sensor
(`ARDepthData`, `AREnvironmentProbeAnchor` and `ARMeshAnchor` are read out of depth or a scene
reconstruction built on it), a face the TrueDepth camera measures (`ARFaceAnchor`), an object scanned
out of a depth mesh (`ARObjectAnchor`), and a directional light the port does not estimate
(`ARDirectionalLightEstimate`). Each class is carried as an `@implementation` in its own file, with its
properties synthesised, so that a name the SDK declares resolves at load time and a `respondsToSelector:`
or a cast answers the way the release's does. None of them is ever produced by a session of this port,
for the reasons below; the class is the API, and the instances it would describe are the sensor's.

## What the SDK declares

Read from `spec/ARKit/declarations.tsv`, the generator's output over the iPhoneOS 26.2 SDK (libclang):

| class | superclass | availability | members the port carries | line range |
| --- | --- | --- | --- | --- |
| `ARDepthData` | `NSObject` | ios=14.0 | `depthMap`, `confidenceMap` (`CVPixelBufferRef`) | 7-10 |
| `ARFaceAnchor` | `ARAnchor <ARTrackable>` | ios=11.0 | `geometry`, `blendShapes`, `leftEyeTransform`, `rightEyeTransform`, `lookAtPoint` | 419-426 |
| `AREnvironmentProbeAnchor` | `ARAnchor` | ios=12.0 | `environmentTexture`, `extent`, `initWithTransform:extent:`, `initWithName:transform:extent:` | 337-342 |
| `ARMeshAnchor` | `ARAnchor` | ios=13.4 | `geometry` | 555-557 |
| `ARObjectAnchor` | `ARAnchor` | ios=12.0 | `referenceObject` | 604-606 |
| `ARDirectionalLightEstimate` | `ARLightEstimate` | ios=11.0 | `sphericalHarmonicsCoefficients`, `primaryLightDirection`, `primaryLightIntensity` | 539-543 |

The `introduced` values in `registry/ARKit/ios11.json` were written by hand before this file, and three
of them disagreed with the SDK: `ARDepthData` (11.0 written, 14.0 declared), `ARMeshAnchor` (13.0, 13.4),
`AREnvironmentProbeAnchor` (13.0, 12.0) and `ARObjectAnchor` (11.0, 12.0). The rows carry the declared
values now. The class-level `ARFaceAnchor` and `ARDirectionalLightEstimate` rows agree.

The anchor subclasses declare their `initWithTransform:` and `initWithName:transform:` as
`NS_UNAVAILABLE` (`*unavailable` in the spec: lines 427-428, 558-559, 607-608). `AREnvironmentProbeAnchor`
is the exception: its two initialisers with an `extent` are available from 12.0 (lines 341-342), and they
are implemented here. `ARDepthData` declares no initialiser of its own.

`ARFaceAnchor` is declared at 11.0, but three of its members are declared at 12.0: `leftEyeTransform`,
`rightEyeTransform` and `lookAtPoint` (spec lines 423-425). They are carried in `ARKit/ARFaceAnchor.m`,
which is an 11.0 file, and they have no registry rows. The symbol check in `release-split` sees the class
symbols and not these methods, so it does not check their release; the release is recorded here and
nowhere else.

## Why no session produces them on this device

- **The face classes**: `ARFaceTrackingConfiguration`'s `+isSupported` answers NO in
  `ARKit/ARConfiguration2.m`, so a session never runs face tracking and never reports an `ARFaceAnchor`.
  The port has no face path in `ARKit/RevenantARTracker.h`: the tracker reports features, planes and the
  camera pose.
- **The depth classes**: `-[ARFrame hasCapturedDepthData]` returns NO (`ARKit/ARFrame.m:402`), and
  `ARFrame.sceneDepth` is not carried, so no frame holds an `ARDepthData`.
- **The mesh and the probe**: a mesh is built from scene depth, and an environment texture is rendered
  from the camera's view of the room. The tracker produces neither.
- **The object anchor**: `+[ARObjectScanningConfiguration isSupported]` answers NO in
  `ARKit/ARConfiguration3.m`, and no session matches a reference object (`detectionObjects` is owed).
- **The directional light**: `ARFrame.m` builds the ambient `ARLightEstimate` from two fixed values and
  computes no direction. `facts/ARKit/ARKit.md` has the measurement.

## What each class does

- `ARFaceAnchor`, `ARMeshAnchor`, `ARObjectAnchor`, `ARDepthData`, `ARDirectionalLightEstimate`: the
  members are the synthesised accessors of the instance variables the SDK names, and they answer what a
  session would have put in them. Since no session makes one, the answer is nil or a zero value, and
  nothing in the port reads a value back in.
- `AREnvironmentProbeAnchor`: the two `extent` initialisers store the extent and hand the place to the
  anchor's own initialiser. `environmentTexture` stays nil, because nothing renders one. A caller that
  reads the extent back gets what it wrote.

## What is not measured

- The release's own answer for `-init` on these classes. The header marks it unavailable; the
  `ARConfiguration.m` note records that the release defines an `-init` the header marks unavailable, so
  the port does not refuse it. What the release answers for these six classes was not measured on a
  device or a cache, and the registry rows do not claim it.
- Nothing here is a host differential. ARKit is not on macOS, so there is no host oracle; the tests in
  `tests/backports/host/arkit-sensorshells` check the class shape, the extent round trip and the
  superclass chain against the port's own sources.
