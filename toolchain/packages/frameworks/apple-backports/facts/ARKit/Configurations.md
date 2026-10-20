# The configurations: what the release's own metadata answers, and what the hardware does not

The 36 rows of `coordination/corpus/ledger-2026-10-03/ARKit.tsv` that belong to a class this tree
carries and no file of `registry/ARKit` named. Every row here is decided by one of two measurements,
and which one is named in the row.

## The two releases everything is read out of

| release | file | what it decides |
| --- | --- | --- |
| ARKitCore of the arm64e shared cache of **iOS 16.0** | `~/.revenant/dyld/16.0/dyld_shared_cache_arm64e`, read only, in process | which accessors the release's class really has, and which of them are class methods |
| the armv7 shared caches of **iOS 6.1.3** and **iOS 4.3** | `~/.revenant/dyld/6.1.3/`, `~/.revenant/dyld/4.3/` | what the port's own bands run on: 0 of their classes and 0 of their selectors is anything ARKit |

Both are read with this repository's own readers (`tools/corpus/skeleton-table.lua`,
`tools/corpus/objc-inventory.lua` through `modules/apple/dyld.lua` and `modules/apple/objc.lua`). No
`ipsw`. Nothing outside this worktree was written.

### The 16.0 class method lists

`skeleton-table.lua impls <class>` prints each class's instance list and its **metaclass's** list,
each with its own header, because an instance list says nothing about a class method. Seven lists
answered here, and every accessor address a row names came out of one of them:

| class | instance list | entries | class list | entries |
| --- | --- | --- | --- | --- |
| `ARConfiguration` | `0x1af2140d8` | 61 | `0x1af214018` | 15 |
| `ARWorldTrackingConfiguration` | `0x1af215e88` | 86 | `0x1af215dc0` | 16 |
| `ARBodyTrackingConfiguration` | `0x1af2198a8` | 39 | `0x1af219828` | 10 |
| `ARFaceTrackingConfiguration` | `0x1af2138c8` | 19 | `0x1af213808` | 11 |
| `ARVideoFormat` | `0x1af214578` | 28 | `0x1af2144b0` | 16 |
| `ARPlaneAnchor` | `0x1af218400` | 33 | `0x1af2183c8` | 2 |
| `ARImageAnchor` | `0x1af21c010` | 15 | `0x1af21bff8` | 1 |
| `ARSession` | `0x1af219178` | 133 | `0x1af219118` | 7 |

All eight are `entsize_and_flags = 0xc000000f`: small twelve-byte entries with direct selectors, which
is the layout ARKitCore uses throughout. Every list here **resolved and printed its selectors**, which
is the control that a read which found nothing would print no table at all.

### The 6.1.3 and 4.3 answers, and the controls that make them answers

`objc-inventory.lua` over each armv7 cache: 11 378 classes and 1171 protocols in 6.1.3, 7187 and 564 in
4.3. **0** of them begin `AR`; 0 contain `Depth`, `TrueDepth`, `LiDAR`, `SceneDepth`, `Tracked` or
`ARKit`; and every selector these 36 rows are about is in none of their own method lists, instance or
class.

A search that answers "in none" everywhere is exactly what a broken search answers, so the controls
are stated with it:

| what the same read was asked | 6.1.3 | 4.3 |
| --- | --- | --- |
| `AVCaptureDevice` | present, 100 instance and 5 class methods | present |
| `CMMotionManager` | present, 74 instance methods | present |
| `NSObject` | 590 instance and 104 class methods | - |
| `UIView` | 597 instance and 66 class methods | - |
| `-init` | in 2551 class lists | 1644 |
| `-copyWithZone:` | in 824 class lists | - |
| `+defaultDeviceWithMediaType:` on `AVCaptureDevice` | in its own class list | - |
| `+alloc`, `+new` on `NSObject` | in its own class list | - |

**One reading of this inventory was wrong first and is worth recording**, because it is the same shape
as the mistake the wave brief names. `objc-inventory.lua` prints each class's selectors as the reader
stores them, and the reader stores every selector with a single leading `-` and **no sign** - the
class-method column of `NSObject` begins `-CA_addValue:multipliedBy:` and contains `-alloc`, not
`+alloc`. Searching for `+alloc` therefore answered 0 in every class of both caches, and searching for
`-initWithName:transform:` answered 0 although `NSObject` plainly has an `-init`. Every count in this
page is from the corrected search; the sign is the reader's, not the ARM's, and the table above is
what shows the corrected one can see.

