# Changes to the photo library, iOS 8.0

`-[PHPhotoLibrary performChanges:completionHandler:]` and `-performChangesAndWait:error:` run a block that makes change requests,
and apply the requests together. iOS 6 has one way to change the library: an application adds an image or a video to the saved photos
through `ALAssetsLibrary`. So the change that can be made is a creation.

## What is made

`+[PHAssetChangeRequest creationRequestForAssetFromImage:]`, `...FromImageAtFileURL:` and `...FromVideoAtFileURL:` are made
into a write to the saved photos: an image with `writeImageToSavedPhotosAlbum:`, the bytes of an image file with
`writeImageDataToSavedPhotosAlbum:metadata:`, a video with `writeVideoAtPathToSavedPhotosAlbum:`. A creation date and a
location set on the request are written as the EXIF, TIFF and GPS metadata of the image (an image with either set is written from its JPEG data, at full quality). A file that is not an
image, or a video the saved photos cannot hold, gives nil, as the header says.

`placeholderForCreatedAsset` is a `PHObjectPlaceholder` whose identifier is a token before the write, and is the address of the new asset
after it; the token also finds the asset with `+[PHAsset fetchAssetsWithLocalIdentifiers:options:]`, and is kept between launches in the
application support folder of the application.

`+[PHAssetCreationRequest creationRequestForAsset]` (iOS 9) is the same kind of change request, staged instead of written immediately:
`addResourceWithType:data:options:` and `addResourceWithType:fileURL:options:` accept exactly one resource, photo or video, and the
commit writes it the same way the iOS 8 creation request does. A second resource, or a resource type other than photo or video
(adjustment data, an alternate photo, a live photo pairing), fails the change with a reason. `PHAssetResourceCreationOptions.shouldMoveFile` on a file
resource removes the file once the asset is made from it, as the header says ("the original file is removed if the asset is
created successfully"); `ALAssetsLibrary` itself always copies, so the move is the copy followed by the removal. The header also
says a file that is open or hard-linked cannot be moved: a file with more than one hard link, and one whose folder does not let it
be removed, fail the change with `PHPhotosErrorInvalidResource` and a reason when the requests are checked, before anything is
written. Whether another process holds the file open iOS 6 gives no public way to ask, so that case is not refused. A removal
that still fails after the asset is made fails the change with the file system's error, the way every write of the change that
fails after the ones before it does (below): the asset is then in the library and the file is still where it was. A video
resource given as data is written by `ALAssetsLibrary` only from a file, so the data is staged in a file of the process's
temporary folder and that file is removed once the library has copied it, whether the write succeeded or not; a staged file
that cannot be removed after a successful write fails the change the same way. The staged file is named with the extension
of the video's type, because the library tells a movie by its path: on the iPad 2 the same QuickTime bytes, and the same
MPEG-4 bytes, are compatible with the saved photos album as `.mov` and `.mp4` and not with no extension, and a write of the
data from a file with none failed with no asset. The extension is the one of the options' `uniformTypeIdentifier`, else of
their `originalFilename`, else of the data's container: `mp4` for an ISO base media file whose `ftyp` brand is not
QuickTime's `qt  `, `mov` otherwise. `+supportsAssetResourceTypes:` answers
YES only for a single-element array naming the photo or the video type. `+[PHAssetResource assetResourcesForAsset:]` (iOS 9) describes
the one resource an iOS 6 asset already has, read from `ALAssetRepresentation` (`defaultRepresentation`) rather than from a Photos
database row; `+assetResourcesForLivePhoto:` always gives an empty array, since no live photo can exist on this release.

Albums are the one other thing this release lets an application change. `+[PHAssetCollectionChangeRequest
creationRequestForAssetCollectionWithTitle:]` and `+changeRequestForAssetCollection:` (only for a regular album — a smart album or one
synced from elsewhere is refused) are made into `-[ALAssetsLibrary addAssetsGroupAlbumWithName:resultBlock:failureBlock:]` and
`-[ALAssetsGroup addAsset:]`; `addAssets:` queues assets to append at commit, and `placeholderForCreatedAssetCollection` resolves like
the asset placeholder above. `addAssets:` takes a `PHAsset` or, the documented way to add an asset to an album in the same change
that creates it, the `PHObjectPlaceholder` such a creation request gives back. The documentation of `PHObjectPlaceholder` says a
placeholder can be used "to make additional change requests involving the object to create" and names no order for them, so the
port asks for none: the requests of a block are written in two rounds, first everything a request makes (the assets, the new
albums), then what relates one object to another (the assets an album is given), and the placeholder is resolved in the second
round, when every creation of the block has been written, whether the asset's creation request came before the album request or
after it. The earlier text here asked a block to make the asset's creation request first, the order this port happened to write
in; that was a limit of the port, not of the API. iOS 6 has no way through `ALAssetsLibrary` to rename an album, reorder or remove its assets, or delete an
album at all, so `setTitle:` on an existing album, `insertAssets:atIndexes:`, `removeAssets:`, `removeAssetsAtIndexes:`,
`replaceAssetsAtIndexes:withAssets:`, `moveAssetsAtIndexes:toIndex:` and `+deleteAssetCollections:` all fail the change with a reason,
before anything is written.

The block is run first and its requests are checked all together before any is written. A block called outside a change raises an
`NSInternalInconsistencyException` with the text of iOS 8. The completion handler is called once, off the main thread, with the
success and an error in the domain `PHPhotosErrorDomain`. No access answers `PHPhotosErrorAccessUserDenied` or `PHPhotosErrorAccessRestricted`.

## Reading a resource back

`+[PHAssetResourceManager defaultManager]` (iOS 9) gives the bytes of a `PHAssetResource` back, on the same `ALAssetRepresentation` the
resource was built from, one chunk at a time, as the documentation of iOS 9 says Photos does ("calls your handler block at least
once, progressively providing chunks of data"; the complete data is their concatenation):
`-requestDataForAssetResource:options:dataReceivedHandler:completionHandler:` reads the representation with
`getBytes:fromOffset:length:error:` one chunk after another and calls `dataReceivedHandler` with each, then `completionHandler` with
`nil`; `-writeDataForAssetResource:toFile:options:completionHandler:` writes each chunk as it is read. Only one chunk is held at a
time, so a video is never read into memory whole. A chunk is 1 MiB here, the port's own choice: the size Photos of iOS 9 and later uses
cannot be measured on this machine, since that needs a Photos library with assets in it and the host's one library is the
owner's, and the devices run iOS 6. Nothing of the API depends on it; the device test holds what does not depend on the size: the chunks, none
empty, are together the bytes of a direct read of the asset, and a video of several megabytes is not handed over in one piece.

The file of `writeDataForAssetResource:` is written into a file of its own beside the given one and renamed into place when every
chunk is in, and the given file is left as it was when the read or a write fails, with the file system's error (the device test
holds this). A file already there is replaced on success. That is the port's own choice, not measured behaviour: what Photos
itself does with a file that is already there is not measured, for the same reason as the chunk size, and the documentation says
only that it writes the data "progressively" into the file. The reviewer recalls, without a measurement, that Photos refuses an existing file with a
"file exists" error; if a measurement shows that, the port diverges here. The device test does not check the replacement, since
its only source would be the port itself.

Either call gives `completionHandler` an error, and never calls `dataReceivedHandler` again, when the asset behind the resource's
`assetLocalIdentifier` is gone (`PHPhotosErrorIdentifierNotFound`), the asset has no representation (`PHPhotosErrorMissingResource`),
or the release gives no more bytes before the representation's own `size` (its own error, or `PHPhotosErrorInternalError` when it
gives none) — the read never ends on a silently short answer. `PHAssetResourceRequestOptions.networkAccessAllowed` is held but
changes nothing, since the read never reaches the network; `progressHandler`, when set, is called after each chunk with the part
read so far, the last time with `1.0`. The read runs on a global queue after the call returns, and the handlers of one request are
called one after another from it, so a caller can cancel it: `-cancelDataRequest:` takes the request out of the manager's pending
ones, and the read looks at that before every chunk. A request cancelled before its first chunk calls `dataReceivedHandler` never,
one cancelled during the read no more after that, and either calls `completionHandler` once, with `PHPhotosErrorUserCancelled`
(3072, which the header documents for "the asset resource or editing request"); a cancel after the last chunk still completes it
cancelled, which the documentation allows ("a non-nil error when the data is complete if the user cancels"). A request that has
completed already is not changed by a cancel. The earlier text here, that the read had always finished before a caller could
cancel, was wrong: the read was asynchronous already, and a cancel reached nothing.

