# Backport tests

## Host

Differential tests against the host's own classes. Each script compiles the
backports for macOS (UIKit ones through Mac Catalyst) with every class they
define renamed, and compares the result with the system class on the same
inputs.

A test that stops linking is the worst thing that can happen here, and the
hardest to see. Every script runs under `set -eu`, so a missing framework or a
renamed symbol ends it at its first `clang` call: it never reaches a check, and
from the outside it is indistinguishable from a test nobody happens to have run
lately. It keeps its line in this file, so it goes on looking like cover while
it guards nothing. That is how `host/uikit2/run.sh` - appearances, menus,
pointer, search, colors, symbols, layout values, the compositional layout and
the foundation14 groups - stood dead from the change that broke it until
someone happened to run it: a commit appended a second `frameworks=` line to
add one flag and dropped `-framework MobileCoreServices` in the copy, and the
second assignment quietly won. `host/foundation2/run.sh` went the same way when
a method moved to a new file that its source list does not name. So, before
trusting any of these:

    sh host/run-all.sh [--seconds N] [NAMES]

It starts every script and asks one question of each: did it get past building
itself? A script that FAILS without reaching a single check is reported DEAD
with the last lines of its error; one still running when the clock runs out is
alive, because a link that fails fails in seconds, and one that ends with status
0 is alive because it got to its own end. The few it cannot start - the ones
that take arguments, a server or a tool of their own, and the recorder that
writes expectations rather than checking - are named with the reason, never
passed over in silence. It says nothing about whether the checks pass, only
whether they happen, and it exits non-zero if anything is dead.