## What the release's lists decided

**Four rows decided by an accessor the class does not have.** `-initWithName:transform:` and
`-initWithTransform:` are marked `NS_UNAVAILABLE` on `ARPlaneAnchor` and `ARImageAnchor`, which by the
coordinator's ruling for v-uikit2 obliges nothing; the metadata decides, and it says neither class has
either: 33 entries and 15 entries, and neither selector among them. All four rows are `absent`, and what
a call reaches is `ARAnchor`'s own `-initWithName:transform:`, which is what reaches on the release too.

**Five rows decided by a `getter=`.** The property name is not the selector, and in every one of these
five the ledger row's own reason names the property rather than the getter:

| row | header | selector the release carries |
| --- | --- | --- |
| `ARPlaneAnchor.classificationSupported` | `ARPlaneAnchor.h:93` `getter=isClassificationSupported` | `+isClassificationSupported` at `0x1af14f89c`, one of `ARPlaneAnchor`'s two class methods |
| `ARVideoFormat.videoHDRSupported` | `ARVideoFormat.h:47` `getter=isVideoHDRSupported` | `-isVideoHDRSupported` at `0x1af0f4870` |
| `ARWorldTrackingConfiguration.collaborationEnabled` | `ARConfiguration.h:298` `getter=isCollaborationEnabled` | `-isCollaborationEnabled` at `0x1af085d00` (the row is `absent`) |
| `ARFaceTrackingConfiguration.worldTrackingEnabled` | `ARConfiguration.h:396` `getter=isWorldTrackingEnabled` | `-isWorldTrackingEnabled` at `0x1af0e8728` |
| `ARWorldTrackingConfiguration.supportsAppClipCodeTracking`, `supportsUserFaceTracking`, `+supportsSceneReconstruction:`, `+supportedNumberOfTrackedFaces`, `+supportsWorldTracking` | class properties and class methods | `0x1af11b384`, `0x1af0958a4`, `0x1af11b140`, `0x1af0e7464`, `0x1af0e70ec` |

**Three rows are 26.0 and nothing here can measure them.** `ARVideoFormat`'s 28 instance methods and 16
class methods in the 16.0 cache carry neither `defaultColorSpace` nor `defaultPhotoSettings`, and
`ARSession`'s 133 instance methods do not carry
`-captureHighResolutionFrameUsingPhotoSettings:completion:` - the nearest is
`-captureHighResolutionFrameWithPhotoSettings:completion:` at `0x1af1611e4`. The newest release this
workspace holds a cache of is 16.0, so for these three the *absence in the 16.0 list* is also the
absence in every release whose metadata can be read here, and the rows are `absent` with that stated
rather than a value invented.

## What the port's own code decided

**The session reads no setting at all.** `-[ARSession runWithConfiguration:options:]`
(`ARKit/ARSession.m:77-91`) is the whole of how a session is started, and it reads the configuration
for `[[configuration class] isSupported]` and for the two run options and for nothing else.
`RevenantARTracker.h` - the tracker's entire interface - names no member that takes a configuration, a
map, an image, a skeleton or an environment probe. That one measurement is what makes the twelve
`absent` rows absences rather than gaps, and it is why `@dynamic` is the honest spelling for them: with
the line removed, clang synthesises the pair of accessors from the SDK header's own property, and they
store the value and return it while the session runs on from nothing.

**Two settings that need no sensor were `@dynamic` and should not have been.**
`ARBodyTrackingConfiguration.detectionImages` and `.maximumNumberOfTrackedImages` were declared
`@dynamic` on the reasoning that the tracker reads neither - which is true - and that therefore nothing
needed them. But the reason `ARWorldTrackingConfiguration`'s two rows of the same names are
`implemented` (measured, in `registry/ARKit/ios11.json`) is not that the tracker reads them: it is that
**nothing about them needs a sensor this device lacks.** The pictures to look for are found in the
camera's own frames and how many at once is a number the caller sets. Both are now implemented in
`ARKit/ARConfiguration4.m`, in the same shape as their 13.0 sibling, and their rows say what the
tracker does with them, which is nothing.