## Observing changes

`-[PHPhotoLibrary registerChangeObserver:]` and `-unregisterChangeObserver:` keep the observers in a weak hash table, so an
observer that goes away is dropped without being unregistered. iOS 6 says that the library changed with
`ALAssetsLibraryChangedNotification`, posted by an `ALAssetsLibrary`; the port listens to the one it reads and writes through,
from the first registration on. Every notification makes one `PHChange` that every observer registered at that moment is sent
with `photoLibraryDidChange:`, one after another on a serial queue that is not the main thread.

The header of iOS 6 says that the user info may name the assets and groups that changed (`ALAssetLibraryUpdatedAssetsKey` and the
three group keys) and that a nil user info means everything changed. Measured on 6.1.3, for writes of the application itself: the
notification is posted once per write, from the library that wrote and off the main thread; the first write of a process, before
its library had read anything, came with an empty dictionary although an asset was added, and a later one with
`ALAssetLibraryUpdatedAssetGroupsKey` and `ALAssetLibraryUpdatedAssetsKey`. So an empty dictionary is not taken to mean that
nothing changed, an asset the keys name counts as changed, and the change reads again what it is asked about in every case. Every fetch result keeps the query that made it
and its options, and `-changeDetailsForFetchResult:` runs that query again: the objects of the fetch before that are not in the
fetch after are the removals, as indexes of the fetch before; the new ones the insertions, and the objects in both that the
notification named or whose properties read differently the changes, as indexes of the fetch after. When nothing differs it
answers nil. The objects both fetches hold must keep their order among themselves to be told as indexes: the saved photos of the
release are in the order of their dates and an asset does not move, so a change that reorders is told with
`hasIncrementalChanges` NO and no indexes, the answer the header allows for any change; `hasMoves` is always NO. A fetch whose
options say `wantsIncrementalChangeDetails` NO is told the same way. `-changeDetailsForObject:` reads the asset or album again by
its identifier: nil when it reads the same and was not named, `objectWasDeleted` when it can no longer be read, and
`assetContentChanged` when the notification named the asset, which is all the release tells: it does not separate a change of
the bytes from one of the properties. `+[PHFetchResultChangeDetails changeDetailsFromFetchResult:toFetchResult:changedObjects:]`
compares the two fetches it is given the same way.

