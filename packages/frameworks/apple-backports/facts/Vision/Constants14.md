# Vision's string constants of iOS 14

Eighty-one string constants that iOS 14 added to Vision are carried in `Vision/Vision14_0Constants.m`:

- the keys of a recognized point, the landmark keys the 14.0 header deprecates in favour of the joint names
  (`VNBodyLandmarkKey...`, 19 names), and the region keys of the same family (`VNBodyLandmarkRegionKey...`, 6);
- the joint names of a human body pose observation (19) and of a human hand pose observation (21);
- the joint groups of the two observations (7 and 6), and `VNRecognizedPointGroupKeyAll`, which is the one key a
  group of joints is asked for with;
- the two video processing options (`VNVideoProcessingOptionFrameCadence`, `VNVideoProcessingOptionTimeInterval`).

Their values are not made up here: they are what the host's Vision gives, read by a probe and compared byte for byte.
An application compares these keys against the points a pose request returns, so the values are the contract.

## What is carried, and what is not

A constant is a name and a string. The classes that answer with these keys are not carried yet, and each has its own
row in `registry/Vision/absent_Vision.json` with what it needs:

- `VNDetectHumanBodyPoseRequest`, `VNDetectHumanHandPoseRequest` need a pose network the port does not carry;
- `VNHumanBodyPoseObservation`, `VNHumanHandPoseObservation`, `VNRecognizedPoint`, `VNRecognizedPointsObservation`,
  `VNDetectedPoint` are results of those requests.

So a constant here is carried for the application that compares against it, and it is not a claim that a pose request
runs.

## How the values were measured

The host is macOS 27.0.1 (build 26A434), arm64. The probe is `tests/backports/host/vision-constants14/probe.m`; it prints
`name=value` for each of the 82 names, once compiled against the host's Vision framework and once compiled against
`Vision14_0Constants.m` and the generated `.gen/Vision/VisionConstants140.m` (the 3D group key, which the generator defines from the 26.2 cache's value) with no framework linked, and `run.sh` compares the two outputs. The run prints

    port: the 82 constants are the host's, byte for byte
    plant: the changed value is seen: 2 line(s) differ

The plant changes one value in a scratch copy (`left_foot_joint`, which two names share) and the comparison must see it.

## What the measurement does not prove

- The values are the macOS 27 host's, not the iOS 14 release's. A value that changed between iOS 14 and macOS 27 would
  pass this test and be wrong on a device. The iOS 14 cache's own strings have not been read for these names; that is
  the check that would settle it, and it is open.
- The SDK's typedef names of the constants (`VNRecognizedPointKey`, `VNHumanBodyPoseObservationJointName`, ...) are the
  ones the port compiles against; the test does not check them, only the values.
- Nothing here has run on a device. The constants are data; no device behaviour depends on them beyond the string.

## Registry

Each of the 81 hand rows is `implemented` in `absent_Vision.json` with `facts` pointing here and `source` naming the host
and this probe. The 3D group key has no hand row: the generator owns it (`.gen/Vision/rows.tsv`), and a hand row beside it
would define the symbol twice. The rows keep their file so that the change is the status and the source of those rows and nothing else.
