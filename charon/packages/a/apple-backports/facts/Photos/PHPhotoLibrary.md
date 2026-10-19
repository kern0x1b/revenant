# The authorization of the photo library, iOS 8.0

`PHPhotoLibrary` came in iOS 8.0 with the Photos framework. Of the class this package
carries what an application asks first and can be answered truthfully: whether it
may read the photos, and the prompt that decides it.

Source: Photos of the arm64 shared cache of iOS 12.0 - `+[PHPhotoLibrary
sharedPhotoLibrary]` at `0x18fbaf99c`, `+authorizationStatus` at `0x18fbafb5c` and
`+requestAuthorization:` at `0x18fbafc7c`. An iPad 2 running 6.1.3 for the status the
release's `ALAssetsLibrary` gives.

## What it is

`+authorizationStatus` reads the Photos entry of the privacy service and maps it to
`PHAuthorizationStatus`, and treats a restriction as its own value. `+requestAuthorization:`
asks the same service, which shows the system prompt once, and calls the handler with the
answer.

## Where iOS 6 differs

The release has the same permission behind `+[ALAssetsLibrary authorizationStatus]`, with
the same four values in the same order (not determined 0, restricted 1, denied 2,
authorized 3), so the status is that call cast. The prompt is shown by the first
`ALAssetsLibrary` request that touches the library; `+requestAuthorization:` makes one, an
enumeration of the saved-photos group, and calls the handler once with the status after
it. When the status is already decided the handler is called with it at once, off the main
thread. The two calls with an access level of iOS 14 answer the same, and the status is
never limited, as the release has no limited selection.

Changes and their observers are told from `ALAssetsLibraryChangedNotification`
(`Changes.md`, "Observing changes"). Everything else that needs the Photos database is
absent: the availability observers, cloud identifiers and the history of changes. The rows
are in `registry/Photos/ios8.json`.