## What is refused

The library of iOS 6 lets an application add to it and read it, not delete from it and not change what is in it. `+deleteAssets:`, an
edit of an asset with `+changeRequestForAsset:`, a favorite, a hidden asset and a date or a location of an existing asset make the whole
change fail with `PHPhotosErrorChangeNotSupported` and a reason, before anything is written. The requests that come with the
content editing (`contentEditingOutput`, `revertAssetContentToOriginal`) are absent; the album and resource requests above are the
only two exceptions, and each still refuses whatever `ALAssetsLibrary` itself cannot do.

Once the checks pass the writes are made one after another; a write that then fails (the disk is full) leaves the ones before it made, as the release has no way to undo them.

Every error of the port is one of the header's named `PHPhotosError` codes, each for the case the header gives it, or the error
the release or the file system gave, passed on: a creation request with no resource is `PHPhotosErrorMissingResource` ("Asset
resource missing"); resource data that is not an image, an image with no pixels, and a file that cannot be moved are
`PHPhotosErrorInvalidResource` ("Asset resource validation failed"); an asset, a resource's asset or an album that is not in the
library (an asset added to an album that no committed change made, an album gone) is `PHPhotosErrorIdentifierNotFound`
("Identifier was not found"); what iOS 6 cannot do, found only at the write (an album name taken, an album that refuses an
asset, as the release does for one the application may not edit), is `PHPhotosErrorChangeNotSupported`, the code of the same
refusals found by the checks; a library that answers a write with neither an asset nor an error is
`PHPhotosErrorInternalError` ("An unknown, internal error"). Which code Photos of iOS 9 and later gives for each of these was not
measured, for the reason above; the header's text for the code is the source.

Source: the header of iOS 16.4; the host's Photos for the text of the exception and the
error codes; `ALAssetsLibrary` of an iPad 2 running 6.1.3 for the iOS 8 creation request. The iOS 9 creation request with its placeholder
passed to `addAssets:` of an album created in the same change, the album found again by its placeholder with that one asset in it,
the refused rename, reorder and delete (`PHPhotosErrorChangeNotSupported`, title unchanged afterwards), the asset resource, and the
resource manager (completion once with `nil`, progress once with `1.0`, within five seconds) were run on an iPad 2 running 6.1.3 on
2026-09-23, called off the main thread, 17 of 19 checks passing; the two others are the release's rewrite below. The refusal of
an album name in use below was run there too: 3300, and the number of 8-by-8 saved photos the same before and after.
The change observers were run on the same iPad on 2026-09-23 with `tests/backports/device/photoschanges8.m`, an application of its
own with the photo library allowed: 22 checks, 0 failures. The data of the resources (`tests/backports/device/photosdata9.m`: the
chunked read and its cancel, the write to a file, `shouldMoveFile` and the hard-linked file, a video given as data in a QuickTime
and an MPEG-4 container, the error codes, an album's placeholders after every creation of the change block) was run there on
2026-09-24 with this tree's Photos sources: 34 checks, 0 failures. One of them, that a write replaces a file already there, has
since been dropped, since its expectation came from the port itself (above); the other 33 are the test as it stands. Controls: the same test over the Photos sources of main
at 7bb1720d, in an earlier form whose small test videos the iPad's encoder refused, failed the album placeholder and the error
code checks this tree passes (18 checks, 11 failed, the rest not reached); and before the staged file took an extension, the
video given as data failed with no asset (32 checks, 1 failed).

## The run of 2026-09-30, and the path that takes it again

The three programs above had no path that ran them: they were in the tree and their figures were in this
page, and a regeneration of the queue files had taken the header that says so with it. There is one now --
`sh tests/backports/device/photos/run.sh` builds each program from this tree's own Photos sources, pushes it
through the driver's own transport, waits for the report the program writes, and prints the figure and every
`FAIL` line. Run on an **iPhone 4S running 6.1.3** on 2026-09-30 with `--control photosalbums8`:

    photosalbums8: 3 checks, 0 failed
    control: 1 checks, 1 failed   (the control failing, as it must)
    photos device: every program that ran passed

`photosalbums8` is the one program of the three that writes nothing, and a daemon is refused the photo library
by 6.1.3, so it runs on any device: the release's own enumeration fails with `ALAssetsLibraryErrorDomain`
-3311 "User denied access", and the port's album check answers that same error instead of "no such album". The
control is `tests/backports/device/photos/control.m`, which asserts the opposite of that check on the same
call in the same process and must fail; a run that does not see it fail is told its figures are not evidence.

**The two applications were not run on 2026-09-30**, because the iPad 2 was not attached: they add assets
to the library on every run, and the runner refuses them on any other device, since the photo library of a
device that is not the iPad 2 is the owner's. What was missing there was a device, not a test.

## The run of 2026-10-01, on the iPad 2

The iPad 2 was attached, and the five programs ran through the same runner, in one command:

    $ CHARON_DEVICE_HOLDER=photos-1 sh tests/backports/device/photos/run.sh \
          --device ipad2 --control photosalbums8 photosavailability13 photoschanges8 photosdata9
    photosalbums8: 3 checks, 0 failed
    photosavailability13: 11 checks, 0 failed
    photoschanges8: 22 checks, 0 failed
    photosdata9: 32 checks, 0 failed
    control: 1 checks, 1 failed
    photos device: 5 ran, 0 refused, every check that ran passed

`photoschanges8` gives the **22 checks, 0 failures** this page already claimed for 2026-09-23, from this
tree's sources, which is the corroboration that run was missing. `photosdata9` gives **32**, where the text
above says 34 measured on 2026-09-24 and 33 after one check was dropped. **That gap of one is not
explained here and is not rounded away**: the report on the device holds 32 `ok` lines and the figure line
says 32, the test's source is the same one main has (29 `CHECK` sites, two of which are inside functions the
program enters twice), and a reader comparing the two dates should read the reports rather than this page's
arithmetic. What the port answered is unchanged: 0 failures in every program.

## What that run found in the port

`photosdata9` died ten checks in with an uncaught exception on its first run of the day:

    FAIL uncaught NSInvalidArgumentException: -[NSURL fileSystemRepresentation]: unrecognized selector
         sent to instance 0x1cdbe0a0

`-[NSURL fileSystemRepresentation]` is a property of **iOS 7.0** -- `NSURL.h:118`, `API_AVAILABLE(macos(10.9),
ios(7.0), watchos(2.0), tvos(9.0))` -- and this port builds for 4.3 and 6.1.3, so six call sites in the
asset-resource code raised on the device: four in `PHAssetCreationRequest9.m` (a moved resource's own path, the
folder it must be removable from, the file a creation request stages a video's data in, and the moved file
itself) and two in `PHAssetResourceManager9.m` (the part file a chunked read writes, and the rename onto the
asked-for file). The seventh call was in the test itself, `photosdata9.m:263`, hard-linking a video. They go
through `-[NSURL path]`, which is of iOS 2, and from there `NSString`'s `-fileSystemRepresentation`, which has
no floor at all. With that, all 32 checks pass.

The index cannot settle this one, and the header explains why: `fileSystemRepresentation` reads first-rung
**3.0**, which is some other class's selector of that name in a 32-bit cache -- a name the ladder saw, an
attribution it does not carry. The header's own availability is the oracle for what a class declares.

The saved photos of iOS 6 do not keep the bytes they are given: a 726-byte JPEG written with
`writeImageDataToSavedPhotosAlbum:metadata:` and `nil` metadata reads back as 1929 bytes, measured the same with no port code on the
path. The resource and the resource manager hand back what the library stores — identical to a direct `ALAssetsLibrary` read of the
same asset — not the bytes given to the creation request.

An album name is unique on iOS 6: `addAssetsGroupAlbumWithName:` answers `nil` for a name already in use. A creation request whose
title is already the name of an album of the device, or of an album created earlier in the same change, fails the whole change with
`PHPhotosErrorChangeNotSupported` and a reason, when the requests are checked — before anything is written, so none of the change's
assets are left behind. Names are compared exactly: the release itself made an album whose name differs from an existing one only
in case. The code is the header's (3300, "The change request is not supported as configured"), the one this port
gives every change iOS 6 cannot make; what the system's Photos answers for a duplicate title was not measured, since this machine
has no Catalyst and the host's own Photos holds the owner's library. A name that collides only at the write, on something the check
does not see, still fails the change there, after the writes before it. When the release refuses to list the albums (an
application denied or restricted, or a library whose data is unavailable), the check has no answer, and the change fails there
with the release's own error (`ALAssetsLibraryErrorDomain`, -3311 "User denied access" for a denied process) instead of taking
the refusal for "no such album" and writing on; `tests/backports/device/photosalbums8.m` holds it on an iPad 2, in a daemon the
release denies. A fetch of albums, which has no way to report an error, is empty then, as it is for an application that may not
read, and the refusal is said in the log.
