# The persistent change family, iOS 16.0

Four class rows of `registry/Photos/absent_Photos.json` said only that "the class arrived in iOS 16, and nothing in iOS 6 does its work or stands in for it", and cited the SDK's own declaration. That is not a reason a reader can check. This page is the measurement: what the family is, what the release this port deploys on carries, and what that release says when its photo library changes. The four rows land `absent`, and the absence is proved here with a control in the same run.

## What the family is

One question: **what changed in the photo library since a moment the caller can name.** `-[PHPhotoLibrary currentChangeToken]` pins that moment, `-[PHPhotoLibrary fetchPersistentChangesSinceToken:error:]` answers with everything that happened since it, `PHPersistentChangeFetchResult` enumerates the answer, `PHPersistentChange` is one change in it, and `PHPersistentObjectChangeDetails` names the inserted, the updated and the deleted local identifiers of one object type.

The declarations, from the headers of the iOS 16.4 SDK (`Photos.framework/Headers/`):

| class | member | declared |
| --- | --- | --- |
| `PHPersistentChangeToken` | none: `NSObject <NSCopying, NSSecureCoding>`, `+new`/`-init` unavailable | `API_AVAILABLE(macos(13), ios(16), tvos(16))` |
| `PHPersistentChange` | `changeToken`; `-changeDetailsForObjectType:error:` | `API_AVAILABLE(macosx(13), ios(16), tvos(16))` |
| `PHPersistentChangeFetchResult` | `-enumerateChangesWithBlock:` | `API_AVAILABLE(macos(13), ios(16), tvos(16))` |
| `PHPersistentObjectChangeDetails` | `objectType`; `insertedLocalIdentifiers`, `updatedLocalIdentifiers`, `deletedLocalIdentifiers` | `API_AVAILABLE(macosx(13), ios(16), tvos(16))` |

A token with no member at all is the point of the family: the class *is* the moment, and its meaning lives entirely in what the library does with it later. This is iOS 16's second generation of the idea. The older family is a **different** class -- `PHChange`, of iOS 8, whose `-changeDetailsForObject:` is what `PHChange8.m` already carries -- and the spelling `changeDetailsForObject:` still reads first rung 8.0, which dates the selector's first holding and says nothing about which class owns it. What the 16.4 header declares for `PHPersistentChange` is the method of the shape column below.

## What the release this port deploys on carries

    REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua PHPersistent 6.1.3 4.3 12.0 16.0

```
6.1.3     $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming PHPersistent 0
         classes 11378, of which PHPersistent* 0
         protocols 1171, of which PHPersistent* 0
4.3       $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming PHPersistent 0
         classes 7187, of which PHPersistent* 0
         protocols 564, of which PHPersistent* 0
12.0      $HOME/.revenant/dyld/12.0/dyld_shared_cache_arm64
         images 1368, of which naming PHPersistent 0
         classes 63192, of which PHPersistent* 3 (PHPersistentChangeFetchRequest PHPersistentChangeFetchResult PHPersistentChangeToken)
         protocols 11426, of which PHPersistent* 0
16.0      $HOME/.revenant/dyld/16.0/dyld_shared_cache_arm64e
         images 2664, of which naming PHPersistent 0
         classes 143137, of which PHPersistent* 7 (PHPersistentChange PHPersistentChangeEnumerationContext PHPersistentChangeFetchOptions PHPersistentChangeFetchRequest PHPersistentChangeFetchResult PHPersistentChangeToken PHPersistentObjectChangeDetails)
         protocols 25549, of which PHPersistent* 0
control: 10 name(s) beginning PHPersistent found in this run, so a zero on another rung is the release's and not the reader's
```

(The tool prints each cache's absolute path; it is written as `$HOME` here, the repository's rule about
home paths.)

The zeros are on both ends this package deploys on, and the control is in the same run: 11378 classes and 524 images read out of 6.1.3, ten names found elsewhere. A zero for `PHPersistent*` there is the release's, not the reader's.

Neither band end has an image named Photos at all, and that is a run with a control too:

    REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua Photos 4.3 6.1.3 12.0

