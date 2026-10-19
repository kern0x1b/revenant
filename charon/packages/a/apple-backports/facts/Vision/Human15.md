# VNHumanObservation (iOS 15): the class, and what a fresh one answers

`VNHumanObservation` is the observation of a person, a subclass of `VNDetectedObjectObservation` in the 15.0 headers, and
the type the human rectangles request types its results as. It is implemented in `Vision/VNHumanObservation.m`, with the test in
`tests/backports/host/vision-human15`.

## What the host does, measured

- **Its surface** is the header's: the superclass, `+new` and `-init` (both answer objects of the class), and the one
  read-only property `upperBodyOnly` (a BOOL) with its getter. `tests/backports/host/vision-human15/surface.tsv` holds the
  five members and the reflection probe of `tests/backports/host/vision-results14` reads them from both sides.
- **A fresh object made with `-init`** answers `upperBodyOnly` NO (0), a zero bounding box, a confidence of 1, and the
  selectors `init` and `new` as the class's own. Its UUID is a new one on each call, so the test leaves it out.

## What the port does

The port's class has one ivar, `upperBodyOnly`, which is zero on a fresh object, so the answers above hold. The port's
`VNDetectedObjectObservation` gives the bounding box and the confidence, which the fresh object answers from.

The port makes no `VNHumanObservation` of its own: `VNDetectHumanRectanglesRequest` answers `VNErrorNotImplemented`
(`Vision/Vision110.m`), so the results of that request are not made, and the class is held to the host's answers for an
object made directly.

## What is not measured

- **The results of the human rectangles request on the host.** A picture with a person in it was not made, so what the
  request types its results as, and what `upperBodyOnly` is on each of them, is not measured here. The request is not
  carried by the port, and its row says so.
- **Setting `upperBodyOnly`.** The property is read-only in the header, so no setter is written or tested.
