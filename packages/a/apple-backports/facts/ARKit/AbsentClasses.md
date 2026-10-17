# The data and skeleton classes: carried, and never produced on this device

Thirteen classes of ARKit whose instances describe a body, a skeleton, a scene mesh, a face mesh, a scanned object,
a matte or a collaboration, and which only a sensor or a tracking configuration this port does not run would
produce: `ARBody2D`, `ARSkeleton`, `ARSkeleton2D`, `ARSkeleton3D`, `ARCollaborationData`, `ARMatteGenerator`,
`ARGeometryElement`, `ARGeometrySource`, `ARGeoTrackingStatus`, `ARMeshGeometry`, `ARFaceGeometry`,
`ARSCNFaceGeometry` and `ARReferenceObject`. Each is carried as an
`@implementation` in its own file, so the name resolves at load time and a `respondsToSelector:` or a cast answers
as the release's does. The members the SDK declares are the synthesised accessors of their instance variables,
and they answer what a fresh object answers on the host: nil or zero. No session of this port makes any of them,
for the reasons below. What is not carried is listed per class, and nothing here is a silent stand-in for it.

## What the SDK declares

From `spec/ARKit/declarations.tsv`, the generator's output over the iOS 26.2 SDK:

| class | superclass | declared | members carried | not carried |
| --- | --- | --- | --- | --- |
| `ARBody2D` | `NSObject` | 13.0 | `skeleton` | none |
| `ARSkeleton` | `NSObject` | 13.0 | `definition`, `jointCount` | `isJointTracked:` |
| `ARSkeleton2D` | `ARSkeleton` | 13.0 | `jointLandmarks` | `landmarkForJointNamed:` |
| `ARSkeleton3D` | `ARSkeleton` | 13.0 | `jointModelTransforms`, `jointLocalTransforms` | `modelTransformForJointName:`, `localTransformForJointName:` |
| `ARCollaborationData` | `NSObject` | 13.0 | `priority` | none |
| `ARMatteGenerator` | `NSObject` | 13.0 | none | `initWithDevice:matteResolution:`, `generateMatteFromFrame:commandBuffer:`, `generateDilatedDepthFromFrame:commandBuffer:` |
| `ARGeometryElement` | `NSObject` | 13.4 | `buffer`, `count`, `bytesPerIndex`, `indexCountPerPrimitive`, `primitiveType` | none |
| `ARGeometrySource` | `NSObject` | 13.4 | `buffer`, `count`, `format`, `componentsPerVector`, `offset`, `stride` | none |
| `ARMeshGeometry` | `NSObject` | 13.4 | `vertices`, `normals`, `faces`, `classification` | none |
| `ARGeoTrackingStatus` | `NSObject` | 14.0 | `state`, `accuracy`, `stateReason` | none |
| `ARFaceGeometry` | `NSObject` | 11.0 | `vertexCount`, `vertices`, `textureCoordinateCount`, `textureCoordinates`, `triangleCount`, `triangleIndices` | `initWithBlendShapes:` |
| `ARSCNFaceGeometry` | `SCNGeometry` | 11.0 | none | `faceGeometryWithDevice:`, `faceGeometryWithDevice:fillMesh:`, `updateFromFaceGeometry:` |
| `ARReferenceObject` | `NSObject` | 12.0 | `name`, `center`, `extent`, `scale`, `resourceGroupName`, `rawFeaturePoints` | `referenceObjectsInGroupNamed:bundle:`, `initWithArchiveURL:error:`, `exportObjectToURL:previewImage:error:`, `referenceObjectByApplyingTransform:`, `referenceObjectByMergingObject:error:` |

The declared release is the SDK's `ios=` availability of the class (the `interface` row), and it is the one the
registry rows carry. `ARMeshGeometry` was written as 13.0 in `registry/ARKit/ios11.json`; the SDK says 13.4 and the
row now says 13.4.

The SDK declares `-init` and `+new` `NS_UNAVAILABLE` on every class above (`*unavailable` in the spec). On the host
each answers the superclass's own IMP and defines none, measured in `facts/ARKit/NSObjectInit.md`, and the port
gives the same answer because it defines none.

## Why no session produces them on this device

- **The face and scene meshes**: `ARFaceGeometry` is measured across a face by the TrueDepth camera, and
  `ARFaceTrackingConfiguration.isSupported` is NO (`ARKit/ARConfiguration2.m`). A scene mesh is reconstructed from
  scene depth, which this device does not have (`ARKit/ARMeshAnchor.m`). `ARSCNFaceGeometry` is drawn from an
  `ARFaceGeometry`, so it is not produced either.
