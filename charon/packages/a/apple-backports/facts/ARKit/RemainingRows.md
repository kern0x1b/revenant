# ARKit's 276 missing rows, partitioned by the `@implementation` the tree actually has

Generated from `corpus/ledger-2026-10-03/ARKit.tsv` -- its `missing` rows -- and from the
`@implementation` lines in `packages/a/apple-backports/ARKit/*.m`, which is the only definition of
"is this class in the tree" that does not need a registry row or a guess. The earlier version of
this page asked the wrong question: it took a row's *missing* status to mean its owner class was
absent, and so filed `ARWorldTrackingConfiguration` (16 rows) and `ARConfiguration` (13) under
"a class this tree does not carry". Both classes are defined -- in `ARConfiguration2.m` and
`ARConfiguration.m`. A missing row means the row is missing, not its owner.

| bucket | rows | what it waits for |
| --- | --- | --- |
| the class is in the tree | 100 | nothing structural: these are code you can write now |
| a pose | 27 | an estimate of a body; see `Pose.md` |
| the class is not in the tree | 149 | the class itself, one whole class at a time |

## The class is in the tree -- 100 rows, writable now

Ordered by how many rows each owner has, so the biggest wins come first.

- `ARWorldTrackingConfiguration` - 16 row(s) (method 3, property 13), defined in ARConfiguration2.m
- `ARConfiguration` - 13 row(s) (method 3, property 10), defined in ARConfiguration.m
- `ARSkeletonDefinition` - 10 row(s) (class 1, method 3, property 6), defined in ARSkeletonDefinition13.m
- `ARBodyTrackingConfiguration` - 7 row(s) (property 7), defined in ARConfiguration4.m
- `ARFaceTrackingConfiguration` - 6 row(s) (method 2, property 4), defined in ARConfiguration2.m
- `ARImageTrackingConfiguration` - 5 row(s) (method 2, property 3), defined in ARConfiguration3.m
- `ARVideoFormat` - 5 row(s) (method 2, property 3), defined in ARVideoFormat.m
- `ARObjectScanningConfiguration` - 4 row(s) (method 2, property 2), defined in ARConfiguration3.m
- `AROrientationTrackingConfiguration` - 3 row(s) (method 2, property 1), defined in ARConfiguration2.m
- `ARPlaneAnchor` - 3 row(s) (method 2, property 1), defined in ARAnchor.m
- `ARAnchor` - 2 row(s) (method 2), defined in ARAnchor.m
- `ARCamera` - 2 row(s) (method 2), defined in ARFrame.m
- `ARFrame` - 2 row(s) (method 2), defined in ARFrame.m
- `ARHitTestResult` - 2 row(s) (method 2), defined in ARAnchor.m
- `ARLightEstimate` - 2 row(s) (method 2), defined in ARFrame.m
- `ARPlaneGeometry` - 2 row(s) (method 2), defined in ARPlaneGeometry.m
- `ARPointCloud` - 2 row(s) (method 2), defined in ARAnchor.m
- `ARReferenceImage` - 2 row(s) (method 2), defined in ARReferenceImage.m
- `ARWorldMap` - 2 row(s) (method 2), defined in ARWorldMap.m
- `ARImageAnchor` - 2 row(s) (method 2), defined in ARImageAnchor.m
- `ARRaycastQuery` - 2 row(s) (method 2), defined in ARRaycast.m
- `ARRaycastResult` - 2 row(s) (method 2), defined in ARRaycast.m
- `ARTrackedRaycast` - 2 row(s) (method 2), defined in ARRaycast.m
- `ARSession` - 1 row(s) (method 1), defined in ARSession.m
- `ARPositionalTrackingConfiguration` - 1 row(s) (property 1), defined in ARConfiguration4.m

## A pose -- 27 rows

- `ARSkeleton3D` - 7 row(s)
- `ARSkeleton` - 6 row(s)
- `ARBodyAnchor` - 5 row(s)
- `ARSkeleton2D` - 5 row(s)
- `ARBody2D` - 4 row(s)
`ARSkeletonDefinition` is **not** in this bucket: the class is in the tree and its two-dimensional
table is measured. Its two remaining `owed` rows are its three-dimensional half.

## The class is not in the tree -- 149 rows

One line per owner, with its row count. This is the decision list for whole classes.

- `ARGeoTrackingConfiguration` - 15 row(s)
- `ARReferenceObject` - 13 row(s)
- `ARGeoAnchor` - 10 row(s)
- `ARGeometrySource` - 9 row(s)
- `ARFaceGeometry` - 9 row(s)
- `ARCoachingOverlayView` - 8 row(s)
- `ARGeometryElement` - 8 row(s)
- `ARFaceAnchor` - 7 row(s)
- `ARAppClipCodeAnchor` - 6 row(s)
- `ARGeoTrackingStatus` - 6 row(s)
- `ARMatteGenerator` - 6 row(s)
- `ARMeshGeometry` - 6 row(s)
- `ARSCNFaceGeometry` - 5 row(s)
- `ARSKView` - 5 row(s)
- `ARSKViewDelegate` - 5 row(s)
- `ARCollaborationData` - 4 row(s)
- `ARPlaneExtent` - 4 row(s)
- `AREnvironmentProbeAnchor` - 4 row(s)
- `ARParticipantAnchor` - 3 row(s)
- `ARCoachingOverlayViewDelegate` - 3 row(s)
- `ARMeshAnchor` - 3 row(s)
- `ARObjectAnchor` - 3 row(s)
- `ARDirectionalLightEstimate` - 3 row(s)
- `ARDepthData` - 2 row(s)
- `ARSkeletonJointNameForRecognizedPointKey()` - 1 row(s)
- `ARTrackable` - 1 row(s)
