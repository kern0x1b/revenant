# The -init and +new rows: the release's own answer is the superclass's, and the port gives the same

Thirty-odd registry rows said `absent` for `-init` or `+new` of a class whose header marks `-init`
`NS_UNAVAILABLE` (or whose class has no `+new` declaration at all). `absent` means `respondsToSelector:`
answers NO, and that is not what the release answers: the selector is there, inherited from the superclass.
The measurement is the same one the MetalKit rows took (`tests/backports/host/metalkit-init`): compare the
IMP each class answers the selector with against the IMP its superclass answers it with, and check whether
the class defines the selector in its own method list.

## Measured

The Mac Catalyst copy of ARKit and SensorKit (the iOSSupport frameworks in the macOS SDK), read with
`class_getInstanceMethod` / `class_getClassMethod` and `class_copyMethodList`:

| class | superclass | defines its own -init | defines its own +new | -init is the superclass's | +new is NSObject's |
| --- | --- | --- | --- | --- | --- |
| ARAnchor, ARCamera, ARFrame, ARHitTestResult, ARLightEstimate, ARPlaneGeometry, ARPointCloud | NSObject | no | no | yes | yes |
| ARRaycastQuery, ARRaycastResult, ARTrackedRaycast, ARReferenceImage, ARVideoFormat, ARWorldMap | NSObject | no | no | yes | yes |
| ARSkeletonDefinition, ARBody2D, ARCollaborationData, ARFaceGeometry, ARGeometryElement, ARGeometrySource, ARMatteGenerator, ARMeshGeometry, ARReferenceObject, ARGeoTrackingStatus, ARSkeleton | NSObject | no | no | yes | yes |
| ARSkeleton2D, ARSkeleton3D | ARSkeleton | no | no | yes | yes |
| SRAcousticSettings, SRPhotoplethysmogramAccelerometerSample, SRPhotoplethysmogramOpticalSample, SRSleepSession | NSObject | no | no | yes | yes |
| ARConfiguration | NSObject | **yes** | no | no (its own) | yes |
| ARGeoTrackingConfiguration | ARConfiguration | **yes** | **yes** | no (its own) | no (its own) |
| ARSCNFaceGeometry | SCNGeometry | no | no | no (SCNGeometry's own) | yes |

ARPlaneAnchor and ARImageAnchor `-initWithName:transform:` and `-initWithTransform:` (declared
`NS_UNAVAILABLE` in the SDK) answer ARAnchor's own IMP on the host, and neither class defines them.

Controls, in the same probe: a class that overrides `-init` differs from NSObject's IMP, and a name no
framework has is not a class.

## What the port does

- The carried classes define no `-init` and no `+new` in their `@implementation` blocks. The check is a
  source scan, not a compiled comparison: `tests/backports/host/arkit-nsobject-init/run.sh` reads `ARKit/*.m`
  and `SensorKit/*.m` and finds no definition of the 63 selectors. A planted definition in a scratch copy
  (`+[ARCamera new]` returning nil) is found by the same scan, so the scan can fail.
- The superclass on the port side is the release's by construction: each `@implementation` names no superclass
  and is compiled against the SDK's own `@interface`, which fixes the superclass. So a selector the class does
  not define is answered by the same superclass IMP as on the host.
- Compiling the port's objects beside the host's, as `metalkit-init` does, is not done for these classes yet.
  The Catalyst SDK lacks CoreMotion, which the tracker and the configuration files import, so those files
  cannot be built for the host as they are.

## The instance-method `-new` rows

The rows `-[ARRaycastQuery new]`, `-[ARRaycastResult new]` and `-[ARTrackedRaycast new]` are the instance selector
`new`, which NSObject does not have: `+new` is the class method. The SDK declares it on each class anyway, as
`- (instancetype)new NS_UNAVAILABLE;` from iOS 13.0 (ARRaycastQuery.h, ARRaycastResult.h, ARTrackedRaycast.h), and
the generator's spec says the same (spec/ARKit/declarations.tsv, the `(im)new` rows, `*unavailable ios=13.0`).

What the release answers is measured on the Catalyst host's ARKit, by `tests/backports/host/arkit-instance-new/run.sh`:
the class defines no instance `new` of its own, `respondsToSelector:` answers NO, and a call raises
`NSInvalidArgumentException`, the unrecognised-selector exception. The port defines no `-new` on these classes, so
its answer is the same, and the rows are implemented as that answer: nothing is built, and nothing is faked.

An earlier note of these rows said the SDK declared no instance `-new`. That was wrong; the header declares it
unavailable, and the test reads the header, so the note cannot drift from it.
