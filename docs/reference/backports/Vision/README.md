# Vision on iOS 6: the Swift module

The Objective-C side of Vision is the backport's classes under `frameworks/Backports/src/Vision`. The SDK's apinotes refine
three members for Swift (`__boundingBox`, `__normalizedPoints`, `__pointsInImage(imageSize:)`), and the SDK's own Swift
overlay supplies the forms that call them. At armv7 the SDK has no such interface, so `src/Vision/Vision.swift` is the
backport's:

- `VNFaceLandmarkRegion2D.normalizedPoints` and `pointsInImage(imageSize:)` as `[CGPoint]`, empty when the region has no
  point;
- `VNRecognizedText.boundingBox(for:)` taking a `Range<String.Index>`, which calls the refined method with an `NSError`
  out-parameter and throws it when set, because the refined method does not throw;
- `VNContour.normalizedPoints` as `[simd_float2]`.

The module is named like the SDK framework, so it is built with `-import-underlying-module` and its sources do not import
it. A consumer builds the `Vision` target of the `Swift` component and passes its module folder with `-I`.

## Limits

The backport declares the face landmark classes but has no detector that fills them: a region has no point, the region
accessors return empty arrays, and `-[VNFaceLandmarkRegion2D pointsInImageOfSize:]` returns NULL
(`frameworks/Backports/src/Vision/VNObservations.m`). Text recognition is the existing one
(`docs/explanation/backports/vision-text.md`).

## Checked

`frameworks/Backports/tests/framework_overlay_test.lua` builds the module for armv7 iOS 6.0 and typechecks
`frameworks/Backports/tests/Vision/overlay.swift`, the lines of Telegram's `CameraPreviewView.swift` and
`ImageContentAnalysis.swift`, and checks that the same file fails without the module.

Not measured on a device: recognition itself.