- **The scanned object**: `ARReferenceObject` is written by a scan that reads a mesh out of depth, and
  `ARObjectScanningConfiguration.isSupported` is NO (`ARKit/ARConfiguration3.m`).
- **The body**: `ARBody2D`, `ARSkeleton`, `ARSkeleton2D` and `ARSkeleton3D` are what body tracking reports, and this
  port builds no body estimator. No session of this port reports a body or a skeleton, whatever
  `ARBodyTrackingConfiguration.isSupported` answers (`ARKit/ARConfiguration4.m`). The skeleton definition is carried
  separately, and its table is measured (`facts/ARKit/Skeleton.md`).
- **The matte**: `ARMatteGenerator` is a person segmentation the port does not compute.
- **The collaboration data**: a collaborating session is not run (`ARWorldTrackingConfiguration.collaborationEnabled`
  is owed in `registry/ARKit/ios13configurations.json`).
- **The geo status**: a geo-tracking session reports one, and this port runs none, because its configuration is
  not supported on this device (the geo section below).

## Measured on the host

`tests/backports/host/arkit-absent-classes/run.sh` compiles each port file with its class renamed and compares it
with the host's own class. Measured facts it rests on:

- `ARGeometryElement.indexCountPerPrimitive` is derived from `primitiveType`, not stored. The host answers 2 for
  a line (type 0, the type of a fresh element) and 3 for a triangle (type 1). The type is read-only with no public
  setter, so the probe set it through key-value coding on the type's ivar and read the getter; the port derives the
  count the same way, and the test checks both answers on both sides. A value the enum does not name is not reachable
  from a caller and was not measured; the port answers 0 for it.
- A fresh object of each class answers nil or zero for every object or scalar property, on the host and on the port
  (the test checks each one). Pointer and struct properties (`vertices`, `jointLandmarks`, the transform arrays,
  `center`, `extent`, `scale`) are not read as values, because `valueForKey:` raises for them; the test prints them as
  `skip` lines, and it checks that the port declares each one with the host's type.
- The host's runtime records the framework's own implementation declaration, which can differ from the header: the
  host's `ARMeshGeometry` properties are writable at runtime where the header says readonly. So the test compares
  property types, not the readonly or copy flags.
- The host's ARKit (macOS) has members the iOS SDK does not declare, such as `ARReferenceObject.identifier`. The
  test checks presence of the iOS SDK's names only.

Controls: two different classes differ in their property shapes, and a name no framework has is not a class. The
mutant that makes `ARGeometryElement`'s line count 4 instead of 2 turns the check red.

## The geo configuration

`ARGeoTrackingConfiguration` is carried (`ARKit/ARGeoTrackingConfiguration.m`): `+new` and `-init` answer an object
of the class, and `+isSupported` answers NO, so a session started with it is refused through
`session:didFailWithError:`.

The host's Catalyst ARKit gives the same answers. Measured with a one-file program compiled with the host's flags
(`-target $(uname -m)-apple-ios14.0-macabi`, the iOSSupport frameworks): the class is present; `+isSupported` is NO;
`+new` and `-init` each return an `ARGeoTrackingConfiguration`; `+checkAvailabilityWithCompletionHandler:` and
`+supportsAppClipCodeTracking` are declared.

The NO on the device is the documented requirement, not a measurement. Apple documents geographic tracking as needing
an A12 chip or later, and this device has an A5 (the iPhone 4S). The host is a Mac, and its NO says nothing about the
device, so the device probe (`tests/backports/device/arkit-config`) checks that the class answers NO on the 4S and that
a session started with it is refused.

The class's settings (`environmentTexturing`, `planeDetection`, `detectionImages`, and the rest the SDK declares) and
its two availability checks are owed (`registry/ARKit/ios14shells.json`). `worldAlignment` is declared
`*unavailable ios=14.0` in the SDK (`spec/ARKit/declarations.tsv` line 229), so no row is owed for it.

## What is not carried, and why it is not a fake

The methods in the table above are not carried. They are not rows of this registry, so no status says they are
absent; a caller compiled against the SDK that calls one gets an unrecognised selector. That is the gap, and it is
not hidden: each method is listed here with the reason it is not built.

- The factories and updates of the face and object classes need the TrueDepth camera or a depth scan, which this
  device does not have; there is no measurement of a fallback to build.
- `ARMatteGenerator`'s methods need a neural segmentation of the people in a frame, which this port does not
  build.
- The body methods need a body estimator, which this port does not build.

Nothing in the port reads a value back from one of these classes: a session never makes an instance, so the nil and
zero values above are only what a caller that builds one by hand gets.
