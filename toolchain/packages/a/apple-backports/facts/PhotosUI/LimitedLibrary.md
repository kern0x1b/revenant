# The limited library picker, iOS 14.0 and 15.0

Two rows: `-[PHPhotoLibrary presentLimitedLibraryPickerFromViewController:]` and the form of
iOS 15 that also takes a completion handler. They live in a category on the port's
`PHPhotoLibrary`, which is the direction the SDK's own header takes - `PHPhotoLibrary+PhotosUISupport.h`
declares both in a category of the class - and the code is in `PHPhotoLibraryLimitedPicker14.m`
and `PHPhotoLibraryLimitedPicker15.m`, one object per release. The rows are in
`registry/PhotosUI/ios14.json` and `registry/PhotosUI/ios15.json`.

Source: `PHPhotoLibrary+PhotosUISupport.h` of the iOS 16.4 SDK for the contract and its wording;
`ALAssetsLibrary.h` of the same SDK for the four values the release's own library authorization has;
`PHPhotoLibrary.h:26` of the same SDK for the limited case of iOS 14; and the host's own
`PHPhotoLibrary+PhotosUISupport.h`, which is where the comparison stops.

## Nothing is presented, and that is the whole answer

The header says: "If the user has not enabled limited photo library access mode for this
application, then this method will do nothing." On this port the application can never have
enabled it. The release's library authorization is `ALAuthorizationStatus`, which has exactly
four values - not determined, restricted, denied, authorized (`ALAssetsLibrary.h:45-52`) - and
`+[PHPhotoLibrary authorizationStatus]` is that value cast (`PHPhotoLibrary.m:34`).
`PHAuthorizationStatus` is the same four plus the three cases of iOS 8 and the limited case of
iOS 14 (`PHPhotoLibrary.h:26`), so the port's status is one of the release's four and never
`PHAuthorizationStatusLimited`. There is no limited selection here, and so there is nothing for
a picker to manage.

The rows are `inert` rather than `implemented` because that is the honest word for them: the port
carries the name, and what it does with it is nothing, which is the header's own answer for the
only state this port can be in. The effect in each row says so.

## The block of iOS 15, which is a choice

The header says the block "will be called upon the user finishing their selection. Only newly
selected assets will be provided to the block", and does not say what happens when there is no
selection to finish. The port calls it, with an empty array.

That is a decision, and it is recorded as one in the row, because the two readings differ in what
an application sees. Not calling it leaves a caller that presents the picker and dismisses itself
from the block waiting for a user who is never asked. Calling it says the true thing - no assets
were newly selected, because none were - and lets the caller finish. A nil block is not called.

## Why no host can be asked about either

The host's own `PHPhotoLibrary+PhotosUISupport.h` declares both methods inside
`#if TARGET_OS_IPHONE || TARGET_OS_MACCATALYST` and `API_UNAVAILABLE(macos, tvos, watchos)`.
There is no macOS implementation to compare with, so the differential of
`tests/backports/host/photosui` does not carry these two rows and says so in its own header: the
other fifteen rows of this family are compared there, these two rest on the wording above. The
device test calls both, which is the only place a view controller exists to present from.

## Where it is proved

`tests/backports/device/phpickermodel.m` measures the behaviour on a real device: both selectors
answered, presenting one raised nothing and presented nothing, and the other form called its block
once with no newly selected assets. 38 checks, 0 failures on an iPad 2 running iOS 6.1.3
(2026-10-01).

`tests/backports/device/phpicker.m` checks the same two calls in an application, and is compiled
here and not run: this device has no `/private/var/tmp/sblaunch`.
