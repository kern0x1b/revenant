# The constants of the families this port does not carry

Eight `NSString * const` of the content editing, live photo and cloud identifier families are `absent`
in `registry/Photos/`, and each row's reason said only that "the constant arrived in iOS 8/9.1/11/15".
That is not a reason a reader can check and not a value: the port does not carry these families, and a
constant whose value nobody has read is a name. This page is the value, read out of a device's own
Photos.framework, and what it would take for each row to become `implemented`.

## The values, and where they were read

`tools/corpus/cache-value.lua` over `$HOME/.revenant/dyld/16.0/dyld_shared_cache_arm64e` -- a split
cache, a 393216-byte header and the bodies in `.01` ... `.44`, read through the port's own cache reader
(`modules/apple/dyld.lua`) because the address space of a split cache and the slide a stored pointer
carries are that code's business, not a second parser's. The tool prints, per symbol, the image that
exports it, the address, and the constant string the pointer in the symbol's storage names.

Not `tools/corpus/cache-value.lua`, which the queue header names for a C symbol's value: that tool reads a
**32-bit** Mach-O and refuses anything else ("not a 32-bit Mach-O"), and this device's 16.0 library is
arm64e, 64-bit, and split -- and no armv7 image of a release this port can run holds these names at
all, since the armv7 rungs of the held ladder stop at 9.3.6. So the eight values below are read by the
one tool that can read that image, and there is no second architecture here to cross-check them
against; what the run does check is internal, that the pointer in the symbol's storage names a string
whose bytes are NUL-terminated within the storage the next export bounds.

Every one of the eight is exported by `/System/Library/Frameworks/Photos.framework/Photos`:

| symbol | introduced | value | address |
| --- | --- | --- | --- |
| `PHContentEditingInputCancelledKey` | 8.0 | `PHContentEditingInputCancelledKey` | `0x1d5e7f7d8` |
| `PHContentEditingInputErrorKey` | 8.0 | `PHContentEditingInputErrorKey` | `0x1d5e7f7d0` |
| `PHContentEditingInputResultIsInCloudKey` | 8.0 | `PHContentEditingInputResultIsInCloudKey` | `0x1d5e7f7e0` |
| `PHLivePhotoInfoCancelledKey` | 9.1 | `PHLivePhotoInfoCancelledKey` | `0x1d5e7dcb8` |
| `PHLivePhotoInfoErrorKey` | 9.1 | `PHLivePhotoInfoErrorKey` | `0x1d5e7dca8` |
| `PHLivePhotoInfoIsDegradedKey` | 9.1 | `PHLivePhotoInfoIsDegradedKey` | `0x1d5e7dcb0` |
| `PHLivePhotoShouldRenderAtPlaybackTime` | 11.0 | **`LivePhotoShouldRenderAtPlaybackTime`** | `0x1d5e7fcc8` |
| `PHLocalIdentifiersErrorKey` | 15.0 | `PHLocalIdentifiersErrorKey` | `0x1d5e7f440` |

Seven of the eight are a string equal to their own name. **The eighth is not**: the option key of
`-[PHLivePhotoEditingContext prepareLivePhotoForPlaybackWithTargetSize:options:]` is
`LivePhotoShouldRenderAtPlaybackTime`, with no `PH` in front, which is why a port that writes
`@"PHLivePhotoShouldRenderAtPlaybackTime"` -- the guess every other one of these invites -- exports a
key no system dictionary is built with. The five keys `PHImageManager8.m` already carries were read in
the same run and each is a string equal to its own name, so what that file does is right for a reason
that can now be repeated.

```
$ REVENANT_ROOT=$PWD xmake l tools/corpus/cache-value.lua \
    $HOME/.revenant/dyld/16.0/dyld_shared_cache_arm64e symbols.tsv
#cache	arm64e	8
PHLivePhotoShouldRenderAtPlaybackTime	/System/Library/Frameworks/Photos.framework/Photos	0x1d5e7fcc8	30b8dfdf01002000	3755980848	9007207305689136	...	0x1dfdfb830	LivePhotoShouldRenderAtPlaybackTime	8	264
```

## The first held rung of each name

`tools/cache-index/first-rung.lua`, which answers presence and not the release a name was introduced
in, and which wants the name as the cache spells it -- for a C symbol the Mach-O underscore, since
`PHLivePhotoShouldRenderAtPlaybackTime` read `NONE` and `_PHLivePhotoShouldRenderAtPlaybackTime` read
`11.0`:

| name | first held rung | header's `introduced` |
| --- | --- | --- |
| `PHContentEditingInputCancelledKey` | 8.0 | 8.0 |
| `PHContentEditingInputErrorKey` | 8.0 | 8.0 |
| `PHContentEditingInputResultIsInCloudKey` | 8.0 | 8.0 |
| `PHLivePhotoInfoCancelledKey` | 9.1 | 9.1 |
| `PHLivePhotoInfoErrorKey` | 9.1 | 9.1 |
| `PHLivePhotoInfoIsDegradedKey` | 9.1 | 9.1 |
| `_PHLivePhotoShouldRenderAtPlaybackTime` | 11.0 | 11.0 |
| `PHLocalIdentifiersErrorKey` | 16.0 | 15.0 |