**Two settings were left to clang's synthesis and were storing values nothing read.**
`-frameSemantics` and `-videoHDRAllowed` were auto-synthesised, so a caller could set a scene-depth
semantics or an HDR flag and read both back while `ARSession.m` ran no classification and the camera
delivered no HDR. They now answer `ARFrameSemanticNone` and `NO`, with setters that say so, which is
the same shape `-isAutoFocusEnabled` / `-setAutoFocusEnabled:` already uses in `ARConfiguration2.m`
for the setting the hardware *does* have. `-copyWithZone:` lost its `copy.frameSemantics` line with
them, because copying a constant is not copying anything.

## RETRACTED: there is no auto-synthesised `automaticImageScaleEstimationEnabled` on the third configuration

An earlier version of this page reported a defect: that
`ARImageTrackingConfiguration.automaticImageScaleEstimationEnabled` gets an auto-synthesised accessor
in `ARKit/ARConfiguration3.m`, storing and returning whatever the caller set, while the same setting
is `@dynamic` on the other two configurations. **That was wrong, and the compiler says so.**

The property is not declared on `ARImageTrackingConfiguration` at all. In the 16.4 build SDK's
`ARKit.framework/Headers/ARConfiguration.h` it is declared three times, and on three *different*
classes:

| line | enclosing `@interface` | the declaration |
| --- | --- | --- |
| 275 | `ARWorldTrackingConfiguration` | `@property (nonatomic, assign) BOOL automaticImageScaleEstimationEnabled API_AVAILABLE(ios(13.0));` |
| 524 | `ARBodyTrackingConfiguration` | `@property (nonatomic, assign) BOOL automaticImageScaleEstimationEnabled;` |
| 629 | `ARGeoTrackingConfiguration` | `@property (nonatomic, assign) BOOL automaticImageScaleEstimationEnabled;` |

`ARImageTrackingConfiguration`'s own interface in that header does not declare it, so clang had
nothing to synthesise from. Adding `@dynamic automaticImageScaleEstimationEnabled;` to
`ARKit/ARConfiguration3.m` to test the claim is what settled it, and the answer is the compiler's:

```
packages/frameworks/apple-backports/ARKit/ARConfiguration3.m:82:10: error: property implementation must
have its declaration in interface 'ARImageTrackingConfiguration' or one of its extensions
   82 | @dynamic automaticImageScaleEstimationEnabled;
```

That edit is not in the tree. The release agrees: `ARImageTrackingConfiguration`'s own instance list
in ARKitCore of the arm64e shared cache of iOS 16.0 is **ten** twelve-byte entries and none of them is
`automaticImageScaleEstimationEnabled` (list `0x1af214430`, read with
`tools/corpus/skeleton-table.lua impls ARImageTrackingConfiguration`), while the two that do declare it
carry the accessor at named addresses: `0x1af11bf90` in `ARWorldTrackingConfiguration`'s own list of
eighty-six and `0x1af168518` in `ARBodyTrackingConfiguration`'s own list of thirty-nine (and
`0x1af168538` for that class's `automaticSkeletonScaleEstimationEnabled`). The ten entries it does
have are `.cxx_destruct`, `description`, `init`, `isEqual:`, `copyWithZone:`,
`createTechniques:`, `setMaximumNumberOfTrackedImages:`, `trackingImages`, `setTrackingImages:` and
`maximumNumberOfTrackedImages`.

So the three configurations that declare the setting are all `@dynamic` in this port, and the one that
does not declare it never answered it. There was no defect to fix, and the coordinator's request to
"make it answer honestly on all three configurations" is answered by the measurement rather than by a
commit: it already answers honestly everywhere it exists.

## Still not reopened

`ARWorldTrackingConfiguration.environmentTexturing` is an `implemented` row that stores a value nothing
builds a texture from: there is no `AREnvironmentProbeAnchor` in this tree and no member of
`RevenantARTracker.h` that takes a probe. It was decided and landed before this series, so it is
recorded here rather than changed by a series that was not asked about it.

## The harness

There is no host oracle for any of this: this Mac's `ARKit` has no `ARWorldTrackingConfiguration`, no
`ARReferenceObject` and no `ARSession` (see `facts/ARKit/PlaneExtent.md` for the run and its control),
so nothing here is compared with a host answer. What checks the code is the light guard over
`tests/backports/host`, the release check over the objects, and `tools/registry-shape.lua` over the
registry - which is why the rows carry their measurement in `reason` and `source` rather than a claim
of agreement.