```
4.3       $HOME/.revenant/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming Photos 0
         classes 7187, of which Photos* 0
         protocols 564, of which Photos* 0
6.1.3     $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming Photos 0
         classes 11378, of which Photos* 0
         protocols 1171, of which Photos* 0
12.0      $HOME/.revenant/dyld/12.0/dyld_shared_cache_arm64
         images 1368, of which naming Photos 17
         classes 63192, of which Photos* 2 (PhotosAXGlue PhotosGraphTestsCommon)
         protocols 11426, of which Photos* 0
control: 2 name(s) beginning Photos found in this run, so a zero on another rung is the release's and not the reader's
```

12.0 is in that run for the control's sake, and its absence is the tool's own doing: the same command with
only the two band ends prints `CONTROL FAILED: no rung read carried a name beginning Photos, so this run
cannot show that the reader finds one; an absence from it is not evidence`. Photos came in iOS 8, so a
census of the two releases this package deploys on finds nothing anywhere, and a zero with nothing to
certify it is not a result. With 12.0 beside it, 17 images and two names, the zeros at 4.3 and 6.1.3 are
the releases'.

The `PH` prefix collides and the reader says which framework it came from -- the three `PH*` classes 6.1.3
carries are preference-bundle cells:

    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
      | awk -F'\t' '$2 ~ /^PH/ {print $2, $4}' | sort

```
PHSettingsNumberCell /System/Library/PreferenceBundles/MobilePhoneSettings.bundle/MobilePhoneSettings
PHSettingsNumberEditingController /System/Library/PreferenceBundles/MobilePhoneSettings.bundle/MobilePhoneSettings
PHSpinnerAndCheckmarkCell /System/Library/PreferenceBundles/MobilePhoneSettings.bundle/MobilePhoneSettings
```

The release's own photo library is in those 524 images, ten classes of it in `AssetsLibrary` and five in
`AssetsLibraryServices`:

    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
      | awk -F'\t' '$4 ~ /AssetsLibrary/ {n=$4; sub(/.*\//,"",n); print n}' | sort | uniq -c

```
     10 AssetsLibrary
      5 AssetsLibraryServices
```

## The whole of the release's photo library

The release's library is `ALAssetsLibrary`, and the 26 selectors below are all of it:

    REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
      | awk -F'\t' '$2 == "ALAssetsLibrary"' | tr ',' '\n' | sed 's/^/  /'

```
  class	ALAssetsLibrary	NSObject	/System/Library/Frameworks/AssetsLibrary.framework/AssetsLibrary	-_addGroupForAlbum:ofType:toArray:
  -_copyGroupForURL:
  -_libraryIsAvailable
  -_performBlockAndWait:
  -_writeImageToSavedPhotosAlbum:orientation:imageData:metadata:internalProperties:completionBlock:
  -_writeVideoAtPathToSavedPhotosAlbum:internalProperties:completionBlock:
  -addAssetsGroupAlbumWithName:resultBlock:failureBlock:
  -assetForURL:resultBlock:failureBlock:
  -dealloc
  -enumerateGroupsWithTypes:usingBlock:failureBlock:
  -groupForURL:resultBlock:failureBlock:
  -init
  -internal
  -isValid
  -publicErrorForPrivateDomain:withPrivateCode:
  -publicErrorFromPrivateError:
  -registerAlbum:assetGroupPrivate:
  -setInternal:
  -videoAtPathIsCompatibleWithSavedPhotosAlbum:
  -writeImageDataToSavedPhotosAlbum:metadata:completionBlock:
  -writeImageToSavedPhotosAlbum:metadata:completionBlock:
  -writeImageToSavedPhotosAlbum:orientation:completionBlock:
  -writeVideoAtPathToSavedPhotosAlbum:completionBlock:	-_library
  -authorizationStatus
  -disableSharedPhotoStreamsSupport	
```

It adds an image or a video to the saved photos, makes an album, enumerates albums, reads an asset by URL or by group, and answers whether the authorization is already decided. **Not one of them names a moment, a revision, a count or a change.** There is no token to take, no "since" to ask, and no history to read: the release keeps no account of its library as of any past time.

## What the release does say when the library changes

The one thing a 6.1.3 caller gets is a broadcast, and it is measured twice over.

    xmake l tools/cache-index/first-rung.lua ALAssetsLibraryChangedNotification ALAssetLibraryUpdatedAssetsKey

