# The iOS 11 Vision initialisers the headers mark NS_UNAVAILABLE: what the host answers, and the port's answers

The headers of the iOS 11 Vision classes declare `-init`, `+new` and `-initWithCompletionHandler:` on nine classes as
`NS_UNAVAILABLE`, so no application calls them through a header. The selectors are still answered by the release: the
class's own `-init` is not overridden, so NSObject's initialiser runs and returns the receiver. `tests/backports/host/
vision-init11` measures it, and the port answers the same.

## What the host does, measured

On macOS (this machine's Vision, called from a bare tool), each initialiser is called on a fresh allocation, and the class
of the answer is printed:

- `-init` and `+new` answer an object of the class itself, for `VNFaceLandmarkRegion`, `VNCoreMLModel`, `VNCoreMLRequest`,
  `VNFaceLandmarks`, `VNImageRequestHandler`, `VNTargetedImageRequest`, `VNTrackObjectRequest`, `VNTrackRectangleRequest`
  and `VNTrackingRequest`. None of the answers is nil.
- `-initWithCompletionHandler:` answers an object of the class itself, for `VNCoreMLRequest`, `VNTargetedImageRequest`,
  `VNTrackObjectRequest`, `VNTrackRectangleRequest` and `VNTrackingRequest`.

## What the port answers

The port's classes inherit NSObject's initialiser, and its own answers are the same objects, on the same fourteen calls.
The test compares the lines, and a plant (a category on `VNCoreMLModel` whose `-init` answers nil) must turn the comparison
red.

## What is not measured

- The requests' behaviour once built (what `-performRequests:` does with a request built this way) is the subject of the
  request rows, not of these initialisers.
- The header marks these selectors unavailable because they are not a way to make a useful object; the measurement says
  what the release answers, and that is all the rows claim.

## Registry

The fifteen method rows of `registry/Vision/ios11.json` that name these initialisers are `implemented`, with this file as
their `facts`. The rows' `reason` no longer says that neither release carries Vision: the port carries these classes, and the
host answers as above.