It runs the real scripts, so the ones that write an expectations header write it
again: look at `git status` afterwards, and note that `host/ios1516/run.sh` puts
freshly made UUIDs in its header on every run.

    sh host/url/run.sh
    sh host/session/run.sh      starts host/session/server.py on a free 127.0.0.1 port
    sh host/coremedia7/run.sh   holds CoreMedia's arithmetic and its sample buffers to the host's own: CMTimeMultiplyByRatio
                                over 700k answers, CMSampleBufferCopyPCMDataIntoAudioBufferList over 90k, and the ready-creating
                                and per-sample sample buffers over 143. Each must be the same wherever the claim in
                                registry/CoreMedia/ios7.json and ios8.json holds, and the corners outside it are measured
                                against the exact value and written down in facts/CoreMedia/; and constants.m holds 74 of
                                CMFormatDescription.h's 75 CFString keys to the host's own bytes
                                (facts/CoreMedia/FormatDescriptionConstants.md); and tagcollectionimage.m holds
                                CMTagCollection's 23 functions to the host's own, the port's file built as its own
                                image and reached through dlopen, 208 answers, none different
                                (facts/CoreMedia/TagCollection.md)
    sh host/arkit-nsobject-init/run.sh  the 63 -init and +new rows of the carried ARKit and SensorKit classes: on the host each selector is the superclass's own IMP and the class defines none; the port's sources define none of them (facts/ARKit/NSObjectInit.md)
    sh host/arkit-instance-new/run.sh  the instance -new of ARRaycastQuery, ARRaycastResult and ARTrackedRaycast: the SDK declares each NS_UNAVAILABLE from iOS 13.0, and the Catalyst ARKit defines none and raises unrecognised-selector on a call; the port does the same
    sh host/arkit-absent-classes/run.sh the thirteen data and skeleton classes of ARKit and SceneKit (ARBody2D, ARSkeleton and its 2D and 3D kinds, ARMeshGeometry, ARFaceGeometry, ARReferenceObject and the rest) against the host's own: superclass, the iOS SDK's property names with the host's types, a fresh object's values (facts/ARKit/AbsentClasses.md)
    $HOME/Git/projects/ios/coordination/heavy.sh sh device/arkit-config/run.sh  the stored settings of the world and body configurations on the 6.1.3 emulator (`xmake emulate`), and the body configuration refused by a session through session:didFailWithError:; facts/ARKit/ConfigurationSettings.md
    sh host/arkit-sensorshells/run.sh   the six sensor-data classes of ARKit (ARDepthData, ARFaceAnchor, AREnvironmentProbeAnchor, ARMeshAnchor, ARObjectAnchor, ARDirectionalLightEstimate) against the host's own ARKit on Mac Catalyst: superclass, protocol, declared properties by name and type, and the probe's constructors
    sh host/gamecontroller/run.sh   the port of the GameController model against the host's GameController, 8576 lines
    sh host/alert/run.sh
    sh host/layout/run.sh
    sh host/foundation2/run.sh  writes device/foundation2-expectations.h when it passes
    sh host/uikit2/run.sh
    sh host/keyedarchive11/run.sh  writes device/keyedarchive11-expectations.h when it passes
    sh host/foundation11/run.sh    writes device/foundation11-expectations.h when it passes
    sh host/rangewithname/run.sh
    sh host/validatedformat/run.sh [pairs] [seed]
    sh host/validatedformat/run.sh --mutants [pairs] [seed]
    sh host/fuzz/run.sh percentencoding|stringcase|calendar [rounds] [seed]
    sh host/directionaledges/run.sh  writes device/directionaledges-expectations.h when it passes
    sh host/directionalmargins/run.sh
    sh host/contentsize/run.sh
    sh host/fontmetrics/run.sh
    sh host/systemspacing/run.sh
    sh host/gesturename/run.sh
    sh host/rendererformat/run.sh
    sh host/batchupdates/run.sh
    sh host/interactions/run.sh
    sh host/traitstyle/run.sh
    sh host/animatorscrub/run.sh
    sh host/usernotifications/run.sh  writes device/usernotifications-expectations.h when it passes
    sh host/coredata/run.sh
    sh host/probes/run.sh
    sh host/swipeactions/run.sh
    sh host/registry/run.sh <dyld_shared_cache_armv7>
    sh host/spring/run.sh  writes device/spring-expectations.h when it passes
    sh host/ypcbcr/run.sh  the 420 Y'CbCr conversions and the four pixel conversions of iOS 7 against the host's own vImage
    sh host/blocks/run.sh
    sh host/textcontent/run.sh
    sh host/avcapture/run.sh
    sh host/oslog/run.sh  writes device/oslog-expectations.h when it passes
    sh host/homeindicator/run.sh  writes device/homeindicator-expectations.h when it passes, then holds the port's categories to it with mutants
    sh host/mlcompute/run.sh  asks the host's own MLCompute and the port's the same 377 questions and compares the two answers line by line
    sh host/mlcompute/measure.sh  asks the host's own MLCompute what it computes and what its layer factories keep, and writes the answers to a file; neither program is a test, they record
    sh host/vision/run.sh  writes its record to the run folder; RECORD=1 sh host/vision/run.sh writes device/vision-expectations.h (the committed record, changed only by such a commit), then holds the port's Vision classes, under names of their own, to it with mutants. It needs the Core ML containers in MODELS (default .agent-work/runs/coreml-models-2), and without them the picture cases do not run: the run now refuses to report anything and says which path is missing. It records 45 keys with the ten containers and fails if it records fewer. It also fails, before any verdict, on a container the cases name failing to compile when no case expects it to (the one that is expected, vision_image, is listed with its reason in device/vision-cases.m at compile_failure_expected), and on a home path in the record it wrote, because that file is committed and a framework error message is not stable across machines. The corpus is also checked for the containers the cases name, and it fails BY NAME before the record is written if one is missing: a container that is absent and a container that is present but cannot be run both record 45 keys and differ on one value (picture/error), so the count cannot tell them apart. vision_image is the one a case expects to fail, and it is expected to be PRESENT and to fail
    sh host/vision/run-crop.sh  asks Core ML's own image constructor for the same crop-and-scale rules the port implements, for five picture and target pairs under both rules and all three interpolation qualities, compares the pixels, and mutants the geometry
    sh host/vision-constants14/run.sh  the 82 string constants iOS 14 added to Vision (the pose keys, joint and group names, the video options) against the host's own Vision, byte for byte, with a plant that must be seen; the values are macOS 27.0.1's (facts/Vision/Constants14.md says what that does not prove)
    sh host/vision-coordinates15/run.sh  the coordinate conversions iOS 14 and 15 added to Vision (VNNormalizedPointForImagePoint, the four region-of-interest conversions) and the six barcode symbologies of iOS 15, against the host's own Vision, 566 answers to 17 digits, with a plant that must be seen (facts/Vision/Coordinates.md and Constants15.md say what the host does not prove)
    sh host/vision-results14/run.sh  the header-declared surface of VNDetectedPoint and VNRecognizedPoint against the host's Vision, member by member: the superclass, the encodings of the methods and the attributes of the properties, the NS_UNAVAILABLE initialisers included
    sh host/vision-contours14/run.sh  the contour classes of Vision iOS 14 added (VNContour, VNContoursObservation) and VNDetectContoursRequest against the host's Vision: the declared surface, and the contours of seven drawn pictures, numbers to 1e-5; the sibling order and grey pictures are not reproduced (facts/Vision/Contours14.md)
    sh host/coreml/run.sh  the port's Core ML -- the value types, the descriptions and their constraints, the providers, the model, the keys and the exported constants -- against a real Core ML on this host, over the containers tools/coreml/make-models.lua writes: every description, every constraint, -isAllowedValue: over a battery of values, the providers, the keys, the options, the constants and a prediction per model, then eighteen mutants, none of which may survive. The system run compiles each container with the framework's own compiler first, because this host's Core ML refuses to read an uncompiled .mlmodel. It is green on NINE of the ten containers make-models.lua writes: the tenth, vision_image, is the one make-models.lua reports as 'no host input', and with it present the run prints 'compared 770 keys, 0 differ, 48 missing' and 'port: DIFFERS'. The run prints which corpus it was given on its first line
    sh host/coreml-unavailable-init/run.sh  the five Core ML classes whose headers declare -init and +new NS_UNAVAILABLE (MLKey, MLMetricKey, MLParameterKey, MLModelAsset, MLImageConstraint): the selector's implementation on the host's Core ML and on the port, line for line, with a control and a plant
    sh host/vision-human15/run.sh  VNHumanObservation (15.0): its surface read by the reflection probe, and what a fresh object answers on the host and in the port (upperBodyOnly NO, a zero bounding box, confidence 1), with a plant that must be seen
    sh host/vision-init11/run.sh  the initialisers of the iOS 11 Vision classes the headers mark NS_UNAVAILABLE (nine classes: -init and +new; five: -initWithCompletionHandler:), answer for answer against the host, line for line, with a plant that must be seen
    sh host/coreml-collection14/run.sh  MLModelCollectionDidChangeNotification, the one constant of the iOS 14 model-collection family: its value on the host's Core ML (read through dlsym, the SDK stub does not export it) and in the port's MLModelCollection14.m, with a plant that must be seen
    $HOME/Git/projects/ios/coordination/heavy.sh sh host/coreml/emulate.sh  the same surface on the device: libCoreMLBackports linked, the containers embedded in device/coreml-models.h, and every method the registry claims called at least once (emulate.sh, one heavy job)
    sh host/traits11/run.sh  writes device/traits11-expectations.h when it passes, then holds the port's text input traits, password rules and view flag to it with mutants
    sh host/callkit/run.sh  writes device/callkit-expectations.h, then holds the port's CallKit classes, under names of their own, to it with mutants
    sh host/insetref/run.sh  writes device/insetref-expectations.h when it passes, then holds the port's flow layout to it with mutants
    sh host/imageflip/run.sh
    sh host/markdownsourceposition/run.sh  holds NSAttributedStringMarkdownSourcePosition to the host's own, 47 checks: the four numbers, the copy, equality, the archive's keys with their values and the range over the 29 runs the host's own parser marks
    sh host/ios1516/run.sh  writes device/ios1516-expectations.h when it passes
    sh host/cachereader/run.sh <dyld_shared_cache> <image> <class> <selector>
    sh host/orderedcollections/run.sh  writes device/orderedcollections-expectations.h
    sh host/diffable/run.sh  writes device/diffable-expectations.h
    sh host/pasteboard10/run.sh  writes device/pasteboard10-expectations.h
    sh host/previewing/run.sh  writes device/previewing-expectations.h
    sh host/contacts/run.sh  writes device/contacts-expectations.h, then holds the port's Contacts classes, under names of their own, to it with mutants
    sh host/spotlightstore/run.sh  builds the port's CoreSpotlight and the search bundle's reading of its store on the host: a refused write, a store holding entries no application should write, and mutants of both
    sh host/dynamics/run.sh  the port's UIKit Dynamics, under names of their own, beside the host's own animator; host/dynamics/mutants.sh holds the tests to their negative controls
    sh host/air2es/run.sh    builds tools/air2es against the llvm package and needs glslangValidator
    sh host/scenekit/run.sh  writes device/scenekit-expectations.h: macOS SceneKit's matrix functions, node rotations and SCNView defaults
    sh host/scenekit/frames.sh <scenes> <frames>  device/scenekit-frames.m's snapshots of Telegram's star2 and coin against macOS SceneKit's frames, and a renderer a little wrong beside them (no bound yet)
    sh host/scenekit/lighting/run.sh  reproduces the fits of SceneKit's lighting models that SceneKit/RevenantSCNRenderer.m draws with
    sh host/scenekit/lighting/cases.sh  writes device/scenekit-lighting-expectations.h: macOS SceneKit's pixel for 1422 lighting cases, and a known-wrong renderer's for the roughness control of device/scenekit-lighting.m
    sh host/scenekit/animation/record.sh <dir>  macOS SceneKit's series of Telegram's animations (gradient and shimmer over srgblevels.swift's levels, and over Metal's own as -metal); compare.py <dir> <device-dir> holds device/scenekit-animation.m's to them and reports the -metal ones
    host/scenekit/animation/mipmaps.swift | (fitmipmaps.py, deleted with no caller left)  what Metal's mip levels of an sRGB texture hold and how SceneKit samples them, against srgblevels.swift's rule (the port's), the models before it and GL ES 2.0's
    host/scenekit/animation/givenlevels.swift  whether SceneKit samples the levels of an MTLTexture it is given or makes its own
    sh host/uuid/run.sh  holds `NSUUID` of `Foundation/NSUUID.m`, the class the backports carry below iOS 6.0, to the host's own: parsing, equality, hash, description, archives (damaged ones too), nil arguments and a subclass of the cluster; it fails under three mutants
    sh host/maptable6/run.sh  holds the port's four NSMapTable factories of iOS 6.0 to the host's own; host/maptable6/emulate.sh runs the same test as a device binary on 6.0, 4.3, 5.0 and 5.1.1 (one heavy job), control.sh its negative control (a port without the runtime's weak references, which must fail) and probes.sh the enumeration and __weak probes the facts cite (a heavy job each)

`host/air2es/run.sh` assembles the AIR fixtures written for the test (a vertex function that reads its buffer by vertex
identifier, one that takes its inputs from a vertex descriptor, a fragment function that samples a texture, one with a loop and branches, and one with a second render target), wraps them as a library, runs
`metallib2es.lua` over it, compares the shaders and the reflection with `expected/quad/` (`REVENANT_WRITE_EXPECTED=1` rewrites
them), has glslang validate both shaders as ES 1.00, and holds the second render target to its refusal.

`device/metal.m` is the device test of Metal's render API over OpenGL ES 2.0, an application: it needs the folder `quad.metallib.es2` in its bundle, which is
`host/air2es/expected/quad` under that name (`app.resources`). It makes the device, reads the library, draws the fixture's two functions into a texture with `drawPrimitives` and
with `drawIndexedPrimitives`, reads the pixels back and compares them with what the fixture computes, blends, draws into the drawable of a `CAMetalLayer`, and holds
what the port cannot do to its refusals.
    sh host/foundation14/run.sh  writes device/foundation14-expectations.h; the foundation14 groups of host/uikit2/run.sh hold each class

`host/oslog/run.sh` runs the same 61 calls through the host's os_log, asked for its
developer output, and through the port's formatter, and compares the two texts; the calls both
platforms can make become the expectations of the device test.

`host/avcapture/run.sh` runs the discovery of capture devices, their types and the
default device against the host's own, through Mac Catalyst, over every combination of
types, media type and position; the microphone is compared on the device only.

`host/textcontent/run.sh` compares the 23 text content type constants and the
`textContentType` of a text field, a text view and a search bar with the host's own,
through Mac Catalyst.

`host/contacts/run.sh` holds the port's Contacts to the host's own under Mac Catalyst, over
`device/contacts-cases.m`: every case builds its objects in memory - CNContact and its values,
the formatter, the vCard pair (both sides delegate to the same `ABPersonCreateVCardRepresentationWithPeople`
of the host's own `AddressBook.framework`, so this is exact, not approximate), groups and
containers before a save, and the plain value classes beside them. No case ever asks a
`CNContactStore` for a permission, a fetch or a save, because the host runs as whoever is
signed into this Mac and this package promises never to touch that person's own address book;
that one seam is held on the device instead, by a future `device/contacts.m`.

`host/blocks/run.sh` runs the port's timers, threads and run loop blocks in one
process with the system's own, compiled with the selectors prefixed, and compares
what each does and raises; `host/imageflip/run.sh` does the same for the flipped
image through Mac Catalyst.

`host/uikit2/run.sh` also runs the `appearances` group: random sequences of changes on the six bar appearance classes,
and the bars that apply them, compared with the host's own, and it writes `device/appearances-expectations.h` when it passes.

`host/uikit2/run.sh` also runs a group that needs a window - the snapshots of a view, for one -
as an application: its `windowed` function builds the group with `windowed.m`, which is `main`, a scene delegate and
a window, into a Mac Catalyst bundle with `windowed.plist`, signs it ad hoc and runs it, and the group's
`revenant_windowed_run(window)` is called once the window is up. A test written for it compares the system's answers with
the backport's the way the others do, for whatever UIKit will not do without a scene.

The `menus` group of `host/uikit2/run.sh` compares the menu elements, the menu identifiers, the context menu configuration and
interaction at rest, the preview parameters, target and targeted preview with the host's, and the `menucontroller` group holds the
two calls the new `UIMenuController` methods make to the old interface. `device/menus.m` is the device counterpart: it checks that the
classes and constants come from `libUIKitBackports.dylib` and repeats the checks that need no window.

The `pointer`, `pointercategories`, `search`, `searchcategories` and `colors` groups of `host/uikit2/run.sh` hold the pointer values (regions,
requests, shapes, effects, styles, interactions), the hover recogniser, `UIKey` and the key input strings, the button, event and gesture members, the
search token and search text field, the search bar's text field and the color well and picker to the host's own, as text, statement by statement, in
windows where a view is needed; what differs on purpose (the members of later releases, the class of a search token, the positions of tokens, the size
of a well, presenting a picker in a Mac Catalyst tool that never completes a presentation) is stated in the test and in the facts. `device/pointer.m` is the
device counterpart: it checks that the classes come from `libUIKitBackports.dylib`, repeats the value checks, adds interactions and recognisers
to real views, puts a search text field and a search bar's field on screen with tokens, and taps a color well to present, drive and dismiss the picker.

The `symbols` group of `host/uikit2/run.sh` compares `UIImageConfiguration`, `UIImageSymbolConfiguration`, the two weight functions, the symbol members of `UIImage` on ordinary
images and `UIImageView.preferredSymbolConfiguration` with the host's, over generated configurations and every pair of them, and draws the 549 symbols of `symbols-names.txt` against the host's at
eight configurations (size, insets, baseline within a point) and four sizes (overlap of the bitmaps); `REVENANT_WRITE_SYMBOLS=<directory>` rewrites `RevenantSymbolMetrics.h`, `symbols-expectations.h` and the
scores. `device/symbols.m` checks on the device that the classes and functions come from `libUIKitBackports.dylib`, the value behaviours, and every symbol against `symbols-expectations.h`.
The `layoutvalues` and `compositionallayout` groups of `host/uikit2/run.sh` hold the compositional layout's classes to the system's.
`layoutvalues` runs 139 statements against the system's classes and the port's and compares the answers as text:
defaults, copies, equality, `-description`, exceptions. `compositionallayout` is a `windowed` group: it puts each of 182 layouts
(`device/compositional-cases.m`) in a collection view in a real window, once with the system's layout and once with the port's,
and compares the content size, every attribute of the layout, the answers to six rectangles and the first item of every section,
with no tolerance; when all agree it writes the system's answers to `device/compositional-expectations.h`. Set
`REVENANT_FUZZ_ROUNDS=300` to add random layouts (`REVENANT_FUZZ_MASK` narrows the features they use, `REVENANT_FUZZ_ONLY=n` prints round
*n*'s two answers); they are a hunting tool, and rows that mix fractional and absolute widths still differ in a few. Give the
group a temporary directory of its own and a bundle identifier of its own (the `windowed` function's) when others run at the same time.
The `orthogonal` and `sizedlayout` groups are the same kind of test for the two features that need a live collection view. `orthogonal`
(`orthogonal_test.m`, the scenario in `device/compositional-cases.m`) puts sections that scroll the other way, in each of the five
behaviors and four kinds of group, in a collection view, moves the system's private scroll view of each to seven offsets and the port's
section by the same offsets, and compares the cells that are shown (frame, alpha, hidden, z, transform) and what the handler is told
(offset, and every visible item's frame, bounds, center, alpha, z, category), with a handler that moves, fades and turns items;
the answers are written to `device/compositional-orthogonal-expectations.h`. `sizedlayout` (`sizedlayout_test.m`) lays out 19 layouts of
cells that measure themselves by constraints, by `-sizeThatFits:` and not at all, in lists, grids, insets, fixed rows, counted groups,
with headers and footers, long and scrolled, and compares the frames of the cells and the content size; the answers are written to
`device/compositional-sized-expectations.h`.

`host/registry/run.sh` holds the build's check of the registry to a release's own
Objective-C metadata. The build refuses an `absent` entry whose class, method,
accessor or protocol the release carries, and an `ignored` entry the release
does not carry, within the releases the entry covers. The script gives the check
entries made up for the purpose, against the cache it is passed, and needs no
device.

`host/callkit/run.sh` holds the port's CallKit to the host's under Mac Catalyst: the five error domains, the defaults and the copy of a
provider configuration, the deadline each action class carries, the completeness of a transaction, the equality, hashing and secure
coding of a handle, and what a copy of each object is. A tool has no VoIP entitlement, so anything that reaches callservicesd comes back
`CXErrorCodeRequestTransactionErrorUnentitled` and no delegate method is ever called; the transactions the port really performs, the
timeouts and the refusals are held on the device by `device/callkit.m` instead. Four records are expected to differ and are named in the
script: the host's CallKit is that of iOS 14 and later, which drops the deprecated localized name from a configuration's copy and keeps a
ringtone as a resolved URL, where the iOS 10 header the port implements has two plain properties; and macOS runs no call directory
service, so the host's `CXCallDirectoryManager` answers a reload and a status with the connection's failure, where the port answers
NoExtensionFound. The test fails if they ever stop differing, and the device is held to the port's answer for those four and to the
host's for the rest.

`host/foundation2/run.sh` runs the cases of `device/foundation2-cases.m`, the
ones the device runs, against the host's Foundation and against the renamed
backports, compares the two and embeds the host's answers in
`device/foundation2-expectations.h`; it attaches the categories itself
(`host-attach.c`), since the host linker leaves `__objc_catlist` alone.

A test that attaches categories under a prefix at run time only renames the
methods it calls. If one method of the port calls another method the port also
carries, by an ordinary message, the host answers that call with its own
implementation, and the port's code never runs. `host/prefix_selectors.py`
closes that. It reads each source through clang's syntax tree and renames both
the port's method definitions and the messages sent to them, with their ARC
family kept, for example `initWith…` becoming `initRevenantHostWith…`. The tests
then attach the renamed categories as they are. `foundation2`, `foundation11`,
`rangewithname`, `keyedarchive11`, `systemspacing`, `gesturename`, `batchupdates` and
`directionalmargins` are built this way. In the four UIKit ones the tool renames
the definitions and nothing else: no method there calls another the port
carries.
`host/keyedarchive11/run.sh` holds the iOS 11 keyed archiving API to the host's
own: it runs `device/keyedarchive11-cases.m` twice in one process, once against
the system's methods and once against the backport's, renamed by
`host/prefix_selectors.py` and attached by `host/foundation2/host-attach.c`, and compares the two
answer by answer. It writes `device/keyedarchive11-expectations.h` only when
every answer agrees. What it holds the backport to, beyond the obvious round
trip: `-encodedData` returns the archiver's own mutable buffer and the same
object every time, it answers for an archiver made with
`-initForWritingWithMutableData:` instead of raising, and an archive whose root
is missing or `nil` fails with `NSCoderValueNotFoundError`, not with
`NSCoderReadCorruptError`.

`host/rangewithname/run.sh` holds `-[NSTextCheckingResult rangeWithName:]` to
the host's own, in one process, over patterns with named, unnamed, nested,
optional and look-around groups, names inside a character class, a `\Q…\E`
quote and a comment, the case-insensitive, comments and literal options, results
shifted by `-resultByAdjustingRangesWithOffset:`, a result of no expression and a
`nil` name. It writes no expectations: the host's ICU is the one of iOS 9 and
later, which compiles a named group, and the device test cannot replay a pattern
iOS 6's ICU rejects; `device/tail11.m` holds the iOS 6 side.

`host/foundation11/run.sh` does the same for the rest of the iOS 11 and 12
Foundation batch: reading and writing a property list through a URL,
`percentEncodedQueryItems`, `-decodeValueOfObjCType:at:size:` and
`NSSecureUnarchiveFromDataTransformer`. It renames the transformer's class as
well as attaching the categories, so the system's transformer and the
backport's stand side by side in one process. Among the answers it holds the
backport to: the error for a property list of the wrong kind is
`NSFileReadCorruptFileError` with the text naming the URL, a mutable receiver
reads a mutable array, a query item keeps its escapes, and the transformer
raises Apple's own wording for data that is not data and for a class that is
not allowed. It also holds the validated format to the host's: which formats
pass against which allowed specifiers, and the message for the ones that do
not. The matching rule itself was read off the running implementation - three
thousand random pairs of format and allowed specifiers, where the two agreed
on every verdict and every message - rather than out of CoreFoundation's
format parser.

`host/directionaledges/run.sh` holds `NSDirectionalEdgeInsets` to the host's
UIKit through Mac Catalyst: the text the insets format to, everything the
parser accepts and everything it refuses, the encoding the value carries, and
the bytes the coder writes with secure coding on and off.

`host/directionalmargins/run.sh` holds the directional layout margins to the
host's UIKit: which of the two projections wins when each is set last, and how
both read in either writing direction. It ends with a note rather than a check
for the one case the port cannot follow — a direction changed after the
directional margins were set, which would need `-layoutMargins` itself.

`host/contentsize/run.sh` holds the two content size category functions to the
host's: all one hundred and sixty-nine ordered pairs, the accessibility answer
for every category and for nil, and the exception an arbitrary string earns.

`host/fontmetrics/run.sh` holds `UIFontMetrics` to the host's UIKit at the
default content size category, which is the only category iOS 6 has: the
rounding to the display scale, the `maximumPointSize` cap, a custom font
keeping its family, the answer being a new object, and the wording of the
refusal when the font is `nil`.

`host/validatedformat/run.sh` fuzzes the validated format of `NSString`. It
compiles the port into the test under other selectors, puts random pairs of
format and allowed specifiers to the host's Foundation and to the port, and
compares their verdicts and messages. Where the arguments are the ones the
allowed string describes, it also compares every character of the output. Each
pair runs in a process of its own, since the host's formatter itself can crash
on a pair whose arguments it misreads. This method once slipped through the Foundation tests: its entry points
called the host's own initializer, so the port's check never ran on the host.
The port now does its work in one static function, and the fuzzer calls it
directly.

The pairs and the arguments come from a seeded generator, and the run prints
its seed, so `run.sh <pairs> <seed>` repeats it. The integer and float arguments
are drawn per pair, since a fixed argument hid three wrong strings for as long
as it was 7. Every fifty pairs the fuzzer switches a random half of what it can
write on or off - positionals, flags, widths, stars, precisions, lengths, odd
specifiers, `%P`, text, text outside ASCII, `%%`, an unfinished `%` - so a rare
combination is not always drowned by the common ones. A quarter of the pairs go
through the localized form. When a pair differs, the fuzzer cuts both strings
down, a piece at a time, for as long as they still differ, and prints the
smallest pair next to the one it found: `[%1$D%c] against [%D]` instead of
forty characters. Each pair runs in a child process that sends the host's answer
before it asks the port, so a crash of the host's formatter is counted apart,
and a crash of the port is a difference like any other.

`run.sh --mutants` checks the fuzzer itself. Each line of `mutants.txt` names a
rule of the port and a Perl substitution that breaks it; the script builds the
port with that one change, runs the fuzzer over it with a fixed seed, and says
`caught` with the smallest pair, `MISSED` when the fuzzer passes a broken port,
and `STALE` or `BROKEN` when the change no longer applies or no longer
compiles. It exits non-zero on anything but `caught`.

`host/fuzz/run.sh` runs one of three fuzzers against the host's Foundation:
`percentencoding` (percent encoding and the URL character sets, Base64 of
strings and data), `stringcase` (localized case, containment and transforms,
tried under `en_US` and `tr_TR` so a locale-blind rule shows up), and
`calendar` (the `NSCalendar` and `NSDateComponents` methods of iOS 8). Each
draws its inputs from a seeded generator and prints the seed, so a run can be
repeated with `run.sh <fuzzer> 0 <seed>`. Every difference is filed under a
category, one per method or option, and the first three of each are printed.
The host is newer than any release the port follows, so a difference is not by
itself a bug in the port: a category listed in `host/fuzz/tolerated/<fuzzer>.txt`,
with the reason on the same line after a tab, is counted but does not fail the
run. Any other category does.

`host/fuzz/run.sh --mutants <fuzzer> [rounds] [seed]` checks a fuzzer the way
`validatedformat`'s does: `mutants/<fuzzer>.txt` names, one per line, a rule of
the port and a Perl substitution that breaks it, over a private copy of
Foundation built for that one run; the script says `caught` with the category
the run failed under, `MISSED` when the broken port still passes, and `STALE`
or `BROKEN` when the change no longer applies or no longer compiles.

`host/probes/run.sh` holds the capability probes of DeviceCheck, ARKit and CoreNFC
to the host's own frameworks, which it reaches through Mac Catalyst since ARKit
and CoreNFC are not native on the Mac. The five sources are compiled with their
classes and constants renamed, and the port and the frameworks answer side by
side: the shared object and `-isSupported` of `DCDevice`, `+isSupported` of every
configuration, `+readingAvailable` of both sessions, the class each one derives
from, and the strings of the three error domains. What the host cannot answer
the same way is left to the device test: it has a daemon and hands out a token,
where the port answers an error. The settings and session calls the port leaves
out are checked to be absent, since the host has them.

`host/swipeactions/run.sh` holds `UIContextualAction` and `UISwipeActionsConfiguration` to the
host's UIKit through Mac Catalyst, with the two classes renamed: what an action holds, the
colour each style gives it and the one it gets back from nil, the copies it makes and the
one it does not, and a configuration that keeps the array it was given as it is.

`host/systemspacing/run.sh` holds the system spacing of a layout anchor to the
host's UIKit, comparing the whole shape of the constraint each method returns -
items, attributes, relation, multiplier, priority and the constant the spacing
ends up in. It covers the eight points between ordinary edges at four
multipliers, the three relations on both axes, the baseline spacing over five
pairs of font sizes, a baseline against an edge, two views with no font at all,
and an edge of the container. It ends with a note for the one combination the
port does not reproduce: a baseline of a text view under the baseline of a view
with no font.

`host/rendererformat/run.sh` holds the preferred formats and
`+formatForTraitCollection:` to the host's UIKit. It compiles the renderer
format classes renamed together with the categories, and compares what each
factory answers: its class, bounds, scale, whether it is opaque and whether it
prefers an extended range. The trait collections cover nil, empty, six display
scales on both sides of the two epsilons the releases have used, each display
gamut, a scale with a gamut, and a size class alone. A last check, for the port
alone, hands it an object that answers a display scale and not a display gamut,
as the trait collections of iOS 6 to 9 do, and expects the scale taken and the
gamut left unspecified.

`host/gesturename/run.sh` holds the name of a gesture recognizer to the host's:
that it starts empty, that it is copied rather than held, that clearing it
works, and that two recognizers keep their own. It notes the one thing the port
cannot do - the system prints the name inside `-description`, which belongs to
the release.

`host/animatorscrub/run.sh` is the contract for the two flags iOS 11 added to
`UIViewPropertyAnimator`, a class of the iOS 10 range: the defaults, where the
flag may be set and where setting it raises, what scrubbing does to an animator
built with animations, built without, paused and running, and what an animator
that pauses on completion does when its time has passed - it stays active and
not running, and holds its completion blocks until the application finishes it.
It fails until the class carries them; the properties answer `NO` before that,
because the class is the SDK's own interface under another name and the compiler
synthesises what nobody wrote, so every check is behaviour rather than
`respondsToSelector:`.

`host/usernotifications/run.sh` sets the notification values and triggers
beside the system's UserNotifications: what a trigger refuses and with what
text, the next date of every trigger through the triggers' own
`-nextTriggerDateAfterDate:withRequestedDate:` on 5760 fixed dates, a content
fresh, filled, copied, set to nil and archived both ways, requests, sounds and
the members of later releases the class must not answer. When it passes it
writes the device's expectations.

`host/traitstyle/run.sh` is the contract for the user interface style of a
trait collection, iOS 12 API on a class of the iOS 7-10 range: it runs one
script against UIKit's own collection and the same script against the port's,
and compares the style a collection is built with, what a collection of a scale
alone and of nothing at all answer, five merges, equality and hash against an
empty collection, four containment questions, the description, the copy, an
archive round trip, and the collection a screen is given. It fails until the
port carries the API, which is the point: the numbers in it are what the port
has to match.

`host/interactions/run.sh` covers two things a view holds for somebody else:
the list of `UIInteraction`s, and the attributed strings of accessibility. It
runs one script against UIKit's own implementation and the same script against
the port under its host names, and compares every answer - which interaction is
told what and when, the order of the list, the copy the getter hands out, the
three exceptions the current implementation raises for a `nil` argument, and
how an attributed label and a plain one stand for one value. The loose constants the port carries for this range are compared with UIKit's
own strings, values included, and the VoiceOver notification is compared with
the deprecated name it replaced as well - being the same string is the whole
reason it works here.

`host/batchupdates/run.sh` runs the same sequence of table updates twice, once
through the system's `-performBatchUpdates:completion:` and once through the
backport's, and compares the whole order of what happened: the update block
running inside the call, the completion arriving only after the run loop turns,
one completion per call, `nil` blocks and an empty block accepted, a nested
call, and the rows left after inserting, deleting and moving.

`host/uikit2/run.sh` renames selectors as well as classes, so a test holds a
backported method and the system one side by side, and checks the spring curve
against a real CASpringAnimation, which needs AppKit and so runs as a plain
macOS tool. What each of its tests holds the backport to:

- `spring_uikit.m` prints the spring UIKit itself builds for
  `+[UIView animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:]`;
  `spring_ours.m` compares the spring the backport solves for with it and writes
  the samples `spring_sample.m` checks against a real CASpringAnimation. A layer
  has a presentation layer only inside a window, so that part is the plain macOS
  tool, and the sample at the very end of an animation is left out, where Core
  Animation has already removed the animation and shows the model value.
- `motion_test.m`: Mac Catalyst answers nil for every motion effect, so the
  backport is held to the rules the UIKit headers state - the viewer offset runs
  from -1 to 1, the horizontal type maps -1 to the minimum relative value and the
  vertical type maps a downward tilt to it, a group adds the values of its
  effects, and the view applies the result to its layer.
- `sizes_test.m`: every content size category of the backport against the string
  the system's own constant holds, and that no two of them are the same string.
- `tint_test.m`: iOS 7 states that `-tintColor` returns the first colour set in
  the superview chain, that a dimmed adjustment mode greys the colour it returns,
  and that `-tintColorDidChange` reaches the views that inherit the colour.
- `bars_test.m`: on iOS 6 the tint colour of a bar is the colour of the bar
  itself, which is what iOS 7 calls the bar tint colour, so the backport keeps
  the value it was given and hands it to the iOS 6 tint colour.

- `vtvalues/`: prints the strings the host's VideoToolbox gives the H.264 profile levels of iOS 7 and
  `kVTDecompressionPropertyKey_RealTime`, the values `VideoToolbox/VideoToolbox7.m` carries.

## Device

The device tests run on an emulated iOS 6.0 (iPhone3,1). Until the toolchain runs the
emulator itself, a test is built by hand against the 6.0 band of the package
and started by the emulator lab:

    clang -target armv7-apple-ios6.0 -isysroot SDK -fuse-ld=LD64 -fobjc-arc -Idevice \
        device/url.m device/check.m -LBAND -lFoundationBackports -framework Foundation -o url
    ldid -S url BAND/*.dylib

and the libraries reach `/usr/lib/revenant/org.revenant.apple-backports/` of the
emulated root filesystem the way a device gets them: the data of
`org.revenant.apple-backports_<revision>_iphoneos-arm.deb` unpacked into it and its
postinst run with `DPKG_ROOT` set to it.

A test that creates UIKit objects is an application (its own `-Info.plist`,
installed and started through SpringBoard), not a process of its own: a bare
process has no `UIApplicationMain` behind it, and there `UITextView`'s
`initWithFrame:` traps with `SIGTRAP`
(`packages/a/apple-backports/facts/UIKit/TextSystem7.md`). Inside the
application, schedule later steps with timers or
`performSelector:withObject:afterDelay:`, not with `dispatch_async` to the main
queue from a block already running there: the main queue is serial, so a block
queued behind a running one does not run while that one spins a nested run loop.
A test waiting on a library that answers on the main queue (`ALAssetsLibrary`,
the Photos port over it) waits off the main queue, and off the main thread it
sleeps or waits on a semaphore, never `CFRunLoopRunInMode`, which returns at
once on a thread whose run loop has no sources.

A stand built through Revenant's `@addon/revenant/app` rule
instead of by hand asks for ARC itself, on the target:

    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc")

The rule adds neither, and every file here is written for ARC. Without them the
build succeeds and the process fails at run time: `gesture.m`'s static `queue`,
assigned an autoreleased array, dangles once the pool drains, and the first
`dispatch_after` step dies in `objc_msgSend` with SIGSEGV. On a device such a
death leaves no crash report, so it reads as a hang. The link flag is what makes
clang force-load arclite below iOS 9.

- `mechanism.m`, `url.m`: a process of their own, Foundation only; they print
  `ok`/`FAIL` lines and exit with the number of failures. `url.m` includes
  `url_expectations.h`, the host's results that `host/url/run.sh` writes there
  when it passes, so the device is held to the same answers.
- `session.m` with `session-scenarios.m`: started from a LaunchDaemon on a full
  boot, with `host/session/server.py` running on the host and its port as the
  second argument (`session session PORT`); it writes
  `/private/var/backports/session.log` and `session.done`.
- `foundation2.m` with `foundation2-cases.m`: a process of their own, the second
  Foundation batch; it holds each case to `foundation2-expectations.h` and
  names, for every backported method, the image its implementation comes from,
  so a method the release already has is never taken from the library.
- `webkit.m` with `webkit-cases.m`: an application, the WebKit batch: a `WKWebView` over the `UIWebView` of the release
  is put through loads, history, decisions, JavaScript, scripts and messages, and every answer is held to what the
  system's `WKWebView` did in `webkit-expectations.h`, which `host/webkit/run.sh` records under Mac Catalyst. It needs
  the package built with `webkit = true`; three records that differ for a stated reason are tolerated by name.
- `localauth.m`: a process of its own, the LocalAuthentication batch: a context answers as a device with no fingerprint
  sensor and no way to ask for the passcode - the questions fail with the system's errors, an evaluation is answered
  off the main thread and never succeeds. The behaviour a device shares with the host is held to it by the
  `localauth` group of `host/uikit2/run.sh`. It needs the package built with `localauthentication = true`.
- `searchcontroller.m` with `searchcontroller-cases.m`: an application, the search controller of iOS 8 put through its
  presentation, its delegate's messages, typing, cancelling and the navigation item that holds it, and every answer
  held to what the system's `UISearchController` did in `searchcontroller-expectations.h`, which
  `host/searchcontroller/run.sh` records in an application under Mac Catalyst; nine records differ for a stated reason
  the test names.
- `itemprovider.m` with `itemprovider-cases.m`: a process of its own, `NSItemProvider` and `NSExtensionItem` put through
  what each type and each class asked for answers, the load handlers, the errors, a provider of a file, the
  representations of data and files, and objects, and every answer held to what the system's classes did in
  `itemprovider-expectations.h`, which `host/itemprovider/run.sh` records under Mac Catalyst. The behaviour that does not
  depend on the UTI database is also held by the `itemprovider` and `itemproviderbuiltins` groups of `host/uikit2/run.sh`.
- `ios1516.m`: a process of its own, what iOS 15 and 16 added that the port carries: `NSUUID`'s `compare:`, held to the answers
  `host/ios1516/run.sh` writes into `ios1516-expectations.h` after holding the port's method to the host's own, the
  orientation update of a view controller and the padding above a section header.
- `textalias.m`: a process of its own, the classes the release carries without exporting them that the port exports as
  aliases (`packages/a/apple-backports/revenant_alias.h`), `NSTextTab` and `NSTextList`: the linked name answers the release's
  class, what is made through it is the release's class, the name answers NSObject's class introspection as the release's
  class, a subclass written of the name inherits the release's class and is laid out after it, and the categories written
  on the name - `NSTextTab`'s `+columnTerminatorsForLocale:`, `NSTextList`'s initializer of iOS 16 - are on the release's
  class, from `libUIKitBackports.dylib`, attached by the library's loader and by nothing in a `+load`. It is built with
  `packages/a/apple-backports/attach.c` beside `check.m`, which makes the process an image with aliases of its own for the
  loader's other paths: `NSTextBlock`, whose category writes a method the release has and one it lacks, and `NSTextTable`,
  whose subclass has a `+load`, so the runtime lays the alias out before the loader runs. It is built by its own project,
  `device/textalias/xmake.lua` (`xmake f -P tests/backports/device/textalias -p iphoneos -a armv7`, then `xmake build`, then
  `xmake emulate -d iPhone4,1 -r 6.1.3 install` and `run /usr/libexec/textalias`); 61 of 61 on the 6.1.3 emulator. A probe
  built by hand with plain `clang` and `-marm` is not built through the toolchain, and its red run (31 FAIL lines) is not
  evidence about this test.
- `corelocation.m`: a process of its own, the CoreLocation batch: the circular region as a class, its notify flags,
  and the answers of the class methods about monitoring and ranging. It needs the package built with
  `corelocation = true`; it is checked on the emulated 6.0 and on the iPad 2, where location services and region
  monitoring are on and the emulator has no location daemon, so what depends on the daemon is compared with the
  release's own `+regionMonitoringAvailable`, not with a number.
- `spring.m` with `spring-cases.h` and `spring-expectations.h`: a process of its own, the two members iOS 9 added to
  `CASpringAnimation` and the two iOS 10 added to `CADisplayLink`. It names the image every one of the six methods comes
  from, so a release that has them itself is never shadowed, holds the settling time of the 32 springs of
  `spring-cases.h` to the host's answers that `host/spring/run.sh` records - their values are exact in a `float`, since
  a `CGFloat` is one on armv7 and the release keeps what it is given - checks that the initial velocity and the
  release's own velocity are one value in both directions, and puts a real link through the frame rates, the frame
  intervals and a run loop, where the target timestamp is a frame past the timestamp. 53 of 53 on an iPhone 4S
  running 6.1.3.
- `seckey.m`: a process of its own, the five key functions of iOS 10. It names the image each of the five comes from,
  asks for a key with no parameters and with a key type the release cannot make and gets an error rather than a crash,
  generates a 1024-bit RSA pair that is not kept in the keychain, takes its public key, holds the public external
  representation to a PKCS#1 RSAPublicKey of a modulus of the size asked for and an exponent of 65537, runs PKCS1 and
  OAEP-SHA1 round trips through the pair, and holds an algorithm the release cannot do to a refusal that carries an
  OSStatus the caller can read. The private key's representation is either a PKCS#1 RSAPrivateKey or an error, and the
  test fails if it is ever the public half. It needs the package built with `security = true`.
- `ypcbcr.m`: a process of its own, the 420 Y'CbCr conversions of iOS 8. It names the image each of the seven
  functions comes from, checks the four matrices against the coefficients the newer release holds, holds every luma and
  chroma byte of a 34 by 18 picture to the arithmetic the header writes out within the last bit, checks that the luma
  and chroma are the same whichever chroma layout is asked for, that the alpha the caller gives reaches every pixel,
  that each of the four channels is extracted byte for byte, and that the refusals are the documented ones. It then
  holds the four pixel conversions of iOS 7 to the header's integer arithmetic exactly, with no tolerance. It needs the
  package built with `accelerate = true`.
- `tolerance.m`: a process of its own, the timer tolerance, which is a property
  and two CoreFoundation functions.
- `uikit2.m` (`uikit2-Info.plist`): an application for the second UIKit batch -
  the traits, the tint colour, the motion effects, the spring animation, the
  notification settings and the bar appearances. Where the environment cannot
  answer a check - an emulator delivers no device motion for the gyroscope - it
  prints a `skip` line with the reason instead of a verdict. Its controller
  answers NO to `-shouldAutorotate`, since iOS 6 ignores
  `-[UIApplication setStatusBarOrientation:animated:]`, which the traits step
  turns the status bar with, while the top-most full screen controller
  autorotates.
- `keyedarchive11.m` with `keyedarchive11-cases.m`: a process of its own for the
  iOS 11 keyed archiving API. It holds each case to
  `keyedarchive11-expectations.h`, names the image every backported method comes
  from, and checks the one thing the host cannot show: that a second
  `-finishEncoding` on iOS 6 neither raises nor touches the archive, which is
  what `-encodedData` stands on.
- `foundation11.m` with `foundation11-cases.m`: a process of its own for the
  rest of the iOS 11 and 12 Foundation batch, held to
  `foundation11-expectations.h`. Besides the cases it shares with the host, it
  names the image every backported method comes from and checks that the
  transformer answers to its name through `+[NSValueTransformer valueTransformerForName:]`.
- `security12.m`: a process of its own for `SecTrustEvaluateWithError`, `SecCertificateCopyKey` and
  the serial number of a certificate. It holds the trust evaluation to what the newest Security
  answers - the verdict, the domain, the code, the description and the underlying error - for a
  trusted certificate, an untrusted root, a name that does not match, an expired certificate
  and the combinations of them, and the same file, compiled against the host's own Security,
  passes all twenty-four of its checks, so the expectations are the host's answers and not
  ours. It links `libSecurityBackports.dylib`. It ran on an iPad 2 (6.1.3): twenty-seven checks and
  no failure.
- `cvpages.m`: a process of its own that links UIKit, for the compositional layout in a collection view on iOS 6: a group of
  700 points in a 320 x 480 view, scrolled so that it reaches past both ends of the bounds, has its view, once, at its own frame,
  where a plain layout's element of that shape has none (the release's answer is printed as a `note`); the layout answers
  such an element twice, the frame cut to the bounds first and its own last, which is what iOS 6's `UICollectionViewData`
  needs to file it under a page (`facts/UIKit/UICollectionViewCompositionalLayout.md`). It ran on an iPad 2 (6.1.3): 17 checks,
  no failure.
- `tail11.m`: a process of its own that links UIKit, for the small rows that answer
  the same on every device: `-[NSProcessInfo thermalState]` answers nominal and its
  notification is never posted, the export presets of the image picker are kept per
  picker and the video one is copied, the key `UIImagePickerControllerPHAsset` carries
  its own name, the key `NSLocalizedFailureErrorKey` carries `NSLocalizedFailure` from
  `libFoundationBackports.dylib` and `-localizedDescription` makes of it what the host's
  Foundation does, in the order of `NSError.h` and against a value provider, the two
  split scroll indicator insets come from `libUIKitBackports.dylib` (`uikit12.m` holds
  what they do), and what is absent stays absent. It also holds the four volume keys
  of iOS 11 to what an iPad 2 answers - success and no value for a key it does not
  know, the available capacity for the important usage key - the refusal of a
  pattern that names a group, and `-trashItemAtURL:resultingItemURL:error:`
  answering the feature unsupported error, and the swipe action classes, whose
  answers it holds to those of the host. It ran on an iPad 2 (6.1.3): 67 checks
  and no failure.
- `probes.m`: a process of its own for the capability probes, run on an
  iPhone 4S and an iPad 2 (6.1.3). It checks that every class the probes carry
  comes from `libFoundationBackports.dylib`, that `+isSupported` and
  `+readingAvailable` answer as the facts say, the hierarchy, the domains, and
  the one thing no host can show: `-generateTokenWithCompletionHandler:` is
  not answered before it returns, is answered from a background queue with
  `DCErrorFeatureUnsupported` and no user info, and a `nil` handler is ignored.
  It also checks that what is absent answers no to `respondsToSelector:` and
  `NSClassFromString`. The last full run answered 72 checks and no failure on
  each device.
- `directionaledges.m` with `directionaledges-cases.m`: a process of its own
  for `NSDirectionalEdgeInsets`, held to `directionaledges-expectations.h`. The
  structure's encoding is checked for its own name rather than against the
  host's, since `CGFloat` is a float on the device and a double on the host.
- `safearea-tweak.m`: the safe area and the directional layout margins, which
  need a real window and so run inside a running application rather than one of
  their own: it is a MobileSubstrate tweak filtered to Preferences, which
  `killall Preferences` restarts without a respring. It makes a window of its
  own below the normal level, checks forty-seven answers against what the
  algorithm read out of UIKit 11.0 says they must be - the safe area, the
  scroll view's adjusted content inset, the directional margins and
  `UIFontMetrics`, which shares the run because it needs the device's screen
  scale and its font cache - writes
  `/private/var/backports/safearea.log` and `safearea.done`, and hides its
  window again. Six of the checks are that `-safeAreaInsetsDidChange`,
  `-viewSafeAreaInsetsDidChange`, `-safeAreaLayoutGuide`,
  `-adjustedContentInsetDidChange`, `-systemMinimumLayoutMargins` and
  `-viewRespectsSystemMinimumLayoutMargins` are **not** there, since the port
  does not declare what it cannot deliver. The scroll view checks need a safe
  area that is not zero on any edge, which is why they run here and not on the
  host: the window gives `{30, 5, 15, 20}`, and each behaviour is held to the
  edges the algorithm says it keeps. The folder has to
  exist and be writable by the application first:
  `mkdir -p /private/var/backports && chmod 777 /private/var/backports`. Every
  check writes its own line to the log, since a tweak must not touch the
  application's `stdout`: a failure that only printed would be lost. So a tweak
  never calls `revenant_log_to`, which reopens `stdout` onto its file
  (`device/check.m`), and its constructor does nothing that can crash the
  application: crashes of the application in a row can leave MobileSubstrate in
  safe mode, where the tweak is not loaded until a respring
  (`killall -9 SpringBoard`). The last
  full run answered `ok checks=47 failures=0` on an iPhone 4S (6.1.3, armv7).
  Three of those checks are not about the safe area at all: they ask the
  release's own visual format parser what it does with the iOS 11 spacing
  option, which is a question only a real iOS 6 can answer.
- `revenant-sblaunch` (in `packages/e/emulator-guest/src/`, built by that
  package, which is where `xmake emulate launch` takes it from): one way to
  start an application on either device without `uiopen`, which has twice left
  the iPhone 4S to its watchdog. It takes one argument, the bundle identifier,
  the way the `sblaunch` already installed on the 4S does, and asks SpringBoard
  through `SBSLaunchApplicationWithIdentifier`, which it looks up with `dlsym`
  rather than linking a private framework. `--wait SECONDS` retries until
  SpringBoard takes the launch, and `--stdout`/`--stderr PATH` launch through
  `SBSLaunchApplicationForDebugging` with the application's output in files.
  - Exit codes: 0 when the launch is accepted (with `--wait`, once the
    application is frontmost); 1 with SpringBoard's code, its description and
    whether the screen is locked (as the token `screen=locked`, or `screen=passcode`,
    which `xmake emulate launch` reads), on standard error when it is refused; 2 for a
    wrong argument; 3 when a function it needs is missing; 4 when SpringBoard
    took the launch and the application did not become frontmost in time.
  - SpringBoard refuses a caller without the entitlement
    `com.apple.springboard.launchapplications`: without it the call returns 1
    even from root. `revenant-sblaunch.entitlements` carries it, and
    `com.apple.springboard.debugapplications` for the launch with output.
  - The package's install holds it signed with `revenant-sblaunch.entitlements`
    at `usr/libexec/revenant-sblaunch` (`xmake where emulator-guest` in a port
    that includes `@addon/revenant/emulate`); copy it to a device from there.
  - The iPad 2 has no `sblaunch`, and on 19 September 2026 this launcher
    started Preferences there and on the iPhone 4S alike.
- `uikit11/`: a MobileSubstrate tweak filtered to Preferences, for the iOS 11
  UIKit members that need a running application. It replays five host tests
  on the device: `interactions`, `systemspacing`, `gesturename`,
  `batchupdates` and `contentsize`.
  - Each host test's `differential.m` is compiled into the tweak unchanged: its
    `main` is renamed, its `printf` goes into the tweak's log through
    `capture.h`, and `alias.m` gives every method of the backport libraries
    the `revenantHost` names the tests call their port side by.
  - On iOS 6 the system side of every test is the port. Each answer is held to
    the host's, which `refresh.sh` runs the host tests to write into
    `uikit11-expectations.h`.
  - A few answers depend on the release, and the tweak checks those against
    the release instead. These are the baselines of system spacing, which
    follow the formula with the device's fonts and the attributes its anchors
    give, and the moment a batch update's completion arrives, which is checked
    after the handler returns.
  - It also reads the back button a real `UINavigationBar` draws for each way
    of setting `backButtonTitle`: on every release this package supports, the
    property is UIKit's own.
  - Build it with Revenant's tweak rule and `-fobjc-arc`, with `host/` and this
    folder on the include path and `capture.h` included first
    (`-include capture.h`). Launch Preferences with `sblaunch
    com.apple.Preferences`. It writes `/private/var/backports/uikit11.log`,
    one line per check, and `uikit11.done`. The last run on an iPhone 4S
    (6.1.3) answered `PASS`.
- `alert.m`, `layout.m`: applications (`alert-Info.plist`, `layout-Info.plist`)
  launched from SpringBoard; they write `/private/var/backports/NAME.log` and
  `NAME.done`, and `alert.m` logs a `SCREENSHOT <label>` line and pauses before
  each state worth a snapshot. `layout.m` holds a table of the system
  UIStackView's frames written by `host/layout/expectations.m`.
- `animator.m` also measures what scrubbing costs, since the answer only means
  something on the slowest hardware the port runs on. It times a scrub step
  three ways - an empty loop, freezing the layer, and rebuilding the animation,
  which is what the port does - and holds the last to one display frame. On an
  iPhone4,1 the three came out at 0.1, 4.4 and 109.2 microseconds against a
  frame of 16666.7. Reading the presentation layer needs `[CATransaction flush]`
  and a turn of the run loop first: before the first commit there is no
  presentation layer and the model value is what comes back.
  It also reads where a quarter of the fraction puts a view on an ease-in-out
  curve, which is the one thing `scrubsLinearly` changes and only a window
  shows: a quarter of the way when the animator scrubs linearly, and short of
  it, where the curve says, when it does not.
- `usernotifications.m`: a process of its own for the notification values and
  triggers. It holds 5760 next dates of calendar triggers, in five zones and
  around changes of clocks, to `usernotifications-expectations.h`, which
  `host/usernotifications/run.sh` writes from the system's own triggers when it
  passes; a zone whose rules changed after 2013 is not among them, since iOS
  6.1.3 keeps the rules of 2013.
- `notifications.m` (`notifications-Info.plist`): an application for the center,
  launched with `sblaunch` since it needs a running `UIApplication`. It asks for
  authorization, adds, replaces and removes requests, reads back what iOS 6 was
  given - the body and no title - checks which repeats are taken and which
  refused, and waits for a notification to arrive while it is in front.
- `stabilization8.m`: a process of its own for the video stabilization of iOS 7 and 8, with the two categories built in: every camera format's `supportedStabilizationMethod` of the release beside `videoStabilizationSupported` and the modes it supports, then a running video data connection of the default camera: Off at first, the exception for a mode past Cinematic, Standard, Cinematic and Auto against the release's switch, the active mode against what the release says it runs, and the old switch afterwards.
- `zoom7.m`: a process of its own for the zoom of iOS 7, with `AVCaptureDevice+VideoZoom7.m`, `AVCaptureDevice+ActiveFrameDuration.m` and `RevenantAVCapture.m` built in: the crop of a 32BGRA and a 420v buffer of a known picture, each format's maximum by the release's rule, 7.0's range and lock checks and texts, the still connection's `videoScaleAndCropFactor` against the release's own maximum, the preview layer's sublayer transform and point conversions, the camera's frames at 1 and 2 (printed), the ramp and its cancel, the frame duration's lock, and what a movie file output's connection can do.
- `captureaudio7.m`: a process of its own for the application's audio session and a capture session: Playback set, the microphone still captured, then `AVCaptureSession+ApplicationAudioSession7.m`, built in, answering NO and keeping it.
- `photooutput10.m`: a process of its own for `AVCapturePhotoOutput`, with `AVCapturePhotoOutput.m`, the zoom's files, `Accelerate/vImageYpCbCr8.m` (the 4:2:0 preview's converter, which 6.1.3's Accelerate lacks) and `Graphics/ImageIONames70.m` (`{MakerApple}`) built in: the release's own still image output in the same session as the control, the photo output in `session.outputs`, the format offered, the refusals, real captures with a preview at the display's size, at a size asked for and past the display, each compared with the probe's own drawing of the photo, an uncompressed photo, a zoomed one, a capture with `{MakerApple}` in its metadata (what the release's JPEG keeps of it is printed), and the flash: the modes offered are the camera's, and a capture sets its mode on the camera (a camera with a flash only, so the iPhone 4S, not the iPad 2).
- `avplayer.m` (`avplayer-Info.plist`): an application of its own, `AVPlayerViewController` over a three second video it writes: presented, picture in picture, inline and full screen with the delegate's transition coordinators, `pixelBufferAttributes` in 32BGRA and 420f, and a file that fails; `checkpoint` pauses where a screenshot is taken. Linked against the package built with `avkit = true`, staged under a folder of its own so the canon stays.
- `colormatching.m`: a process of its own for `CGColorCreateCopyByMatchingToColorSpace` over the release's colour transform (facts/CoreGraphics/ColorMatching.md), with the port built in.
- `bitmapcontexts.m`: prints which bitmap contexts 6.1.3's `CGBitmapContextCreate` makes (8-bit only), the measurement behind the colour matching.
- `ciimage.m`: a process of its own for CIImage compositing, image buffer initializers and linear sampling, with the three categories built in.
- `uttypedynamic8.m`: a process of its own for `UTTypeIsDynamic` and `UTTypeIsDeclared`, with `UIKit/UTTypeDynamic8.m` built in.
- `h264decode.m` (`h264decode-frames.h`): a process linked against the package built with `avfoundation = true`: format descriptions from the host encoder's parameter sets decoded by the release's `VTDecompressionSession`, `VTCompressionSessionPrepareToEncodeFrames` and the profile levels against the release's encoder.
- `avcapture.m`: a process of its own for the discovery of capture devices, linking
  `libAVFoundationBackports.dylib`. It holds a discovery session to the devices the
  release lists, by type, media type and position, in the order of the types, and
  the default device, the device types and the exception for a nil type to what was
  read off 10.3.4.
- `textcontent.m`: a process of its own for the text content types. It holds the 23
  constants to the strings read off iOS 10.3.4, and the property of the three views
  to its defaults and its copying. A process cannot make a text field, which needs a
  running application, so it uses instances that are allocated and not initialized;
  `host/textcontent` runs the same on real views.
- `oslog.m`: a process of its own for `os_log`. It calls the macros the way a program built for iOS 6
  does, on a battery of formats that `host/oslog` has run through the host's own os_log and embedded in
  `oslog-expectations.h`, and reads the messages back from ASL to compare them with the host's text, with the level and the
  facility they arrive at, and with what must not arrive.
- `blocks.m`: a process of its own for the block methods of `NSTimer`, `NSThread`
  and `NSRunLoop` and for `temporaryDirectory`, linking the backports library. It
  holds the timers, the thread and the run loop to what the host's own Foundation
  answers in `host/blocks`, the exception texts included.
- `imagescreen.m`: a process of its own for `-imageWithHorizontallyFlippedOrientation`
  and `maximumFramesPerSecond`. It flips all eight orientations, keeps the insets
  and rendering mode, and asks the release for the refresh interval the frame
  rate is worked out from.
- `coredata.m`: a process of its own for the Core Data container, linking
  `libCoreDataBackports.dylib`. It loads a SQLite store and, asynchronously, an
  in-memory one, inserts, fetches in and out of a context's block, saves in a
  background task and waits for the view context to merge it.
- `haptics.m`: a process of its own for the feedback generators, linking UIKit
  but raising no window. It holds the port to what was read off iOS 10 rather
  than to a sensation: that the three generators are there and come from the
  backports library, that `UISelectionFeedbackGenerator` is declared and its `-selectionChanged` does nothing,
  that a style outside the three still builds a generator and simply plays
  nothing instead of raising, that the iOS 13 `-impactOccurredWithIntensity:` is
  not answered, and that every call returns without raising. It says nothing
  about how hard the motor turns: that was measured on an iPhone4,1 with the
  accelerometer and is written down in
  `packages/a/apple-backports/facts/UIKit/UIFeedbackGenerator.md`, since an
  emulated device has no motor and every call there plays nothing.
- `avaudioengine.m`: a process of its own for `AVAudioEngine`/`AVAudioPlayerNode`, linking
  `libAVFoundationBackports.dylib`. A graph that compiles, runs and produces silence reports
  nothing - no exception, no error code, a green gate - so this pulls the real `GenericOutput`
  unit's output by hand through `AudioUnitRender` and checks it sample-for-sample against a known
  waveform scheduled through a real `AVAudioPlayerNode` into the real `mainMixerNode`.
  `kAudioUnitSubType_GenericOutput` needs no `mediaserverd`, so this runs on the emulator, not
  only on a device. 13 checks, no failure on an iPhone4,1 (6.1.3): the pulled samples matched the
  scheduled waveform exactly.
- `avaudiouniteq.m`: a process of its own for `AVAudioUnitEQ` over a real `kAudioUnitSubType_NBandEQ`
  unit, in the same offline `player -> EQ -> mainMixer -> GenericOutput` graph `avaudioengine.m`
  proves. A real EQ node attached but never touching the signal is the same "compiles, runs,
  produces silence" failure one level up, so the check names its expected result before running: a
  band at 0 dB gain, un-bypassed, should leave a 2 kHz test tone where it started, and a real
  `LowPass` band at 150 Hz against that same tone should attenuate it to well under half its RMS.
  9 checks, no failure on an iPhone4,1 (6.1.3): the 0 dB band left the tone bit-exact
  (`max |output - source| = 0.000000`), and the 150 Hz low-pass dropped RMS from 0.353003 to
  0.007011, about 50x. This file is itself evidence of a property of the whole test stand: it
  compiles against the real SDK's own framework headers, not this port's private headers, so a
  class member the port's implementation invents but Apple's real header does not declare fails
  here at compile time, before it ever reaches a device - caught exactly once, for a fabricated
  `AVAudioUnitEQFilterParameters.active` property, while writing this file.
- `avaudioconverter.m`: a process of its own for `AVAudioConverter` over real
  `AudioConverterServices`, linking `libAVFoundationBackports.dylib`. A known 440 Hz Float32 tone
  is converted down to Int16 and back up to Float32 through `-convertToBuffer:fromBuffer:error:`,
  and the check names its error bound before running rather than after: `AVAudioPCMFormatInt16`
  maps `[-1, 1]` onto `[-32768, 32767]`, so neither hop can move a sample by more than one int16
  step, and the round trip's own bound is `2/32768 = 0.00006103515625`. 8 checks, no failure on an
  iPhone4,1 (6.1.3): measured max error `0.0000152587890625`, about half the named bound and almost
  exactly half an int16 step - what round-to-nearest quantization predicts for a full-scale tone,
  and clearly non-zero, so the round trip really quantized rather than silently passing the buffer
  through. The first run of this file failed every conversion with `OSStatus -50` (`paramErr`): a
  freshly allocated `AVAudioPCMBuffer` already owns real sample memory at its full `frameCapacity`,
  but its `AudioBufferList`'s `mDataByteSize` starts at 0 (it tracks `frameLength`, not capacity),
  and `AudioConverterServices` reads `mDataByteSize` as how much room it has to write into - fixed
  in `AVAudioConverter.m` by claiming the output buffer's full intended byte range with
  `-setFrameLength:` before calling into AudioConverterServices, not after.

## Checking an application against a release and the backports

`tools/check-app.lua` says, for a built armv7 binary, what stays unresolved on a
release and why. It asks the build's own import check what the binary imports
that neither the release's shared cache nor the backports' libraries export,
and sorts the answer into the imports the backports carry - which are
unresolved only because the binary binds the stock library first, and are cured
by linking `libUIKitBackports.dylib` or `libFoundationBackports.dylib` before it
or by retargeting the weak binding - and the imports nothing carries, which are
what a port is still missing.

    REVENANT_ROOT=/path/to/revenant xmake l tests/backports/tools/check-app.lua \
        6.0 /path/to/band/folder /path/to/App /path/to/Other

The release is one the `~/.revenant/dyld` folder holds a cache of, and the band
folder is the folder of `libFoundationBackports.dylib` and its siblings that the
package builds for that release (`lib` of an installed `revenant@apple-backports`,
or the `bands/<release>` folder of its deb). A binary that already loads the
backports by their install names is checked with those libraries supplied, so
it has nothing left in the first list.

## Reading what a release's library does

The facts behind an `implemented`, `inert` or `ignored` entry come from the release's own library, and
a shared cache holds it with no symbol for an Objective-C method. `tools/cache-methods.lua` lists the
methods of an image's classes with the address of each implementation, and `tools/cache-disasm.lua`
disassembles from an address, naming the string or the selector an `adrp` with an `add` or a `ldr`
reaches:

    xmake l tools/cache-methods.lua ~/.revenant/dyld/12.0/dyld_shared_cache_arm64 CoreLocation CLLocationManager
    xmake l tools/cache-disasm.lua  ~/.revenant/dyld/12.0/dyld_shared_cache_arm64 0x187d5acd8 300

They read the cache file and the sub-caches beside it (`.01`, `.02`, ...) through Revenant's own reader,
`modules/apple/dyld.lua` and `modules/apple/objc.lua` (`image_methods`), so they need no symbol file:
an arm64 cache of iOS 12 has its pointers as a slide chain whose bits are masked off, an arm64e cache
of iOS 16 has authenticated pointers, and its method lists are the small, relative kind whose
selectors sit in the table the cache's Objective-C optimisation header (or libobjc's `__objc_opt_ro`)
names. Where the cache builder attached categories to a class, its method list is a list of lists
and the categories' methods are listed too, with their implementations in the images that carry
them. `tools/cache-disasm.lua` wraps the bytes in a one-section arm64 object whose `__text` sits at
the cache address and disassembles it with `xcrun llvm-objdump` from the Command Line Tools.
`host/cachereader/run.sh` holds the two to a method a cache is known to have.

## Asking a release which C names it exports

`../../tools/corpus/surface-diff.lua` knows the Objective-C classes and selectors the release carries, and no C name, so a
constant or a function that iOS 6 already exports itself shows as a gap, and an `absent` written for it tells an
application that a name is not there when it is. `tools/probe-exports.lua` asks the release: it builds a small
program, runs it in the emulator, loads every framework of the release and calls `dlsym` for each name.

    xmake l tools/probe-exports.lua --registry --workdir "$(xmake l ../../modules/workspace.lua fresh probe)"
    xmake l tools/probe-exports.lua --names names.txt --workdir "$(xmake l ../../modules/workspace.lua fresh probe)"

`--registry` asks about every constant and function the registry lists as `absent`, and exits 1 when the release
exports one, which is the mistake to correct (the entry is the release's own, and says so in a file of facts).
`--names` takes one name a line, a function without its parentheses, for the names a pack of `absent` rows is about to
list: run it before writing the pack. It runs `xmake emulate` with the `XMAKE_GLOBALDIR` of the caller, which must
hold the `revenant latest` addon of the tree named by `--revenant`, and the emulator's answer for iOS 6.0 was the same as an
iPad 2 and an iPhone 4S running 6.1.3 gave.

## Measuring how much of an SDK the registry has decided

`../../tools/corpus/surface-diff.lua` lists what an SDK declares for a framework - every class,
protocol, method, property, extern constant and function, with the release its
availability attribute gives for iOS - and says how much of it the registry has
decided. It reads the SDK the way the build reads one, from clang's AST of the
umbrella header, and needs no addon. A row is decided when the registry lists it
by name, lists its property's accessors, lists its class as `absent` or
`ignored`, or lists its class as `implemented` and the row arrived no later than
the class did; the rest is API nobody has said anything about, which is
`absent` by default, and is the gap the tool counts by framework and release.

    xmake l tools/corpus/surface-diff.lua Foundation UIKit CoreLocation \
        --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk

A macOS SDK is read as Mac Catalyst, whose `System/iOSSupport` carries UIKit and
the other iOS frameworks with the availability of iOS up to that SDK's release;
a framework that exists only on iOS is not in it, and a run against it reports
nothing. An iPhoneOS SDK takes `--target arm64-apple-ios16.4` and has them.
`--above` and `--up-to` cut the releases, `--list` prints every gap, and
`--rows FILE` writes every declared row for other tools to read.

A row with no recorded availability - a member of a protocol whose header carries no attribute is the common one, `UICoordinateSpace` for example - has no release, so the cuts above cannot place it and the count leaves it out. With `--release R` the tool also counts those members whose class or protocol iOS R has no trace of (no class of its own inventory or protocol list of a class), that no class of it answers by selector, and that the registry does not decide, and `--list` prints them with a `?` where the release goes. They are candidates, not proven gaps: a protocol iOS R has and no class adopts shows up too.
A header that lives under a `SubFrameworks` folder of the SDK counts as the framework that imports it: `UICoordinateSpace` is defined in `UIUtilities.framework` and declared forward in UIKit, and its members were not read before.
- `compositional.m` (`compositional-Info.plist`) with `compositional-cases.m`: an application of its own, the compositional layout put in a collection view on a window and held to `compositional-expectations.h`, the system's answers for 182 layouts written by the `compositionallayout` group (the answers are those of a screen of scale 2: at another scale the layouts are not compared). It also checks that the environments a section provider and a custom group's provider are given have the sizes the facts say, that a section that scrolls the other way is nested and its handler called, that what is absent answers no, and it holds the port to `compositional-sized-expectations.h` (estimated dimensions measured from cells: labels, frames, a fixed intrinsic content size, a cell whose `preferredLayoutAttributesFittingAttributes:` sets the height and one that adds to its superclass's answer; and a layout and data source released while a measurement waits are left alone); a label's height in a list is taken from the device's own font at the recorded width, what lies below moved by the difference, and a `note` line names each such height, since the recording's font is the host's; and `compositional-orthogonal-expectations.h` (scripted offsets of the sections that scroll the other way, through `revenant_scrollSection:toOffset:settle:`, numbers compared to one unit in the sixth digit `%g` prints, since armv7's `CGFloat` is a float). It then drags with real touches through `gesture.h` along a section that scrolls the other way (it moves, carries on, and the collection view does not scroll; a drag outside it, or mostly across it, scrolls the collection view and leaves the section; the paging behaviors come to rest on a group or a page; a pull past the start gives and returns), so it needs the application active (run `wake` first). The status bar is hidden by the property list, so the safe area is zero as the host's is. It writes `/private/var/backports/compositional.log` and `compositional.done`.
- `safariviewcontroller.m`: an application of its own, the SafariServices batch: a controller is shown against a small server on the loopback address, and the delegate is asked for the initial load, a redirect, the activities and the dismissal. The rest of what a controller does before it is shown is held to the system's by the `safariviewcontroller` group of `host/uikit2/run.sh`. It needs the package built with `safariservices = true`.
- `aswebauth.m` (`aswebauth-Info.plist`): an application of its own, the web authentication session of iOS 12 over the loopback server `safariviewcontroller.m` uses: the callback URL of a redirect, the error of its own domain with the code 1 for a cancel and for an address that is not a web address, the second start refused and a session with no handler.
- `names-various.m` (`names-various.h`): the 37 names that AVFoundation, AVFAudio, CoreImage, CoreText, MobileCoreServices and MapKit added in iOS 7 to 10 and that are carried, each a symbol of `libAVFoundationBackports.dylib` or `libGraphicsBackports.dylib` with the text the iOS 12 cache holds, and that no session accepts the input priority and 4K presets and the metadata output does not list the QR code.
- `gamecontroller-names.m` (`gamecontroller-names.h`): the 322 names of inputs, keys, haptic localities and the customization notification of GameController that are carried, each a symbol of `libGameControllerBackports.dylib` with the value the host gives it: the strings, the 134 key codes and the infinite duration of a haptic.
- `photos.m`: a command-line test of the photo authorization of `PHPhotoLibrary`: the status is the `ALAssetsLibrary` status, both access levels give it and never limited, and `+requestAuthorization:` is called only when the status is decided already, so no prompt is shown. It needs the package built with `photos = true`.
- `gamecontroller-model.m` (`gamecontroller-model-expected.h`): the controller of software over the profiles, elements and motion: the counts of the elements, their names and aliases, the pressed and touched thresholds of a button, the events of a button and of a direction pad in the order the host gives them, the copy of a state, the capture, the micro gamepad and the motion, each line held to what the host's GameController gives for the same script (`gamecontroller-model.m --print` on the host writes the expected lines).
- `gamecontroller.m`: a command-line test of the GameController classes with nothing attached: the lists are empty, the current device and the coalesced keyboard are nil, the discovery calls its handler once on the main queue, the notification names are the strings of their own names, and the background flag keeps what it is given. It needs the package built with `gamecontroller = true`.
- `gamecontroller-extras.m`: the colour, the event view controller and the classes of the devices that are carried: that the 14 classes come from the backports and have the superclasses of the header, that a colour holds, describes, copies and encodes itself as the host does, and that the event view controller starts with the switch off.
- `secitem.m` (`secitem-Info.plist`, `secitem.entitlements`): an application of its own, the synchronizable attribute of iOS 7 against the keychain of the release: the two constants and the library they come from, an item added with the attribute true and false, and what a query for it, for not, for Any and for nothing finds. The entitlements give the application a keychain access group, without which every `SecItem` call answers -25308 whatever it asks. Install `revenant-sblaunch` first and run `su mobile -c uicache` before launching. It needs the package built with `security = true`.
- `securitydemand.m`: a command-line test of the keychain names of iOS 8 and 9 and the shared web credential functions: the eleven constants as their strings, `SecAccessControlCreateWithFlags` answering NULL with `errSecUnimplemented`, the two blocks of the shared web credential functions and the shape of the passwords `SecCreateSharedWebCredentialPassword` makes. `secitem.m` also holds what the keychain of iOS 6 does with the keys, on a device of iOS 6 only: -50 for each. It needs the package built with `security = true`.
- `scenekit-decode.m`: a command-line test of the .scn decoder on archives written here by stand-in classes under SceneKit's and AppKit's class names, decoded with secure coding as `SCNScene` does: a single object where a key usually holds an array (particle systems, a child, a material, an element), a string under such a key or inside its array when decoded without secure coding (left out, one log line), an `NSColor` the port cannot read (the property keeps its default and one log line names the key, read from standard error) beside a device RGB colour, the same in a material (the slot keeps the material's default, white or black, while a slot archived with no colour stays nil as on macOS), a physics world's decoded and set values with its one line saying nothing is simulated, and a flag stored as a string. Needs no OpenGL, so it runs in `xmake emulate`. It needs the package built with `scenekit = true`.
- `scenekit-defaults.m` (`scenekit-defaults-cases.m`, `scenekit-defaults-expectations.h`): a command-line test of what new objects of ten SceneKit classes answer for every property the port carries, held to the answers `host/scenekit-defaults/refresh.sh` records from macOS SceneKit (six significant digits, one unit in the last). Runs in `xmake emulate`. It needs the package built with `scenekit = true`.
- `scenekitprojection.m` (`scenekitprojection-expectations.h`): the port's `SCNSceneRenderer.projectPoint` and `unprojectPoint`, held to the sixteen answers `host/scenekitprojection/project.swift` records from macOS SceneKit's own renderer for the same camera, viewport and eight points. The host's renderer is given one offscreen frame first, because a renderer that has not rendered answers its input back unchanged; the device test renders for the same reason, and skips itself and says so where there is no OpenGL ES 2.0 context. The comparison's own mutant is in the test: a mirrored `y` has to be rejected for every point, and 0.05 of a unit is the tolerance - four orders tighter than the flip that error actually produced, and four wider than the float rounding the two sides share. Built by `device/build-scenekitprojection.sh`, the clang line a test for the target needs and that no script here assembled. Needs the package built with `scenekit = true`.
- `scenekit.m` (`scenekit-expectations.h`): SceneKit's matrix functions, a node's rotation conventions, `SCNView`'s defaults and the delegate messages of `-snapshot`, held to what `host/scenekit/run.sh` records from macOS SceneKit. Without OpenGL ES 2.0 (the emulator) it checks the rest and says what it skipped. It needs the package built with `scenekit`, `opengles` and `uikit`.
- `scenekit-lighting.m` (`scenekit-lighting-expectations.h`): the `SCNView` shader over the lighting grid, one pixel per case, within one level of macOS SceneKit's pixel (`host/scenekit/lighting/cases.sh`), except seven cases at roughness 0.01 and 0.02 that the test names as known open and holds to staying more than one level off (a case that changes state, either way, fails). Its negative control is a check on the grid's data, not on the port: the grid must keep the cases whose pixel for a renderer with the roughness 0.02 too large is more than two levels from SceneKit's (256), which a port within one level of SceneKit's cannot match; the specular exponent has no such case (a renderer with it 3% too large is within two levels of SceneKit's on every case), so nothing holds it. It also prints what the GPU's fragment floats hold, the largest texture and whether `GL_OES_element_index_uint` is there, and checks that a light and a camera with an animated position are drawn at the presented position. Needs a device.
- `scenekit-animation.m`: `scenekit-animation <case>` prints the series of one of Telegram's animations as the port's `SCNView` draws it; `host/scenekit/animation/compare.py` holds the eight cases to macOS SceneKit's series. Needs a device.
- `gl-extensions.m`: prints the GPU's OpenGL ES 2.0 renderer, version and extensions, which decide how `SCNView` holds a colour slot's image (half floats in linear light, or the encoded image). Needs a device; links nothing of the package.
- `scenekit-frames.m`: `scenekit-frames <scene.scn> <points> <out.png> [switch...]` writes `SCNView`'s snapshot of a scene after the same switches `host/scenekit/render.swift` takes (no particles, no subdivision, no clear coat, no normal contents) and, for the negative control only, `roughness+D`, and switches that take one slot of every material off (`nometalness`, `noselfillumination`, `noemission`, `flatdiffuse`); `host/scenekit/frames.sh` prints how far its frames of star2 and coin are from macOS SceneKit's, and a renderer a little wrong beside them (no bound yet). Needs a device.
- `uiview-kvo.m`: a command-line probe of what KVO of a `UIView`'s `frame` and `bounds` fires on nine ways of changing a view's geometry, beside the calls its two setters get, and of what KVO does with an observer left on a view that deallocates (`facts/UIKit/UIDynamicAnimator.md` M3). Runs in `xmake emulate` on 4.3 (`-d iPhone3,1`, linking arclite with `-fobjc-arc` on the link line), 5.1.1, 6.0 and 6.1.3; path (f) is skipped where `NSLayoutConstraint` is absent (below 6.0); it is not an app, so it needs no SpringBoard.
- `dynamics-watch.m`: a command-line program of the shipped `UIDynamicAnimator`'s watch of its reference view, on an emulated 4.3, 5.1.1, 6.0 and 6.1.3 with `revenant@apple-backports` linked (the target waives `revenant.waive.weak-imports` with its reason below 6.1.3): which changes of the view wake a resting animator, and that no KVO leak line is logged when the animator or the view is released first (`facts/UIKit/UIDynamicAnimator.md` M3). With no display in the process (`[UIScreen screens]` empty after its first view, as on 4.3) the wake checks are skipped with a line each and the lifetimes run whole; the last line it prints says how many checks failed and how many were skipped, which the run's own verdict (`pass`, the exit status) does not.
- `display-probe.m` (`display-probe/xmake.lua`, `display-probe/control`, `display-probe/run.sh`): a command-line probe of whether a process that is not an application has a display, by the public routes (`[UIScreen mainScreen]`, `[UIScreen screens]`) and by the private `+[CADisplay mainDisplay]` for comparison, and what one display link does there (on 4.3 it faults in QuartzCore, and the probe catches the fault to print where). A second argument makes the process do more first: a view, a window made key and visible, a run loop turn, thirty seconds of turns waiting for a screen, or `UIApplicationMain`. Its build decides two things the program cannot: the binary's `apple_minimum` and whether `revenant@apple-backports` is linked, so `display-probe/run.sh <release>` builds every combination for the release (`4.3` and the release's own, with and without the package) and runs each mode in a run of its own, on an emulated 4.3, 5.1.1, 6.0 or 6.1.3 (`facts/UIKit/UIDynamicAnimator.md` M3). It needs the addon v0.8.11 in the shared xmake store.
- `nsuuid.m` (with `below6/`): a process of its own, `NSUUID` through the name an application writes, on an emulated 6.0 (the release's class, the reference), 4.3 and 5.0 (the backports' class from `libFoundationBackports.dylib`): parsing, the hash held to 6.0's measured values and to NSData's for 2000 random UUIDs, equality, the archive key, `compare:`, the class cluster and the answers where the port follows the newest release and not 6.0 (`facts/Foundation/NSUUID.md`). `below6/run.sh nsuuid` builds one binary at `apple_minimum` 4.3 with `revenant@apple-backports` linked, runs it on each release and holds the `answer` lines of 4.3 and 5.0 to 6.0's; `below6/xmake.lua` names the programs, one per class the backports carry below iOS 6. It is a heavy job.
- `progress.m`/`progress-cases.m` (with `below6/`): the same `-addChild:withPendingUnitCount:` cases `host/progress/run.sh` already records from the host, run through `below6/run.sh progress` on an emulated 6.0 (the release's class), 4.3 and 5.0 (`Foundation/NSProgress.m`, the class the backports carry below iOS 6): children, fractions, KVO, cancelling and pausing a child, and release. `tests/backports/host/progress2/run.sh` holds the class alone (renamed) to the host's own `NSProgress` for the surface `progress-cases.m` does not reach - the current-progress stack, `isIndeterminate`, `resume`, the handlers - with four named tolerances where iOS 6's own measured answer differs from the host's newest one (`facts/Foundation/NSProgress.md`).
- `accelerate7.m` (`accelerate7-cases.m`, `accelerate7-expectations.h`): a command-line test of the three vImage functions that connect it to CoreGraphics, over every format the port makes and the sizes and background colours of the cases, held to the answers `host/accelerate7/refresh.sh` records from the host's vImage (within one level), with the errors of a wrong format or flag. `host/accelerate7/run.sh` runs the port beside the host's own on the host. It needs the package built with `accelerate = true`.
- `linearalgebra.m`: a command-line test of the 44 BLAS and LAPACK entry points of Accelerate, the 42 `la_*` of `vecLib/LinearAlgebra` and the two `appleblas_*` of the CBLAS extension: every one of them called, the statuses and the shapes exactly and the elements to the six significant digits a float has, held to the answers `host/linearalgebra` records from the host's own Accelerate, and the two entry points of the threading model of iOS 18 (which no header of the build SDK declares, so they are reached the way a C client reaches them) with the refusal of a value the library does not have. `host/linearalgebra/run.sh` runs the port's `LinearAlgebra8.m` and `AppleBLAS8.m` beside the host's own on the host - 164 checks - and `host/appleblas/run.sh` the geadd alone, 22 checks, with a bad parameter run in a child process each because the release's own `cblas_xerbla` ends the process. It needs the package built with `accelerate = true`.
- `vdsp.m`: a command-line test of the twenty-two elementwise vDSP entry points of Accelerate, the 24-bit conversions of iOS 7.0 in both readers and both clamps, the integer add, the split-complex products in one precision and in the other, the two sums-and-differences, the four ramps, the two sliding window maxima, the scaled multiply-multiply-add, the two dot products and the distance - every one of them called and held to the answers `host/vdsp` records from the host's own vDSP, element by element, including the three where the operation is not the one the name reads as (`vDSP_vaddsub`'s second output is the second operand minus the first, the ramps leave the start at the end of the ramp, and `vDSP_vsmsmaD`'s B is a scalar at B[0]) and the buffer sizes the sliding window maximum reads and writes. `host/vdsp/run.sh` runs the port's two object files beside the host's own vDSP - 59 checks. It needs the package built with `accelerate = true`.
- `graphicsnames.m`: a command-line test of `kCIInputAngleKey`, `kCIInputRadiusKey` and `kUTTypeScalableVectorGraphics`: their strings, the library they come from, and that the release's Gaussian blur and straighten filter read their radius and angle under them. It needs the package built with `graphics = true`.
- `cametal.m`: a command-line test of `CAMetalLayer` with no Metal: the class comes from the backports, the properties keep what they are set to and start as the header says, the drawable size follows the bounds until it is set, `nextDrawable` is nil, the properties of iOS 16 keep what they are given, and a maximum of drawables outside 2 to 3 raises with the reason of iOS 12. It needs the package built with `metal = true`.
- `photos8.m`: the Photos classes over `ALAssetsLibrary`: that the 17 classes and the keys come from the backports, the defaults of the fetch and request options, the exception a request raises outside a change, an empty fetch until the application is authorized, and, when it is, a change that adds two images (one with a date and a location), the placeholder before and after, the fetches by identifier, media type, predicate, sort and limit, the smart albums, the images at fitted, filled, exact and maximum sizes, the data, an asynchronous and a cancelled request, and a video request for an image; the deleting and favorite changes must fail with `PHPhotosErrorChangeNotSupported`. It adds images to the library it runs against, and iOS 6 lets no application delete them. Built as a daemon it sees a library that the daemon is not authorized to read, so the content checks need an application whose photo permission is decided.
- `photoschanges8.m` (`photoschanges8-Info.plist`): an application of its own, the change observers of `PHPhotoLibrary`: first what the release itself posts for a write (`ALAssetsLibraryChangedNotification`, its thread and keys, and that it names the new asset by the identifier the port gives it), then an observer held weakly and told off the main thread after a write, the fetch result details of the saved photos (one insertion, incremental, no moves), no change for an untouched asset, the album that changed, nothing told once unregistered, and `changeDetailsFromFetchResult:toFetchResult:changedObjects:`. It adds three 8-by-8 blue images to the saved photos on each run; a daemon is refused the library by iOS 6, which gives it to a bundle identifier the user allowed. Results in `/private/var/backports/photoschanges.log` and `.done`.
- `photosresources9.m`: `PHAssetResourceManager`'s cancellation, in a process of its own with the Photos sources built in: a request of a resource with no asset behind it completes once with the asset's error (the control), and 50 requests cancelled right after the call each complete once, with no data, with `PHPhotosErrorUserCancelled` unless they had completed before the cancel; a later request is not cancelled by a cancel of another. It needs no photo library the process may read.
- `photosdata9.m` (`photosdata9-Info.plist`): an application of its own, the data of `PHAssetResource` read back through `PHAssetResourceManager`, with the Photos sources built in: a video of blue noise, a few megabytes, written with `PHAssetCreationRequest` into a new album `RevenantPhotosProbe-<time>` whose request the block makes first, which then holds it, read back in chunks that are together the bytes of a direct `ALAssetRepresentation` read, none empty, more than one, with progress rising once per chunk to 1.0; a read cancelled at its first chunk hands over no other and completes once cancelled; `writeDataForAssetResource:` leaves those bytes in the file, replaces a file that was there, and a write that fails leaves the file as it was and nothing beside it; `shouldMoveFile` leaves a file not moved where it was, removes a moved one once the asset is made, and refuses a hard-linked file with `PHPhotosErrorInvalidResource` before anything is written; a video given as data is added and the file it was staged in is gone after the change. Each error of the port is the header's code for the case it is made to happen in: a creation request with no resource `PHPhotosErrorMissingResource`, photo data that is not an image and an image with no pixels `PHPhotosErrorInvalidResource`, an asset no committed change made added to the album and a resource with no asset `PHPhotosErrorIdentifierNotFound`. It adds one such video, four 64-by-64 solid-blue videos and one album to the library on each run; the photo permission of `local.revenant.backports.photosdata` must be granted once, on the first launch. Results in `/private/var/backports/photosdata.log` and `.done`.
- `photosalbums8.m`: the name check of an album's creation when the release refuses to list the albums, in a daemon (which 6.1.3 denies the photo library) with the Photos sources built in: the release's own enumeration fails (the control), and the store's album check and the creation request's validation fail with that same error instead of answering "no such album". Nothing is written.
- `photosavailability13.m`: a process of its own, in the state 6.1.3 puts a daemon in (the release denies it the photo library), what `-[PHPhotoLibrary unavailabilityReason]` of iOS 13 answers there -- an `NSError` in `PHPhotosErrorDomain` with the header's own 3311 -- and the rules of `-registerAvailabilityObserver:` / `-unregisterAvailabilityObserver:`: weakly held, a registration while the library is already unavailable is told nothing, a double unregister is not a crash, a notification with no observer alive reaches nobody. It writes nothing and reads no asset, so it runs on any device; the authorised case (a nil reason) needs an application and is named as unmeasured in `facts/Photos/Availability.md`.
- `photos/run.sh` builds `photoschanges8.m`, `photosdata9.m`, `photosalbums8.m` and its own `control.m` from this tree's Photos sources (no package installed, so a run measures the tree it is run from and the canon on the device is left alone), pushes each through the driver's own transport, and prints what every program reported: the figure line, every `FAIL` line, and a run with no report is a failure of the run, not a silence. `sh tests/backports/device/photos/run.sh --control photosalbums8` needs only a claim (`xmake device --minutes=20 claim`); it builds `photosalbums8` and the control, and the control must fail, which is what makes the figure above mean something. The two programs that WRITE to the photo library are refused unless the device is the iPad 2 (the one holding the fleet's own `RevenantPhotosProbe` fixtures) or `PHOTOS_ALLOW_WRITE=1` says that device's library is a test library. The claim is the operator's; the script refuses a device held by someone else.
- `record-filter.m`: the record permission of the audio session (granted, and the request answering YES once off the main thread) and `-[CIImage imageByApplyingFilter:withInputParameters:]` held to the filter made by hand (defaults, an unknown filter giving nil, an unknown key raising, the input image replaced).
- `names-more.m` (`names-more.h`): the 836 constant strings of AVFoundation, ImageIO, Security, CoreVideo, QuartzCore and CoreTelephony that iOS 7 to 12 added and that are carried, each a symbol of one of the backports libraries with the text the iOS 12 cache holds.
- `audiosession-inputs.m`: the available inputs of the audio session are those of the current route, a preference for nil or for the input in use succeeds and is kept, and an input that is not in the route is refused with the error of a resource that is not there.
- `phpickermodel.m`: a command-line test of the PhotosUI model questions, built like a port image (the objects of `Photos/` and `attach.c` linked in, so the categories of iOS 15 and 16 are attached) and needing no window server: the four inputs the Mac Catalyst host does not answer at all - an empty array and a nil one to `+[PHPickerFilter allFilterMatchingSubfilters:]`, a nil one to `+notFilterOfSubfilter:`, and `PHAssetPlaybackStyleUnsupported` to `+playbackStyleFilter:` - the eight filters the queue names, the configuration's defaults and its copy, the two methods of iOS 16 and the two forms of the limited library picker. Run it as `mobile` and read `/private/var/backports/phpickermodel.done`; 38 checks, measured 0 failures on an iPad 2 running 6.1.3. It is a command-line test and not an application because `phpicker.m` needs a bundle SpringBoard will start, and a device without `/private/var/tmp/sblaunch` will not start one - the model questions are answerable without that and the presentation ones are not.
- `phpicker.m` (`phpicker-Info.plist`): an application of its own, the photo picker of iOS 14 over the release's `UIImagePickerController`: the configuration and its copy, the controller that holds the release's picker as a child for the media types of the filter (on an iPad in a popover and modally), one result or none reported once on the main thread, the item provider that loads the chosen image as a `UIImage` through `UIImage`'s own provider methods, and a filter that matches nothing of the release. The choice is fed to the delegate by hand, since a test cannot tap the library. It needs the package built with `photos = true` and `uikit = true`; launch it with `revenant-sblaunch` after `su mobile -c uicache`.
- `visualeffect.m` (`visualeffect-Info.plist`): an application of its own, the blur of `UIVisualEffectView`: over four coloured stripes it puts a light and a dark effect view and one with no effect, and reads the picture each shows, at a stripe's middle and at the line between two, for the tint, the blur, the dark one being darker, the view following what changes behind it, and the time a refresh takes. Launch it with `revenant-sblaunch`; the screen must be on, and `wake` puts it on for a device with no passcode.
- `metal.m`: a command-line test of `MTLCreateSystemDefaultDevice`: it comes from the backports, answers nil twice, and neither MetalKit nor the device protocol is there. It needs the package built with `metal = true`.
- `avauthorization.m`: a command-line test of the camera and microphone authorization of iOS 7: both statuses, the exception for another media type with its reason, and a request that calls its handler once off the main thread. It needs the package built with `avfoundation = true`.
- `coregraphics7.m` (`coregraphics7-cases.m`, `coregraphics7-expectations.h`): a command-line test of CoreGraphics colour spaces: the release's own `CGPathAddRoundedRect`, `CGPathCreateWithRoundedRect`, the generic colour functions and the constant colours over 265 cases held to the answers `host/coregraphics7/refresh.sh` records from the host's CoreGraphics, and the predicates and `CGColorSpaceCopyICCData` of `libGraphicsBackports.dylib`. `host/coregraphics7/run.sh` runs those predicates beside the host's own. It needs the package built with `graphics = true`.
- `coretelephony.m`: a command-line test of the radio access technology of iOS 7: the eleven names as their own strings, the notification name, and `currentRadioAccessTechnology` answering nil or one of the names, with the misspelled WCDMA of 6.1.3 given the value of iOS 7. It needs the package built with `coretelephony = true`, and the name of the technology depends on the network the phone is on.
- `textkit7.m`: an application of its own, the text batch of iOS 7: the attribute names, the document types, `NSTextTab` and what the release's HTML, RTF and plain-text import gives, read against the host's answers recorded by `host/textkit7/run.sh` from `textkit7-cases.m`.
- `nsdataasset.m`: an application of its own, `NSDataAsset` reading the small compiled catalogue in `data-assets/Assets.car` (written by `host/nsdataasset/make-car.py`); the group `nsdataasset` of `host/uikit2/run.sh` compares the port to the system's class on a catalogue an application was built with, named by `REVENANT_DATA_ASSET_CATALOG`.
- `opengles.m`: an application of its own, the ES 3.0 functions in an ES 2.0 context: vertex arrays, occlusion queries, fence syncs, mapped buffer ranges, immutable textures and multisampled renderbuffers through the release's extensions, and the errors of the calls with no answer. The library is `OpenGLES/ES3Functions.m` and `ES3Queries.m` of the package, first generated from the SDK's two headers and maintained as source since. It needs the package built with `opengles = true`.
- `imageextract.m`: an application of its own, the files `tools/assets-extract` wrote from a catalogue (`IMAGE_EXTRACT_DIR` in the build script): every name of the index is found by the stock `+[UIImage imageNamed:]`, at the scale and size of the best file for the screen.
- `uikitnames.m`: an application of its own, the names and small classes of iOS 7 to 10 - the transition context keys, the screenshot and background-refresh notifications, the activity types, the callout and title text styles, the edge pan recognizer and the percent-driven transition - read against the host's answers recorded by `host/uikitnames/run.sh` from `uikitnames-cases.m`.
- `foundation8b.m`: the names of iCloud metadata and app extensions, the deallocator blocks and file access intents of iOS 7 to 10, read against the host's answers recorded by `host/foundation8b/run.sh`: the intents are coordinated on a real folder, alone, together and for an item that is not there.

`host/previewaction/run.sh` records what the host's UIKit answers for `UIPreviewAction`,
`UIPreviewActionGroup` and `-previewActionItems` in `device/previewaction-cases.m`, and
`device/previewaction.m` runs the same cases against the port on the release, record by record.

`host/invalidation/run.sh` records what the host's UIKit answers for the collection view
invalidation contexts and for `-invalidateLayout` routed through `-invalidateLayoutWithContext:`
in `device/invalidation-cases.m`, and `device/invalidation.m` compares the port record by record.

`host/presentation/run.sh` records what the host's `UIPresentationController` answers in
`device/presentation-cases.m`, in a Mac Catalyst application with a window, and
`device/presentation.m` compares the port record by record on the release.

`host/imageio/run.sh` runs `device/imageio.m` against the host's ImageIO, and the same tool runs on
the release against the port: the key `kCGImageSourceShouldCacheImmediately` is the string ImageIO
gives it, and an image made with it set is the image made without it.

`host/inputview/run.sh` records what the host's `UIInputView` answers in `device/inputview-cases.m`,
in a Mac Catalyst application with a window, and `device/inputview.m` compares the port on the release.

`host/fontkeys/run.sh` records the strings of the eighteen `UIFontDescriptor` keys from the host's UIKit into
`device/fontkeys-cases.m`, and `device/fontkeys.m` compares the port's on the release and against the release's own CoreText
constants.
- `orderedcollections.m`: a process of their own, Foundation only, the difference of two arrays and two ordered sets: 1600 cases of
  `orderedcollections-cases.h` (differences with every option, their descriptions and inverses, applying, equivalence tests, and differences built from
  changes that are refused) are held by fingerprint to `orderedcollections-expectations.h`, which `host/orderedcollections/run.sh` records from the host's
  Foundation. The `orderedcollections` group of `host/uikit2/run.sh` compares the port to the system on 320000 more.
- `diffable.m` (`diffable-Info.plist`): an application, the diffable data sources: 800 cases of `diffable-cases.h` - random sequences of snapshot
  and section snapshot operations, with their exceptions - are held by fingerprint to `diffable-expectations.h`, which `host/diffable/run.sh` records
  under Mac Catalyst; eleven scenarios say which cells the provider is asked for, the ones the system asks for; and forty random snapshots
  are applied to a collection view and a table view, and the view has to be as the snapshot says after each. The `diffable`, `diffablesection`,
  `diffabledatasource` and `diffablesectiondatasource` groups of `host/uikit2/run.sh` put the port beside the system's classes; the last two run
  in a window. It writes `/private/var/backports/diffable.log` and `diffable.done`.


`host/personname/run.sh` records what the host's `NSPersonNameComponents` does in `device/personname-cases.m`, and
`device/personname.m` compares the port on the release. `host/presses/run.sh` does the same in a Mac Catalyst application with a
window for `UIPress`, `UIPressesEvent`, the presses messages of `UIResponder` and `UICollectionViewTransitionLayout`, and
`device/presses.m` compares them.

`swipeui.m` (`swipeui-Info.plist`) is an application for both devices that checks the swipe actions of a table with real touches:
it sends digitizer events to the HID event system from a queue of timed steps and reads what the table, the delegate and the
buttons do - the row slides and shows its buttons, a tap runs a handler with the index path, a swipe across the row runs the
first action, a tap elsewhere or a scroll closes it, a table whose delegate answers nothing is left alone, and the configuration
of iOS 11 does the same for both edges and a full swipe. There is no host oracle: the host's UIKit draws no swipe buttons. It
writes `/private/var/backports/swipeui.log` and `swipeui.done`.

`keycommand.m` (`keycommand-Info.plist`) is an application for both devices that checks the key commands of iOS 7 with key events made by `GSEventCreateKeyEvent` and handed to `-[UIApplication handleKeyEvent:]`, the entry the release gives a hardware key: the command of the nearest responder runs with the command as its sender, modifiers must match exactly, a key going up and a key that is no command do not run one, the arrows and escape are found by key code and by character, and a command its responder cannot perform is passed on. It has no host oracle (Mac Catalyst has no such entry) and no hardware keyboard was attached to a device, which `facts/UIKit/KeyCommands.md` says.

`activity.m`, `keyboardlocal.m` and `openurl.m` (each with its `-Info.plist`) are applications for both devices with no host oracle, because a macOS process has no idle timer, no software keyboard and no URL delivery of this kind: `activity.m` reads `UIApplication.idleTimerDisabled` around `NSProcessInfo` activities (nested, ended twice, begun on another thread, the application's own setting kept), `keyboardlocal.m` shows the real keyboard and reads `UIKeyboardIsLocalUserInfoKey` in the four notifications UIKit posts, and `openurl.m` gives an application whose delegate has only `-application:openURL:options:` the old call and a real URL sent to its own scheme.

`device/interactivepan.m` (`interactivepan-Info.plist`) pulls a presented controller down with a pan gesture driven by real touches on a device and a `UIPercentDrivenInteractiveTransition`: a third of the way the controller below shows at the top and the coordinator is interactive, let go at 30% the dismissal is cancelled and the controller covers the screen again, let go at 70% it finishes; the screen is read as pixels (`interactivepan-*.png`).

`host/custompresentation/run.sh` records what the host's UIKit does with a `UIPresentationController` subclass that dims and insets its presented view (four variants: it keeps the presenter's view, it removes it, no animator, `shouldPresentInFullscreen`), into `device/custompresentation-expectations.h`: the callbacks and their order with the controllers' appearance callbacks, the container, the presented view and its frame, the context of the animator, what stays in the window, and whether the presenting view is where it was before the presentation while presented and after the dismissal - for the four variants, for the release's own full-screen presentation as the control, and for a full-screen presentation with an animator dismissed through a `UIPercentDrivenInteractiveTransition`; `device/custompresentation.m` holds the port to the same records on a device (on the iPad 2 the root view is under the status bar, 0 20 768 1004, and must stay there).

`host/sheet/run.sh` records what the host's own `UISheetPresentationController` and its detents answer - the constants, descriptions and equality of detents, their resolution for eleven containers, which styles have a sheet and when it is made, the defaults - into `device/sheet-expectations.h`; the host shows a sheet in a window of its own, so the layout is not recorded. `device/sheet.m` (`sheet-Info.plist`, the phone family only, so an iPad runs it phone-sized) holds the port to the records and checks the layout of a large, a medium and a stacked sheet against the values read from UIKitCore 16.0 (`facts/UIKit/UISheetPresentationController.md`), that a tap on the grabber moves between detents and, while a text field in the sheet has the keyboard, ends editing, that the keyboard holds the sheet at its first detent, and that the presenter is itself again once they are dismissed. It ran on an iPad 2 (6.1.3): 56 checks.

`device/releasesheet.m` (`releasesheet-Info.plist`, the phone family only) presents the release's own controllers without a style from a program linked with SDK 13 or later - the activity view controller, the preview controller, the media picker, the image picker and, where the device can send, the mail, message and social composers - and checks that each resolves as iOS 13 does (the port's sheet at its large detent, or the release's own presentation for a controller whose initializer sets a style) and that the presenter is itself again after the dismissal. Build it with `-lUIKitBackports -lMediaPlayerBackports -framework MessageUI -framework Social -framework QuickLook -framework MediaPlayer -framework CoreGraphics`. It ran on an iPad 2 (6.1.3): 16 checks, the composers skipped for want of an account.

`host/sheetmetrics/run.sh` holds the constants the port's sheet takes from UIKitCore 16.0, read from `UISheetPresentationController.m` itself, against the host's own `_UISheetPresentationMetrics` under Mac Catalyst: the top offsets, the maximum depth, the transition's duration and its springs agree; the host's corner radius (8, a later design) differs from 16.0's 10 and is checked to differ.

`host/sheetshadow/run.sh` asks the host's UIKit what the sheet's "magic" shadow is made of (the kit image, the shadow view's frame and cap insets) and checks that the vibrant colour matrix 16.0 gives it takes its colour from what lies behind the layer - over red, blue, grey and white it leaves the matrix of the destination laid over it with the layer's alpha - with a colour matrix that reddens the layer as the control that the capture shows filters at all. It fails if the host stops reading the destination; the port's ledger entry for the shadow rests on it.

`host/sheethandover/run.sh` runs the port's installer (`UIViewController+TransitionCoordinator.m`, the file itself) against the host's UIKit under Mac Catalyst, which has its own `UIPresentationController` and so takes the branch a device from 8.0 on takes and no log of a 6.1.3 device reaches. The host's own sheet stands in for the port's class; what is held is the installer: a controller is asked for its sheet only when it is presented as a page or form sheet from a compact width (not from a regular one, not full screen), the release presents it through the handover (the style is put back, the caller's delegate is asked first for the animators and is back after the dismissal, the caller's detents are the ones presented), and the sheet a dismissal took away is neither kept nor freed late, as UIKit's own controller has none after it. It fails if an ask, a hold or the delegate changes.

`device/modaldefault.m` holds the default `modalPresentationStyle` to UIKitCore 16.0 (`facts/UIKit/UIModalPresentationAutomatic.md`), a process of its own built twice against the band, as the toolchain links it and with an older SDK in its load command:

    clang ... -DMODALDEFAULT_LINKED_ON_13=1 device/modaldefault.m device/check.m -LBAND -lUIKitBackports -lAVKitBackports -lMediaPlayerBackports -framework UIKit -framework MediaPlayer -framework Foundation -o modaldefault13
    clang ... -DMODALDEFAULT_LINKED_ON_13=0 -Wl,-platform_version,ios,6.0,12.4 device/modaldefault.m device/check.m -LBAND -lUIKitBackports -framework UIKit -framework Foundation -o modaldefault12

The first expects the page sheet from every way a controller is made without a style, the second full screen; both keep a style that is set or archived. The first also expects full screen from AVKit's player and the page sheet from MediaPlayer's media picker, their own preferences. Both ran on an iPad 2 (6.1.3), with the band's libraries beside them: 13 and 7 checks.

`host/imagenamed/run.sh` compares `+imageNamed:inBundle:compatibleWithTraitCollection:` with the host's own, through Mac Catalyst, on a folder of loose files (extensions, scales 1 to 3, the pad's files, a JPEG, absent and empty names) under no traits and under every pair of scale and idiom, and writes `device/imagenamed-expectations.h`; `device/imagenamed.m` holds the port to them on the iPhone 4S and the iPad 2 and checks the files for the phone itself.

`host/appgroup/run.sh` compares `-containerURLForSecurityApplicationGroupIdentifier:` with the host's own Foundation, through Mac Catalyst, over 20 identifiers (with the home directory moved, so both write under one place), and writes `device/appgroup-expectations.h`; `device/appgroup.m` holds the port to them on the iPhone 4S and the iPad 2 and checks that the container is a directory that can be written and is found again.

`host/fitting/run.sh` records what the host's UIKit answers for `systemLayoutSizeFittingSize:withHorizontalFittingPriority:verticalFittingPriority:` on a view whose label wraps (widths, the compressed and expanded sizes, required and low priorities) and `device/fitting.m` holds the port to it.

`host/flowauto/run.sh` records the frame of every item and the content size of a flow layout that self-sizes, in 16 scenarios (fixed-width cells, height-only cells, cells of their own width, insets, spacing, headers, a delegate's sizes, the automatic size, last lines, cells with no constraints); `device/flowauto.m` builds them on iOS 6 and compares to the pixel, or to a point where the cell's width comes from its text.

`device/keyboarddismiss.m` opens the keyboard on a text field outside a scroll view and drags a real finger over the scroll view in the four modes (none keeps the keyboard, on drag dismisses it, interactive keeps it above the keyboard and dismisses it when the finger reaches it).

`device/interactivepop.m` drags a real finger from the left edge of a navigation controller: a drag past the middle pops a page and the top page follows the finger, a short drag leaves it, a disabled recognizer and a delegate that says no keep the page, and the root page stays.

`device/smallapis.m` holds `completionWithItemsHandler` of an activity controller and the alternate icon calls (unsupported, with the error of a feature that is not there) on a device.

`host/suitedefaults/run.sh` compares `-initWithSuiteName:` of NSUserDefaults with the host's own over 50 typed reads, writes, registered defaults, URLs and a second instance, and writes `device/suitedefaults-expectations.h`; `device/suitedefaults.m` holds the port to them.

`host/coordspace/run.sh` records what the host's UIKit answers for the coordinate spaces - nested views, a sibling, the window and the two spaces of a screen, converted to and from each other, with the protocol and the bounds - into `device/coordspace-expectations.h`; `device/coordspace.m` holds the port to them.

`host/fontdesc/run.sh` records what the host's UIKit answers for `UIFontDescriptor` - descriptors of Helvetica, Courier and Times New Roman by name and family, every change of them, the matching descriptors, the fonts `+fontWithDescriptor:size:` gives, equality and archiving - into `device/fontdesc-expectations.h`; `device/fontdesc.m` holds the port to them (the lower symbolic traits only: the release's CoreText gives a font's class and its monospace trait its own way).

`host/popover/run.sh` records what the host's UIKit answers for `popoverPresentationController` of a controller with the popover style - none before it is set and for other styles, the same one each time, the defaults of every property and what is kept - into `device/popover-expectations.h`; `device/popover.m` repeats them and presents popovers with real touches: on an iPad a touch outside asks the delegate and dismisses, a passthrough view keeps its touch, a dismissal by the application calls its completion and is not told to the delegate, a popover with no source is refused; on an iPhone the presentation is adapted to full screen through the delegate's answers (`popoverphone.m` is the same test with a property list for the iPhone only, which an iPad runs in its phone mode). (A passthrough view under a navigation controller does not work in iOS 6's own popover controller either, so the test has none.)

`host/exclusion/run.sh` records the line fragments the host's UIKit lays one text (Courier 14, a container 200 by 400) into beside ten exclusion path layouts - a rectangle at the top right, at the top left, in the middle, an oval, a triangle, two rectangles, a band across the width, a rectangle wider than the container, a gap too narrow for a glyph and a rectangle below the text - into `device/exclusion-expectations.h`; `device/exclusion.m` builds them on iOS 6 and compares the glyph ranges exactly and the rectangles to two points.

`host/textattr/run.sh` records what the host draws of one text with each text attribute of iOS 7 - the underline and strikethrough colours, obliqueness, expansion, kern, baseline offset, stroke, letterpress and a writing direction override - drawn by `drawAtPoint:`, a label and a layout manager, measured as pixels of colour and the width, position, lean and centre of the ink, into `device/textattr-expectations.h`; `device/textattr.m` draws them on iOS 6 and compares (the release draws five of the six new names and does not draw the letterpress effect, which the test holds to the plain picture).

`device/guideitem.m` puts a layout guide into constraints by every way the release offers - each of its `constraintWithItem:` constructors, a visual format, the guide's anchors - adds and lays them out and asks for their descriptions, which sends the layout engine's `nsli_` messages, gives a constraint the guide itself as an item past the constructors and has the engine place the guide by it, and asks a guide for the `nsli_` messages a view answers.

`host/layoutsupport/run.sh` records what the host's UIKit answers for `topLayoutGuide` and `bottomLayoutGuide` of a controller in a window - present, stable, distinct, conforming to `UILayoutSupport`, lengths, anchors, and a view constrained between them - into `device/layoutsupport-expectations.h`; `device/layoutsupport.m` repeats them and then puts a controller with a full screen layout under a translucent navigation bar and over a translucent toolbar and holds the lengths to the bars and a view between the guides to what is left.

`host/tableestimates/run.sh` records what the host's UIKit does with `estimatedRowHeight`, `estimatedSectionHeaderHeight` and `estimatedSectionFooterHeight` of a plain and a grouped table - the defaults, what is kept, the refusal of a negative value in the words of each of the three, key-value coding - into `device/tableestimates-expectations.h`; `device/tableestimates.m` holds the port to them.

`device/receipturl.m` asks the main bundle and another for `appStoreReceiptURL`, which iOS 6.1.3's own method answers by raising: the file `StoreKit/receipt` in the bundle asked, and no raise.

`host/documentmenu/run.sh` records what the host's UIKit does with `UIDocumentMenuViewController` - the presentation style, the delegate, the popover presentation controller, the modes each initializer takes and the words it refuses the others in (an export needs a file that is there), the plain init - into `device/documentmenu-expectations.h`; `device/documentmenu.m` repeats them and shows the menu on the device: the options of the application around the way to the picker and Cancel last, and each choice answering its handler or the delegate.

`host/imagetraits/run.sh` records the trait collection the host's UIKit answers for `UIImage.traitCollection` of images at scales 1, 2 and 3, remade at another scale and resizable, into `device/imagetraits-expectations.h`; `device/imagetraits.m` holds the port to them.

`host/smallapis2/run.sh` records what the host's UIKit and Foundation do with `+appearanceWhenContainedInInstancesOfClasses:` (a label under one container class, under two, outside), `beginBackgroundTaskWithName:expirationHandler:` and `includesPeerToPeer` of a Bonjour service and browser into `device/smallapis2-expectations.h`; `device/smallapis2.m` holds the port to them.

`host/touchtypes/run.sh` records what the host's UIKit answers for `allowedTouchTypes`, `requiresExclusiveTouchType` and `allowedPressTypes` of a gesture recognizer (the defaults, an array set, an empty array, duplicates) into `device/touchtypes-expectations.h`, and `device/touchtypes.m` holds the port to them on a device and then taps with a real finger on views whose tap recognizers allow different touch types.

`host/textalign/run.sh` records what the host's UIKit does when `textAlignment` of a label, a text field and a text view is set to left, centre, right and natural (the value read back, and the side the ink of the rendered control is on, for a Latin and a Hebrew text), into `device/textalign-expectations.h`, and `device/textalign.m` holds the port to the same records on a device.

`host/scrollguide/run.sh` records what the host's UIKit does with `frameLayoutGuide` and `contentLayoutGuide` of a scroll view (a content view pinned to the content guide gives `contentSize`, a view pinned to the frame guide stays put when the content scrolls and when the scroll view is resized, a guide nothing constrains) into `device/scrollguide-expectations.h`, and `device/scrollguide.m` holds the port to the same records on a device.

`host/safeguide/run.sh` records what the host's UIKit answers for `safeAreaLayoutGuide` as relations (the guide's frame is the view's bounds inset by `safeAreaInsets`, a view pinned to the guide sits at the insets, and it stays so when a navigation bar is hidden and shown, for an inner view and for a view outside a window) into `device/safeguide-expectations.h`, and `device/safeguide.m` holds the port to the same relations on a device with the insets its own bars give.

`host/toolbar/run.sh` records what the host's UIKit does with a navigation controller that never asked for a toolbar (none is made, whatever the safe area of its controller's view is asked, counted through a `UIToolbar` subclass handed to `initWithNavigationBarClass:toolbarClass:`), and with one that shows and hides its toolbar, for the cases of `device/toolbar-cases.m` into `device/toolbar-expectations.h`; it then compiles the port's `UIView+SafeArea.m` and `UIViewController+SafeArea.m` beside the same cases and holds them to the records, with two mutants that must differ. The host keeps a toolbar out of the view tree, so what a shown toolbar covers is the device's own: `device/toolbar.m` is an application that holds the port to the host's records and checks that the shown toolbar covers the view and is its bottom inset (the emulator or a phone, built by hand like the other applications here; the log is in `/var/revenant` on the emulator).

`host/customtransition/run.sh` records what the host's UIKit does with custom animation controllers (a presentation, a dismissal, a push and a pop, each with an animator that writes down what its context says and what the controllers see, in a Mac Catalyst application with a window) for the cases of `device/customtransition-cases.m` into `device/customtransition-expectations.h`, and `device/customtransition.m` holds the port on a device to the same records: the controllers and views of the context, where they are in the hierarchy at the start and at the end, the frames, the order of the appearance callbacks, the completion handler and `animationEnded:`, and whether the presenting view is back where it was after a dismissal and an interactive one. `device/slidetransition.m` slides views with an animator on a device and reads the screen halfway and at the end (`slidetransition-*.png`).

`transition.m` (`transition-Info.plist`) is an application for both devices that pushes, pops, presents and dismisses view controllers, with and without animation, and reads `transitionCoordinator` in the appearance callbacks of both controllers: the coordinator is one object for both while the release's transition runs and nil before and after, it knows the two controllers, an `animateAlongsideTransition:completion:` animation runs and its completion is called after the transition, and without animation both run at once. It has no host oracle (Mac Catalyst's transitions are its own). The durations the coordinator reports were measured there: a presentation and a dismissal 0.41 seconds, a push and a pop about 0.36.
`swipelook.m` (`swipelook-Info.plist`) is an application for both devices that shows the release's own delete button and the port's swipe button on the same screen with real touches, reads both as pixels (`UIGetScreenImage`, also saved as `swipelook-native.png` and `swipelook-facade.png`) and holds the gloss of the port's to the release's, and checks that the swipe buttons appear on the table of a `UITableViewController`.

`host/layoutguide/run.sh` records what the host's UIKit does with constraints written with `UILayoutGuide` items (`constraintWithItem:` with a guide, activation and deactivation, a guide with no owning view, two guides in one hierarchy) into `device/layoutguide-expectations.h`, and `device/layoutguide.m` holds the port to the same frames and states on a device; without the port's mapping the release refuses the guide as an item.

`documentpicker.m` (`documentpicker-Info.plist`) is an application for both devices that drives `UIDocumentPickerViewController` with real
touches over a fixture tree it writes under `/private/var/backports/docpick`: open mode with a type filter, going into a folder and choosing a
file, the locations page, import with several files and Done, cancelling, export and move into a folder, and a delegate that has only the
singular callback. The `documentpicker` group of `host/uikit2/run.sh` holds the initializers to the system's and checks the type filter and what
open, import, export and move hand back. It writes `/private/var/backports/documentpicker.log` and `documentpicker.done`.

`device/gesture.h` and `gesture.m` are the helper for a test that needs a finger on a device running iOS 6: `gesture_touch`
sends a digitizer event to the HID event system, and `gesture_drag` and `gesture_tap` queue a sequence of them as timed steps
beside the checks a test puts between them with `gesture_step`, run by `gesture_run` from timers on the main queue. UIKit
then sees a real touch, gesture recognizers included; synthesising `UITouch` and `UIEvent` in the process does not work on
this release (`-[UIApplication sendEvent:]` faults without a GSEvent, and `-[UIWindow sendEvent:]` reaches no recognizer). Two
things a test has to do: it is an application whose plist lists both device families (an iPad runs a one-family application
scaled by two, and the coordinates go wrong), and it waits about two seconds after a scroll before the next touch, so
deceleration does not take it. `swipeui.m` is the example.

`host/progress/run.sh` records what the host's `NSProgress` does for children added with
`-addChild:withPendingUnitCount:` in `device/progress-cases.m`, and `device/progress.m` compares the port on the release.
- `lists.m` (`lists-Info.plist`): an application, the lists and cell configurations: values, content and cell geometry are held to `lists-expectations.h`,
  which the windowed `listcell` group of `host/uikit2/run.sh` records from the host's UIKit (the `listvalues` group compares the values on 35000 more);
  a real list layout is put on screen and its rows, header, selection, editing and default backgrounds are measured; the members that are not carried
  are asked whether they answer. Then, with real touches from `gesture.h` (it needs `gesture.m` linked and the screen awake), a list is swiped both ways
  and its buttons are tapped and dragged across, an outline row is expanded and collapsed by a tap on its disclosure, and a row is dragged by its reorder
  grip in editing; the handlers of the data source and the order of the rows are checked. The `listactions` group of `host/uikit2/run.sh` puts the port beside
  the system's diffable data source in a window and compares the outline handlers (thirteen steps) and the reordering handlers and their transactions (six
  drags) with the interactive movement API. It writes `/private/var/backports/lists.log` and `lists.done`.

`uikit12.m` (`uikit12-Info.plist`, `homeindicator-cases.m`, `insetref-cases.m`, `traits11-cases.m`): an application of its own that holds the home indicator, edge gesture and large title accessors, and the section inset reference of a flow layout, to the records of the host's UIKit; it needs `/private/var/backports` made by root, the screen on (`wake`), and the application registered, which a device does after a reboot.

`device/wake.m` is a tool that wakes and unlocks a device that has no passcode, by sending the Home button and a slide along the
unlock track through the HID event system. An application that is launched while the screen is locked comes up inactive
(`applicationState` 1) and receives no touch, and `revenant-launch` is refused with "device locked" in
`/private/var/revenant/events.log`; a gesture test runs `wake` first and checks that the application is active before it touches.

The `metrics` scenario of `session-scenarios.m` holds the task metrics of the port's `NSURLSession` to what the system's session
reports for a data task, a redirect, a refused connection and a handler task, on an ephemeral configuration; `host/session/run.sh`
runs it beside the others and a device runs it with the host's `server.py` reached through a reverse forward of the ssh tunnel.

`host/template/run.sh` records what the host's `UIImageView` and `UIButton` draw for template, original and automatic images
(twenty-one pixels) in `device/template-cases.m`, in a Mac Catalyst application of its own bundle identifier - two of them
with the same identifier do not run together - and `device/template.m` compares the port on the release, to within three in a
channel.

`gesture_unblock` of the gesture helper finds out whether a touch reaches the application - it puts a clear view over the window and
sends one - and if none does, taps the places where the buttons of a centred alert are until one does, so an alert an earlier run left
does not take every touch of a test. `unblock.m` checks it with an alert of its own. It restarts nothing: SpringBoard is never
killed, and a screen that is locked is a matter for `wake`.

`host/underlying/run.sh` runs the scheduler of the port's operation queue - the class that `-setUnderlyingQueue:` puts behind a queue - beside
the system's `NSOperationQueue` over `device/underlying-cases.m` (twenty-one records: where an operation runs, the concurrency of a
serial and of a concurrent queue with a limit, the refusal to change the queue when it is not empty, priority and dependencies,
cancelling, suspending, counts, asynchronous operations), and writes what the system answered for `device/underlying.m`, which runs
the same cases through the real `NSOperationQueue` on the release.

`device/viewtransition.m` changes the status bar orientation of a window whose root controller has a child and checks the size each is told through `viewWillTransitionToSize:withTransitionCoordinator:`, the quarter turn the coordinator carries, the alongside block and the completion, and that the same orientation twice tells nobody. It holds its own expectations: the system has no rotation to record.

`host/errorprovider/run.sh` records what the system's `NSError` asks a user info value provider and what it does with the answers - the keys asked per getter, the user info that stays empty, the value in the user info that wins, another domain, a replaced and a removed provider, a copy - and `device/errorprovider.m` runs the same cases on iOS 6.

`host/tail1/run.sh` records what the system's `UITraitCollection` does with a layout direction, a display gamut and a preferred content size category (constructing, reading, merging, containing, equality, description, coding), the digits of `+monospacedDigitSystemFontOfSize:weight:` and the date formats `-setLocalizedDateFormatFromTemplate:` gives for a few templates and locales; `device/tail1.m` runs the same cases on iOS 6.

`host/tail2/run.sh` records what the system does with an `NSExtensionContext` made by an application (no input items, no calls of its handlers, the controllers of an application having none) and `device/tail2.m` runs the same cases on iOS 6.

`device/textfieldreason.m` ends the editing of a real text field with a delegate that has only `-textFieldDidEndEditing:reason:`, one that has only the old method, and none. It has no host record: a text field of a headless scene does not become the first responder.

`host/tail3/run.sh` records what the system does with `sharedContainerIdentifier` of an `NSURLSessionConfiguration` - default, set, copied, cleared, on a background configuration, kept by a session - and `device/tail3.m` runs the same cases on iOS 6.

`device/focuscontentsize.m` is a process of its own: it holds `UIFocusAnimationCoordinator` to running the animations it is given and then the completion, at once and in that order, with either block allowed to be nil, and holds `adjustsFontForContentSizeCategory` on a label, a text field and a text view to keeping the flag, keeping the font and saying it adopts `UIContentSizeCategoryAdjusting`. It asks `dladdr` that the class and the accessors come from `libUIKitBackports.dylib`, and asks the runtime that all three classes adopt the protocol. The flag is held on classes rather than on instances because iOS 6 cannot make a `UITextField` or a `UILabel` in a process with no application - a plain `UIView` and a `UIProgressView` are made without trouble, the text-bearing controls trap inside CoreFoundation - so the per-instance behaviour waits for an application.

`device/observedprogress.m` is a process of its own and has no host counterpart on purpose: the host's own `UIProgressView` does not move for an observed progress at all, so there is nothing to compare with. It holds the port to what `-[UIProgressView setObservedProgress:]` of iOS 9.3.5 does instead - the fraction taken at once, followed as the progress moves, a hand set overridden by the next move, one progress replaced by another, the observation cleared, and a progress view that goes away while observing taking its observation with it - and asks `dladdr` that both accessors come from `libUIKitBackports.dylib`.

`host/previewing/run.sh` records what the system does when a view controller registers for previewing, which on Mac Catalyst is a host whose force touch capability is unavailable, as iOS 6's is: the context it answers, that the context is keyed by the source view and a second registration on the same view answers the first context with its first delegate, that `sourceRect` starts as `CGRectNull` rather than the source view's bounds, that the recogniser for a failure relationship is one enabled recogniser in no view, that unregistering is quiet twice over, and that the delegate is asked nothing; `device/previewing.m` runs the same cases on iOS 6.

`host/pasteboard10/run.sh` records what the system's `UIPasteboard` answers to `hasStrings`, `hasURLs`, `hasImages` and `hasColors` over the thirteen contents of `device/pasteboard10-cases.m` - a string, a string that reads as a URL, a URL, an image, a colour, two of each, an image set over a string, a string and an image in items of their own, the bytes of a PNG under `public.png`, bytes under a type of the application's own, and a pasteboard emptied - and records beside each answer whether `-strings`, `-URLs`, `-images` and `-colors` return anything, so the predicate is held to what the pasteboard can really hand over; `device/pasteboard10.m` runs the same cases on iOS 6 as a process of its own, and first asks `dladdr` which image each of the four answers and each of the four type lists comes from, so a predicate taken from the release instead of the port, or a type list the port had to invent, is a failure and not a silent pass.

`host/show/run.sh` records what the system does when a controller shows another one - pushed by a navigation controller, presented with no container or in a tab bar controller, sent to a parent that overrides the method, `showDetailViewController:sender:` with no split view - and which controller `targetViewControllerForAction:sender:` and `targetForAction:withSender:` answer; `device/show.m` runs the same cases on iOS 6.

`host/ypcbcr8/run.sh` holds the thirty Y'CbCr conversions of vImage at 8.0 against the host's own vImage, layout by layout and direction by direction: the same buffers through both, every sample of the result compared, over both matrices, the four pixel ranges of `vImage_YpCbCrPixelRange`'s own documentation at each of the three bit depths, four permutation maps and four picture sizes from 2x2 to 34x18. It is 8 947 checks and none of them fail; 0.31 per cent of 5 708 800 samples differ, the widest by 255, and every bound is the measured maximum plus one and is EXCLUSIVE: 2 for the eight-bit shapes, whose measured maximum is 1, and 256 for the two sixteen-bit shapes, whose measured maximum is 255. The CEILING on a one-unit difference in the eight-bit dot product is 2 * (CbCrRangeMax - CbCr_bias) / 255, which is 514.0 at the full sixteen-bit range and 224.88 at the 28672 chroma range, and it is deliberately not the bound: the suite is green at 256, so 514 would admit a real one-unit chroma error in silence. It is also where the family's measured findings live - that a shared sample's chroma is averaged before the scale rather than after, that the Y'CbCr input is not clamped to the pixel range, that the a2vy shape's alpha plane is one byte to a pixel, that a sixteen-bit alpha narrows with `(A*255+32767)/65535` and widens by 257, and that a v210 unit is six pixels of one row at `column / 6`. The two ten-bit shapes and the two Q12-source conversions are the one place the system does not come out of the header's formula, and there the differential holds the port to the formula written out a third time in the test and counts the system's divergence rather than asserting it. `host/ypcbcr/run.sh` is the 4:2:0 8-bit pair of the same family, and is run as well because the whole of the arithmetic is one file.

`host/rotate90/run.sh` holds the five quarter turns of vImage against the host's own. The two differentials' **rows, counted on this series' own base**, are **33**: 28 Y'CbCr shapes in `ios8ypcbcr-shapes.json` and 5 quarter turns in `ios7-15-rotate90.json`. The ten Y'CbCr symbols, the four matrices, the two generators and the seven rows of `ios7.json` and `ios7pixels.json` were already in `revenant` on that base, from the Accelerate band, and are not part of this series - the registry goes from 138 to 171 across it, which is 33 and not the 51 a count of every Accelerate row would report.

searched: libyuv (BSD-3-Clause) for the Y'CbCr layouts and stb_image_resize (MIT/Apache-2.0) for the Lanczos3 filter. **Compared against, not reused.** libyuv's `I420ToARGB` and its v210/v410 readers were read for the channel order and the bit positions of the ten-bit shapes, and the layout this package uses is the header's own drawing as `probe-bits.m` confirmed bit by bit; libyuv handles 8-bit 4:2:0 only, so none of the 4:2:2, 4:4:4, 16-bit or Q12 work here overlaps it. stb_image_resize's Lanczos3 is `sinc(x) * sinc(x/3)` normalised per phase, which is what this package computes and what the host's own weights match to five decimals - but stb_image_resize is integer, handles no alpha channel and no planar layout, and has no edging mode, so reusing it would have meant reimplementing most of it. Both were read for the two facts above and neither is vendored: there is no code from either in this package.