```
ALAssetsLibraryChangedNotification	4.0
ALAssetLibraryUpdatedAssetsKey	6.0
```

What it is, is in `Changes.md` ("Observing changes"), measured on an iPad 2 running 6.1.3 and held by `tests/backports/device/photoschanges8.m` (22 checks, 0 failures, 2026-10-01): the notification is posted once per write, by the library that wrote, off the main thread, naming in its user info what that write changed; and the first write of a process, before its library had read anything, arrives with an **empty** dictionary although an asset was added.

That is the whole of the release's account of a change, and each measured property is something the family needs and the release does not have:

- **it is a broadcast, not a record** -- there is no handle to keep, so nothing can pin a moment;
- **it is not queued** -- a listener that was not running when the write happened is never told, and the empty dictionary above is the release's own way of saying as much to a listener that was;
- **it is about one write** -- nothing asks it "since", and a caller hears only the writes it happens to be alive for.

## Where the family sits in the ladder

`tools/cache-index/first-rung.lua` over the 50 held rungs. First rung is PRESENCE, not version, and the ladder holds nothing between 12.0 and 16.0: 12.0 means "no held release before 12.0 carries it", and 16.0 means "after 12.0 and by 16.0", not a measured first release.

| name | first held rung |
| --- | --- |
| `_OBJC_CLASS_$_PHPersistentChangeToken` | 12.0 |
| `PHPersistentChangeToken`, `PHPersistentChangeFetchResult` | 12.0 |
| `PHPersistentChange`, `PHPersistentObjectChangeDetails` | 16.0 |
| `fetchPersistentChangesSinceToken:error:`, `enumerateChangesWithBlock:` | 12.0 |
| `changeDetailsForObject:` | 8.0 |
| `changeDetailsForObjectType:error:`, `insertedLocalIdentifiers`, `updatedLocalIdentifiers` | 16.0 |
| `deletedLocalIdentifiers` | 11.0 |
| `objectChangeDetailsForKey:` | NONE |

Three things follow, and none of them changes the four rows.

**The registry's `introduced` is the SDK's, and it is right to keep it.** All four rows read `introduced: "16"`, which is what `coordination/corpus/sdk-26.2-surface.tsv` -- the registry's own source -- says for all four, and what the 16.4 headers declare. The census above says two of the four class *symbols* are already held at 12.0, which the ladder cannot date: nothing is held between 12.0 and 16.0, so the release that first carried them is one of 12.0, 13.0, 14.0 or 15.0 and this machine cannot say which. What the 16.4 headers do say is that 16.0 re-declares both classes as `ios(16)` while the family's shape changes below -- which is why the SDK's number and the class symbol's first held rung are two different questions and neither is wrong. Recorded rather than smoothed over; the field is not corrected, because a row's `introduced` means what the SDK declares.

**The shape really is new at 16.0**, which is what makes these four rows the 16 family and not the older one. One `strings -a` pass over the arm64 cache of 12.0 with the seven patterns written out, so the command is the whole of it:

    printf '%s\n' changeDetailsForObject: changeDetailsForObjectType:error: enumerateChangesWithBlock: \
        insertedLocalIdentifiers updatedLocalIdentifiers deletedLocalIdentifiers ZZZNoSuchSelectorControl_photos16a \
        > /tmp/photos16a-pats.txt
    strings -a $HOME/.revenant/dyld/12.0/dyld_shared_cache_arm64 | grep -xF -f /tmp/photos16a-pats.txt | sort | uniq -c

```
      9 changeDetailsForObject:
      2 deletedLocalIdentifiers
      2 enumerateChangesWithBlock:
```

and nothing at all for `changeDetailsForObjectType:error:`, `insertedLocalIdentifiers`, `updatedLocalIdentifiers` or the control `ZZZNoSuchSelectorControl_photos16a`, whose absence is what certifies the three hits. (`grep -f -` reads the patterns from the pipe and runs out of memory on a stream this size, which is why the patterns go through a file.)

`deletedLocalIdentifiers` is the one number here a string's rung does not settle: it reads 11.0, a rung *older* than 12.0, so what 11.0 carries under that spelling is some other class's -- a selector, or a property name, which the same pass matches because Objective-C class metadata holds both -- exactly as `fileSystemRepresentation` reads 3.0 (`Changes.md`, "The run of 2026-10-01, on the iPad 2"). The header of 16.4 is the oracle for what this class declares; the census is the oracle for what a release holds.