The 15.0 row reads 16.0 because the held set has no rung between `12.0` and `16.0` -- the arm64e rungs
above 12.0 are `16.0` and `18.0` -- so the oldest held release that carries the name is one above the
release that introduced it. That is the tool's own rule and not a disagreement with the header.

## The classes of the same families, and what the release says about them

The keys above are not the only absent rows of their families, and the reason is the same one, so it is
written once here and each row carries the part of it that is about that row.

**A live photo, and everything shaped like one** -- `PHLivePhoto` (9.1), `PHLivePhotoRequestOptions`
(9.1), `PHLivePhotoEditingContext` (10), `PHLivePhotoFrame` (10). A live photo is a still image and a video
carrying Apple's paired-media metadata. The release's own photo library has no such thing, and three
measurements say so rather than a header's silence: the word `live` is in no header of its
`AssetsLibrary.framework` (`grep -rin live` over the 16.4 headers, no match); `ALAssetsLibrary` can add a
photo and can add a video, and nothing in it pairs the two, which is the same limit the port's own
`+[PHAssetCreationRequest addResourceWithType:fileURL:options:]` is written against (a resource type other
than photo or video fails the change with a reason -- `facts/Photos/Changes.md`); and the first held rung
that carries `PHLivePhoto` at all is **9.1**, so no release these bands are built for has anything that
would recognise a pair this port invented. A `PHLivePhoto` the port handed out would be two files Apple's
own software does not read as one object, which is the fabricated answer the tree forbids -- so the rows
stay absent and the effect says so.

**A collection list, and the change request on one** -- `PHCollectionListChangeRequest` (8). The release's
albums are one flat level. The only way it makes an album is
`-[ALAssetsLibrary addAssetsGroupAlbumWithName:resultBlock:failureBlock:]` (`ALAssetsLibrary.h:105`, measured
by first-rung at **5.0**), which takes no parent, and `grep -rn parent` over the 16.4
`AssetsLibrary.framework` headers finds one hit: a comment about parental controls. There is no list to put
a collection in and no album to put one inside, so this release's "collection list" is the list of the
albums themselves -- and `+creationRequestForCollectionListWithTitle:` has nothing to create,
`+deleteCollectionLists:` has nothing to delete, and every child-collection member has no child to act on.

One spelling worth recording, because it nearly became a claim: `addAssetsGroupWithName:parentGroup:resultBlock:failureBlock:`
is not an `ALAssetsLibrary` selector at all. The index read `NONE` for it, the 16.4 header does not declare
it, and what the release does have is the flat `addAssetsGroupAlbumWithName:` above. The index's `NONE` is
corroboration and not proof -- it read `NONE` for `groupsForAssetGroupType:`, which the 16.4 header also
does not declare -- so the row rests on the header and on the measured first rung of the selector the
release does have.

## Why the keys stay `absent`

An `absent` row's claim is about the **release**, not about the port: what iOS 6 does not have is in
each row's `reason`, and each of the three families is named there in the release's own terms -- no
content editing at all, no live photo it can pair, no iCloud container and no cloud identifier. What
follows is the other half, and it is not a row: what the port would have to build for the key to become
`implemented`, because a constant is landed when the thing that produces or consumes it exists, and a
key nothing builds a dictionary with is a name with the right value and no user.

- **Content editing (8.0).** The three keys are the keys of the info dictionary
  `-[PHAsset requestContentEditingInputWithOptions:completionHandler:]` hands its result handler, and
  that request is not in the registry at all. It becomes implementable over the port's own store: the
  asset's full-size image is readable through the same `ALAssetRepresentation` the image manager
  already uses, and the output is a file the change block writes back as a new asset. The keys land
  with it.
- **Live photos (9.1 and 11.0).** The three info keys belong to
  `+[PHLivePhoto requestLivePhotoWithResourceFileURLs:placeholderImage:targetSize:contentMode:resultHandler:]`
  and the option key to the live photo editing context. A live photo is a still image and a video
  carrying Apple's paired-media metadata, and iOS 6 has neither the reader for that metadata nor a
  Photos application that would use it: `ALAssetsLibrary` can add a photo and a video and cannot pair
  them, and no release this port supports exposes the pairing. `PHLivePhoto` is therefore not carried
  and cannot be, and the keys stay with it.
- **Cloud identifiers (15.0).** `PHLocalIdentifiersErrorKey` is a key in the `userInfo` of the error
  `-[PHPhotoLibrary localIdentifierMappingsForCloudIdentifiers:]` reports when a cloud identifier
  matched **more than one** resource (`PHPhotosErrorMultipleLocalIdentifiersFound`, 3202). A release
  with no iCloud container can match nothing at all, so that user info has no producer here whatever
  else the 15.0 family does. The other three 15.0 rows are implementable and are not blocked by this.

Source: the header of iOS 16.4 for the declarations and the codes; `tools/corpus/cache-value.lua` over
the arm64e cache of 16.0 for every value and every address above, which is the device's own Photos and
not the host's library; `tools/cache-index/first-rung.lua` over the 50 held rungs for the presence
column. What Apple's Photos *does* with these keys, and what a system library answers for an
identifier it has never seen, is a separate question and is not answered here.