**Two names of the family are in no SDK header at all**: `PHPersistentChangeEnumerationContext` and `PHPersistentChangeFetchOptions`, both in the 16.0 census and in neither the 16.4 headers nor `sdk-26.2-surface.tsv`. They carry no rows and this page makes none: a name the SDK does not declare is not this page's subject.

## Why a port-made token would be a different claim

The obvious way to carry this is the way `PHChange8.m` already carries `PHChange`: read the library again and diff. That works for `PHChange`, whose trigger is the release's own notification -- the port listens to `ALAssetsLibraryChangedNotification` and diffs whatever it is asked about. It does not work here, because the trigger is a **token the library hands out**, and a release that keeps no record of a moment cannot hand one out.

A port-made token could be a snapshot of the library's identity set at the moment it was asked for, and the change could be the diff between that snapshot and a fresh enumeration: a real computation over the real library, answering "what changed since I looked". But that is a **different claim under the same name**. The header says the token comes from the library and pins *its* point in time, and Apple's answer covers the writes the application was not running for, from the system's own journal. The port's snapshot covers only the moment the port itself chose, and is empty across every write the application slept through. A caller cannot tell the two apart from the API, which is what makes the first a fabricated answer rather than a divergence -- the same test `Changes.md` already applies to the live photo pair and to the album a token may not edit.

And on this port a caller could not reach one of these four objects anyway. The only producers are `-[PHPhotoLibrary currentChangeToken]` and `-[PHPhotoLibrary fetchPersistentChangesSinceToken:error:]`, and those two rows in `registry/Photos/ios8.json` are `absent`, with the reason "the release keeps no history of changes of the library" -- which is what the census above measures. `NSClassFromString` answers nil and an unchecked `-class` reference raises, so an implemented class that nothing can return is API surface no caller reaches. A band that defined these four while the two producers stayed `absent` would also fail the gate on its own terms: `check_registry` reports `listed as absent, but what is built answers it` for a name a band carries under a row that says `absent` (`modules/apple/backports.lua`, the `answered` list).

**Those two rows carry no `source` field at all; this page is the measurement that belongs under them.** They are not edited here: `registry/Photos/ios8.json` is not this band's slice, and whoever owns it is the one who can point them here.

## What would have to change for these rows to land implemented

Not the arithmetic: the port already computes the inserted, the changed and the removed of a fetch result in `PHChange8.m`'s `-changeDetailsForFetchResult:`. What is missing is a **record of a span of time in the release** -- a revision the library keeps, or a notification queued for a listener that was not there. Nothing in `AssetsLibrary.framework` of 6.1.3 or 4.3 offers either, and none of the 26 selectors above names one.

The rows land `absent`, and the claim is about the release: on 6.1.3 there is no token to take, no history to read and no way to ask "since", so nothing in the release answers any of the four names.

Source: the headers of the iOS 16.4 SDK for the declarations and their availability; `coordination/corpus/sdk-26.2-surface.tsv` for the `introduced` the registry carries; `REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua PHPersistent 6.1.3 4.3 12.0 16.0` and `... cache-census.lua Photos 4.3 6.1.3 12.0` for the two censuses and their controls; `REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua $HOME/.revenant/dyld/6.1.3/dyld_shared_cache_armv7` for the release's whole Objective-C metadata, the 26 selectors of `ALAssetsLibrary`, the three `PH*` preference-bundle cells and the image counts; `tools/cache-index/first-rung.lua` over the 50 held rungs for every first rung in the table above; one `strings -a` pass over the arm64 cache of 12.0 with the nonsense-selector control for the shape column; `Changes.md` ("Observing changes", and "The run of 2026-10-01, on the iPad 2") for what the release posts when the library changes, measured on an iPad 2 running 6.1.3.

What Apple's Photos of 16.0 answers for a token taken after a write the application never saw is **not** answered here. That needs a device whose Photos library holds assets and whose history is long enough to have dropped, which this machine has not; the question is not needed for any of these four rows, whose claim is about 6.1.3.