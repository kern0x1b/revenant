# The surfaces Telegram 13.0.0 reached at the iOS 6 floor

A build of Telegram 13.0.0 for armv7 at iOS 6.0 stopped on three names the lowered SDK still gated, and a sweep of the
families around them found more. Each entry says what the name does on iOS 6.1.3 and what the port does with it. The
sources of Telegram stay as they are. `frameworks/Backports/tests/availability/floor_surfaces.swift` holds Telegram's own
lines for all of it, and `availability_test.lua` typechecks that file at armv7 iOS 6.0 against the lowered SDK and the
runtime's overlays, and fails when the file also typechecks without the lowering.

## AVAudioPlayer with a file type hint

`AVAudioPlayer(contentsOf:fileTypeHint:)` and `AVAudioPlayer(data:fileTypeHint:)` are iOS 7. iOS 6.1.3 has neither
selector, and its `initWithContentsOfURL:error:` takes the type from the file's extension, while `initWithData:error:`
reads the content. `AVAudioPlayer+FileTypeHint7.m` adds both initializers. The URL form asks AudioToolbox
(`kAudioFileGlobalInfo_TypesForUTI` for the hint and `kAudioFileGlobalInfo_TypesForExtension` for the extension) whether
the two name a common file type. When they do, the system initializer by URL is already right and runs. When they do not,
the file's bytes go to `initWithData:error:`, which sniffs the content. A URL that is not a file URL, and a hint or an
extension that AudioToolbox does not know, take the system initializer by URL. The data form calls `initWithData:error:`,
which does not use a hint on iOS 6, so the hint has no effect there.

The device probe `AudioPlayerHintProbe` runs 11 checks on the iPhone 4S (iOS 6.1.3) and a run with `--negative` fails them
all. Two limits are visible from outside: a player made through the data path has no `url`, and a hint that contradicts
the content of a file whose extension AudioToolbox does not know is not honoured.

`AVAudioSession.setAllowHapticsAndSystemSoundsDuringRecording(_:)` and its getter are iOS 13. The session keeps the flag
and answers it back. It cannot change what iOS 6 does, because iOS 6 never silenced system sounds while recording, so the
value is stored and read and no behaviour follows from it (`AudioSessionSoundsProbe`, 3 checks).

## UIMenu with a subtitle, and the rest of the menu initializers

`UIMenu(title:subtitle:image:identifier:options:children:)` is iOS 15 and `subtitle` is a property of `UIMenuElement`.
The backport keeps `subtitle` and `selectedImage` on `UIMenuElement`, copies them with the element, and carries them
through `UIAction`, `UICommand`, `UIKeyCommand` and `UIMenu`. The menu is shown through an action sheet, which has no
place for either, so the two values are stored, compared and copied and are not drawn.

The Swift initializer families live in `toolchain/src/swift-runtime/overlay/UIKit/UIKitRevenant.swift`: the three
`UIAction` forms, the three `UICommand` forms, the `UIKeyCommand` form with `propertyList` and `alternates`, and the three
`UIMenu` forms, the subtitle one among them. The older `UIMenu` overloads are `@_disfavoredOverload`, so a call that
names `subtitle` picks the new form and a call that does not still picks the old one. `UIKeyCommand` forwards
`propertyList`, `alternates`, `attributes` and `state` to its superclass, so the iOS 13 and 15 declarations that the
header repeats for it resolve to the backport. `MenuElementsProbe` runs 9 checks on the device and fails them all with
`--negative`.

`UIMenuBuilder` and `buildMenu(with:)` are iOS 13. `RevenantMenuBuilder` implements the whole protocol over a root
`UIMenu` with the identifier `UIMenuRoot`: replace, insert and remove for menus, actions and commands, and the
`withElements:` forms that iOS 26 adds. `MenuBuilderProbe` runs 10 checks on the device. Two things the port does not
measure or cannot do: a menu or action the builder is asked to change and cannot find is ignored, which is unmeasured
against a real UIKit, and iOS 6 has no menu-building pass, so `buildMenu(with:)` is never called on it and Telegram's
`builder.remove(menu: .replace)` in its amount field has no effect there.

## Text traits

`smartQuotesType`, `smartDashesType`, `smartInsertDeleteType` and `textContentType` of `UITextInputTraits` were
implemented for `UITextField`, `UITextView` and `UISearchBar` by one macro, and the lowering did not see them (see
"A class that a macro implements" in `lowered-implemented-names.md`). They are lowered now and the traits protocol is
backed through the classes that conform to it.

## Photos

- `PHImageContentMode.default` is `PHImageContentModeAspectFit` under another name, which the lowering takes as lowered
  with it ("A case that names a lowered case is lowered with it").
- `PHAsset.mediaSubtypes` is implemented and answers `PHAssetMediaSubtypeNone`: the AssetsLibrary of iOS 6.1.3 reports
  no panorama, HDR, screenshot, Live Photo, depth effect, high frame rate, time-lapse, screen recording or cinematic
  bit for an asset, so `contains(.videoHighFrameRate)`, `.videoTimelapse` and `.photoLive` are false. `None` and the
  eight subtypes that the picker filters below name are lowered with the property; `photoHDR` and `videoStreamed` are
  not named by the port and keep their availability.
- `PHFetchOptions.fetchLimit` and `includeAssetSourceTypes` were implemented and still gated, because the compiler
  synthesized them and the scan reads no synthesized property. They are named in a `@synthesize` list, and so are
  `PHAssetResourceCreationOptions.uniformTypeIdentifier` and `shouldMoveFile`, which the list scan had skipped.
- A `PHPickerFilter` carried only a media type, so `.panoramas`, `.screenshots`, `.slomoVideos`, `.timelapseVideos`,
  `.screenRecordings`, `.depthEffectPhotos` and `.cinematicVideos` were all the live-photo filter and equal to each
  other. Each is now a filter of the subtype it selects, matches no media type on iOS 6, and is equal only to itself.
  `.bursts` still stands for the live-photo filter, since a burst is not a media subtype. `all(of:)`, `not(_:)` and
  `playbackStyle(_:)` still reduce to the media types the picker can ask the system for, so `not(.images)` is the
  live-photo filter too.

## Overlays at armv7

The SDK carries the Swift interfaces of its frameworks for arm64e only, so a compile for armv7 sees what the
Objective-C headers declare and nothing that Apple's Swift overlay added. Telegram reached four such gaps, and the
runtime builds an overlay for each from the interface the SDK has for arm64e:

- `CMSampleBuffer` gets `presentationTimeStamp`, `duration`, `decodeTimeStamp`, `outputPresentationTimeStamp` and the
  other accessors of the iOS 13 Swift extension, over `CMSampleBufferGetPresentationTimeStamp` and its relatives, which
  CoreMedia has had since iOS 4 (`overlay/CoreMedia/CMSampleBuffer.swift`).
- `CXProviderConfiguration.supportedHandleTypes` is a `Set<CXHandle.HandleType>` in Swift over the refined
  `__supportedHandleTypes` set of numbers (`overlay/CallKit/CXProviderConfiguration.swift`). CallKit is linked weakly,
  and a program that never reaches CallKit does not need it on the device.
- `PHPickerFilter`, `PHPickerConfiguration`, `PHPickerResult`, `PHPickerViewControllerDelegate` and the
  `configuration`, `delegate` and `init(configuration:)` of `PHPickerViewController` are Swift types over the
  Objective-C classes that the headers name `__PHPickerFilter`, `__PHPickerConfiguration` and `__PHPickerResult`
  (`overlay/PhotosUI/PhotosUI.swift`). The delegate is a Swift protocol that a private adapter of the Objective-C
  protocol forwards to, held by the controller, so the delegate reference stays weak. The members iOS 17 added to the
  configuration (`mode`, `edgesWithoutContentMargins`, `disabledCapabilities`) and to the controller (`updatePicker`) are
  not provided, and neither is `spatialMedia`, which the Objective-C backport does not implement.
- The UIKit overlay carries the initializer families above.

`INStartCallIntent` is an Objective-C class of Intents that iOS 6 does not have. `RevenantIntents130.m` implements it,
with its designated initializer, `contacts`, `callRecordFilter`, `callRecordToCallBack`, `audioRoute`,
`destinationType` and `callCapability`, secure coding, copying, equality and hash, and the `Unknown` constants of its
three enums.

## WebKit: async functions, frames, worlds and web archives

`WKWebView` here is a `UIView` over the prefixed WebKitLegacy engine, which evaluates a script synchronously and has no
promise-aware entry. Telegram's `BrowserWebContent` reaches four members that the engine does not offer by name, and
each is implemented over what it does offer (`src/WebKit/WKWebView.m`, `RevenantScriptCodec.m`, `WebKit.swift`):

- `callAsyncJavaScript(_:arguments:in:in:completionHandler:)`, in the `Result` form and in the `async throws` form
  (`WebKit.swift` over the refined `__callAsyncJavaScript`). The body runs as the body of an async function whose
  parameters are the keys of `arguments`. The page reports the settled promise over the same `revenant-wkbridge://`
  channel that `WKScriptMessageHandler` uses, as envelope kind 8 with the call's id, the nonce of the view and the
  result; the completion handler is kept by id and runs once. A rejection or an exception arrives as
  `WKErrorJavaScriptExceptionOccurred`, a result that cannot cross the bridge as `WKErrorJavaScriptResultTypeIsUnsupported`,
  and a body or argument that is not a string, number, boolean, `NSNull`, date, array or dictionary of those as
  `WKErrorUnknown` with a description of what is accepted. A call still waiting when the view is deallocated fails with `WKErrorWebViewInvalidated`, and one
  waiting when the page commits a new navigation with `WKErrorJavaScriptInvalidFrameTarget`.
- `evaluateJavaScript(_:in:in:completionHandler:)`, in both forms, over the same helpers as the plain
  `evaluateJavaScript`.
- `createWebArchiveData(completionHandler:)`, over `WebDataSource.webArchive.data` of the main frame.
- `UIContextMenuConfiguration(identifier:previewProvider:_:)` is a Swift initializer of the UIKit overlay, over the
  refined `__identifier:previewProvider:actionProvider:`; Telegram's `BrowserWebContent` builds the context menu of a web element with it.

What the engine cannot do, and the port does not pretend to do:

- It has one JavaScript world. A call that asks for a content world other than the page world runs in the page world, and
  the first such call logs that it did. A script that relies on isolation (a name it must not see from the page, a
  variable the page must not see) is not isolated here. Isolation needs the engine's `WebScriptWorld` or a second
  JavaScriptCore context bound to the same frame, which the legacy engine does not expose.
- Only the main frame can be targeted. A `WKFrameInfo` of another frame fails with
  `WKErrorJavaScriptInvalidFrameTarget`.
- `createPDF`, `WKPDFConfiguration` and `find(_:configuration:)` are not implemented. Telegram does not call them.

Telegram's build lists the Swift overlay modules that a compile must find. `WebKit` and `ContactsUI` are new entries
beside `UniformTypeIdentifiers` and `IOSurface`; without the `WebKit` module `createWebArchiveData` and the `Result`
form of `callAsyncJavaScript` do not exist for Swift (checked: "has no member 'createWebArchiveData'").

## ContactsUI: the access picker

`View.contactAccessPicker(isPresented:completionHandler:)` is iOS 18 SwiftUI. Telegram's `ContactsControllerNode`
hosts it in `ContactAccessPickerHostingView`, to let a person who gave limited contacts access add more contacts. iOS 6
has no limited access: `ABAddressBook` authorisation is all or nothing, so there is no set of contacts to extend and no
picker that could do it. The overlay (`src/ContactsUI/ContactsUI.swift`, a SwiftUI target) declares the modifier with
`@available(iOS 18.0, *)` and, when `isPresented` becomes true, writes to the standard error and the log that the access
level cannot be extended, sets `isPresented` back to false and does not call the completion handler, since no contact
identifier was chosen. A call site that guards on the iOS version never reaches it on iOS 6.

## ContactsHelper and the change history visitor

Telegram's `ContactsHelper` module did not build because the signature of `CNChangeHistoryEvent acceptEventVisitor:`
names a protocol the SDK marks iOS 13. The cause was in the lowering, not in the header or in Telegram; see "A protocol
that the signature of an implemented member names is lowered with it" in
[What the lowering takes as implemented](lowered-implemented-names.md).

## PDFKit: PDFView

`PDFView` was an `NSObject` with the navigation methods; Telegram's `BrowserPdfContent` needs a view. It is now a
`UIView` (`src/PDFKit/PDFView11.m`, declared in the private header `RevenantPDFView.h`) over the model classes of the
backport. Inside is a `UIScrollView` subclass, which `BrowserPdfContent` finds among `subviews` and takes the delegate of,
so nothing inside depends on the scroll view's delegate. Its content is the `documentView`, and the visible pages (and
half a screen around them) are page views taken from a pool. A page view draws through a `CATiledLayer` of 512 point tiles
without the fade, calls `drawPage:toContext:` (which draws the page with `displayBox`, and which a subclass may replace)
and then draws the highlights and `drawPagePost:toContext:`.

The layout is `RevenantPDFLayout` (`RevenantPDFLayout.m`, which needs Foundation and Core Graphics only and has a host
test): single page, single page continuous, two-up and two-up continuous; vertical and horizontal; `displaysAsBook`,
`displaysRTL`, `displaysPageBreaks` and `pageBreakMargins` (default `{4.75, 4, 4.75, 4}`, zero without page breaks);
`scaleFactorForSizeToFit` as fit width in the continuous modes and best fit otherwise. Defaults follow the SDK header:
continuous single page, vertical, a 50 percent grey background, `displayBox` crop box, shadows on, `autoScales` off,
minimum 0.1 and maximum 100 (the SDK header says assigning either turns `autoScales` off, and it does). The pinch and the
double tap zoom about the touch point; a tap on an annotation runs its action or goes to its destination, posting
`PDFViewAnnotationWillHitNotification` and `PDFViewAnnotationHitNotification`; a link is handed to
`PDFViewWillClickOnLink:withURL:` or opened; `PDFViewPageChangedNotification`, `PDFViewScaleChangedNotification`,
`PDFViewVisiblePagesChangedNotification` and the others post when the value they name changes. `currentPage` is the page
at the middle of the view, the left page of a two-up row. History (`goBack`, `goForward`) records every `goTo` call.
`highlightedSelections` and `currentSelection` draw their lines in the colour of the selection.

`PDFDocument` gained what the view and Telegram use: `beginFindString:withOptions:` and `cancelFindString` (one page per
turn of the main queue, posting the begin, match and end notifications and calling the delegate), `delegate`, `isFinding`
and `indexForPage:`; its page cache is now keyed by index, which fixes the sparse access that `pageAtIndex:` of a
later page followed by an earlier one used to get wrong. `PDFPage` gained `transformForBox:` and `drawWithBox:toContext:`,
and serialises the drawing and the text scan of a page, since tiles draw on several threads. `PDFViewDelegate` is emitted
as a protocol like `PDFDocumentDelegate`.

Not provided: `usePageViewController:withViewOptions:`, `pageOverlayViewProvider`, `inMarkupMode`,
`enableDataDetectors`, `areaOfInterestForPoint:`, the iOS 16 find interaction (`findInteraction`,
`isFindInteractionEnabled`; Telegram's use is behind a condition that is always false and takes the
`beginFindString` path), selecting text by touch, and `PDFThumbnailView`.

## PDFKit: building, editing and writing a document

Telegram's document scanner builds a `PDFDocument()`, adds a `PDFPage(image:)` per scanned page and sends
`dataRepresentation()`. `PDFPage(image:)` and `initWithImage:options:` (`RevenantPDFImage.m`) render a one-page PDF with the
`mediaBox`, `rotation`, `upscaleIfSmaller` and `compressionQuality` options of the SDK. A smaller image is not enlarged
unless asked, and an enlarged one fills the width and leaves bands above and below, as on the host. `PDFDocument` gained
`insertPage:atIndex:`, `removePageAtIndex:`, `exchangePageAtIndex:withPageAtIndex:`, `dataRepresentation`,
`dataRepresentationWithOptions:`, `writeToURL:` and `writeToFile:` with and without options, `copy`, `documentRef`,
`version` and typed `documentAttributes`; `PDFPage` gained `setBounds:forBox:` and a writable `rotation`. The owner and user
password options write an AES-128 encrypted file with the permissions the option names.

A document that nobody has changed returns the bytes it was opened from. A changed one is assembled by
`RevenantPDFAssemble` (`RevenantPDFObjects.m`: an object writer with a cross-reference table, deflated streams and the
encryption dictionary), which copies each page's content and resources out of the `CGPDF` objects
(`RevenantPDFCopy.m`) and writes the pages it was given, in order. A page that is in two documents is one page object, as on
the host. Not done: the write options `PDFDocumentBurnInAnnotationsOption`, `PDFDocumentSaveTextFromOCROption`,
`PDFDocumentSaveImagesAsJPEGOption` and `PDFDocumentOptimizeImagesForScreenOption` are ignored; the outline of a document
is not written again after an edit; the writer sets no `Producer` of its own, where the host writes Quartz's.

Checked: `tests/PDFKit/writer_test.m` has 140 checks that read the output back with Core Graphics and compare it with the host
PDFKit (and the same run with every expectation inverted must fail); `PDFWriterProbe`
(`tests/device_probe/pdfwriter_main.m`) runs 45 checks on an iPhone 4S (iOS 6.1.3, armv7) and had no failure: page images,
the options, insert, remove and exchange, a password round trip, copy, and the sampled pixels of an upscaled page. Writing
a PDF with the page images of a scan was not timed apart from the scan below.

Before the probe could load `libPDFKitBackports.dylib`, the skeleton had to change. A global whose type is a typedef of a
qualified type (`PDFAnnotationKey` is `NSString *const`) was emitted as a `const` placeholder, which the linker put in
`__TEXT,__const`, and the load-time copy from the system image then wrote into read-only memory: the library died with a
bus error before `main`. The placeholder is now declared by a typedef of the type in the facts and `__typeof_unqual__` of
that typedef (`tools/skeleton.lua`), so it is writable whatever the typedef hides. `tests/forwarders_test.lua` has a global
typed by a const pointer typedef, loads the generated library and reads it. This was a defect of every device load of a
library with such a global, not only of PDFKit.

## VisionKit: the document camera

`VNDocumentCameraViewController` is a camera screen (`src/VisionKit/VNDocumentCameraViewController.m`). An
`AVCaptureSession` with the photo preset feeds a live preview, a video data output of 420f frames and a still image output.
A live frame (the rear camera delivers it landscape: 852 by 640 on an iPhone 4S) is reduced to the luminance of at most 320
points on the long side and turned a quarter turn to portrait; `RevenantVisionDetectRectangles`, the detector of the Vision
backport, searches it every 0.12 s on a queue of its own. `RevenantDocumentTracker` (`RevenantDocumentLive.c`) follows the
candidate nearest the last one, outlines it on the preview, and in the automatic mode takes the picture when the page has
held still for 1.2 s; the `Auto`/`Manual` button turns that off, and the shutter takes the picture in either mode. The flash
button cycles off, auto and on. A picture is a JPEG from the still output: `RevenantDocumentPageFromJPEG`
(`RevenantDocumentScan.m`) decodes it at up to twice the size of the page it will make, runs the detector again with the live
outline as a hint, maps the quadrilateral on a rectangle with `RevenantDocumentWarp.c` (a projective transform sampled
bilinearly; the coordinates are interpolated in fixed point, to 1/256 of a pixel, across spans of 8 pixels, so the A5 does
not divide per pixel) and encodes a JPEG of at most 2048 points on the long side. A picture without a page in it becomes
the whole frame. The page just taken shows as a thumbnail beside the shutter and `Save` carries the count; `Retake` drops
the last page, and `Cancel` asks before it discards any pages.

`VNDocumentCameraScan` returns `title` (`Scan yyyy-MM-dd HH.mm`), `pageCount` and `imageOfPageAtIndex:`, with the images
decoded on demand and a page beyond the count answering nil. When the delegate has no
`documentCameraViewControllerDidCancel:` or `documentCameraViewController:didFailWithError:`, and Telegram implements
neither, the controller dismisses itself in those two cases, since nobody else would; `Save` does the same when the
delegate has no `documentCameraViewController:didFinishWithScan:`. A device without a camera answers `isSupported` with NO
and, when presented, fails with `NSFeatureUnsupportedError`; any other start-up failure carries the AVFoundation error.

`VisionKitLoadProbe` (`tests/device_probe/visionkit_load_main.m`) loads the built `libVisionKitBackports.dylib` with its
three Backports dependencies on the iPhone 4S, finds both classes, builds a scan from two JPEG pages and reads them back
(10 checks, no failure). Replaying the compile of Telegram's `TelegramUI` module with `swiftc -typecheck` (the Bazel
parameters of the discovery build, the lowered SDK rebuilt from this branch) gives no diagnostic; the same replay with the
lowered SDK of the build before this work gives one, `'init(image:)' is only available in iOS 11.0 or newer` at
`ChatControllerOpenDocumentScanner.swift:42`. That is a typecheck of one module against the modules the discovery build had
already produced, not a link or a run of Telegram.

Measured on an iPhone 4S (`VisionKitProbe`, `tests/device_probe/visionkit_main.m`, 25 checks, no failure; the screen
was read from a screenshot):

| step | time |
| --- | --- |
| a live frame, turned, reduced to 213 by 284 and searched | 32 ms |
| first live frame after the presentation | 1.26 s |
| a 3264 by 2448 still encoded (the probe's rendered page) | 480 ms |
| that still to a 1497 by 1997 page, found within 0.0020 of the frame | 1.66 s |
| a capture from the shutter to the page of a room | 3.8 s |
| a page held still, from the first sight to the page | 4.1 s |
| the longest pause of the main thread during 40 s of live view | 103 ms (the 100 ms timer) |

The first version took 2.9 s for the page of the probe and 6.0 s from the shutter; the fixed-point warp and a luminance
pass that samples instead of summing every pixel brought them to the figures above. The decode of a real photo is
about 1.6 s of the capture time; asking the still output for BGRA buffers instead of JPEG would spare it, and has not been
done.

Not provided: the review screen of the real framework (corner handles, rotate, crop, filters), any localization of the
strings, landscape, and a choice of camera. The detection was measured on rendered pages and on injected outlines, and the
camera was pointed at a desk, not at paper in a lit room; how well the detector finds a real sheet, and what the A5's
autofocus does at arm's length, is not measured. The probe's page of the room is whatever rectangle the detector found
there. The outline, the layout and the scan delivery were seen on the device; nothing was tried on an iPad 2.

## Foundation, MapKit and CoreMotion: the names the Swift sources of Telegram call

The armv7 build of Telegram 13.0.0 stopped on these lines. Each is the Swift view of a name that the port now implements
below it, and the sources of Telegram stay as they are.

- `DateSuggestion.swift:46, 51, 57, 136`: `Calendar.dateComponents(in:from:)` and `Calendar.nextDate(after:matching:matchingPolicy:repeatedTimePolicy:direction:)`.
  The overlay's methods call `-componentsInTimeZone:fromDate:` and `-nextDateAfterDate:matchingComponents:options:`, which
  Backports implement, and the overlay named them differently from the selectors, so the lowering could not see it
  (`SWIFT_OVERLAY_NAMES` in `lowered.lua` now pairs them). `nextDateAfterDate:matchingComponents:options:` is the system
  search and not an approximation: from the start it walks to the next period whose value matches the coarsest
  component given, and resolves a missing day of the month, a time inside a spring gap and a repeated autumn hour by the
  matching policy and by First and Last counted in the direction of the search. `calendar_match_test.m` compares it with
  the host's answer in 23960 cases (21 component shapes, ten option sets, six zones, twenty instants around their
  transitions) and the answers agree to the second. Two answers of the host are not reproduced because they are defects of
  the host and not rules: a backward weekday-ordinal search returns nil, and a backward day-of-month search that starts
  on a day with a repeated hour returns a date 28 years early. Components the walk does not model (era, week year,
  nanosecond, day of year, a quarter outside the Gregorian calendar) take the older, simpler path, which answers the same
  for them as before.
- `MediaPickerGridItem.swift:483`: `Date.formatted(date:time:)`. The overlay has `Date.FormatStyle` with its date and time
  styles. The pattern is asked from ICU's `udatpg_*` with the locale and its calendar, and the exports are in the
  iOS 6.0 libicucore (read from its dyld cache). `date_format_style_test.lua` compares the output with the host's.
- `WalletCurrencyListContextItem.swift:77`: `Locale.Language.maximalIdentifier`, built on `uloc_addLikelySubtags`.
  `minimalIdentifier`, `isEquivalent(to:)` and the two `Components` initializers came with it. `parent`,
  `hasCommonParent(with:)` and `systemLanguages` are not provided: they come from CLDR parent tables and the list of the
  system's languages, which iOS 6 does not have.
- `BrowserMarkdown.swift:1212`: `NSAttributedString(markdown:options:baseURL:)`. The parser is Backports
  (`NSAttributedStringMarkdown15.m`) and the Swift side (`AttributedString`, `MarkdownParsingOptions`) is in the overlay.
  `attributed_string_markdown_test.lua` compares the Swift side with the host's, but on the host that side calls the host's
  own parser, so it does not test the Backports parser; `MarkdownDumpProbe` on a device does (see below).
- `BrowserMarkdown.swift:2481`: a `switch` over `PresentationIntent.Kind` with a `default` after all twelve cases. The
  SDK's Foundation is built with library evolution, so its enums are not frozen and the `default` is reachable for a
  case a later release adds. The overlay is not built that way, so its enum was exhaustive and the compiler reported
  "default will never be executed", an error under the `-warnings-as-errors` of the Telegram build. The case list is the
  SDK's (twelve cases, same labels). Library evolution is not the remedy on iOS 6: a resilient layout makes a client's
  class need `_objc_realizeClassFromSwift`, which only iOS 12 has (the runtime notes in the packages reference). The
  overlays mark the enumerations the SDK does not freeze with `@nonexhaustive` instead: 70 of the 79 enumerations the
  overlays share with the SDK (the other nine are frozen there, and stay exhaustive here). `toolchain/tests/addon/
  overlay_enums_test.lua` finds them by comparing each overlay module with the SDK's through `swift-api-digester`, and
  compiles a client of every one: a switch without a default is diagnosed as the SDK's is, and `@unknown default` is
  clean. The attribute is read by the type checker, not by SIL generation, which decides whether a `default` is
  reachable from the resilience of the enumeration's module alone (`EnumDecl::isEffectivelyExhaustive`); so a `default`
  after every case still draws "default will never be executed", and `swiftc -typecheck` does not show it, because the
  diagnostic comes from SIL generation, so a replay that looks for it must use `-emit-sil`. Until the compiler honours
  the attribute there, `PresentationIntent.Kind` has one more case, `_nonfrozen`, marked `@available(*, unavailable)`:
  no code can name or build it and no switch has to cover it, and SIL generation counts it among the cases, so a
  `default` compiles without a diagnostic.
- `LocationUtils.swift:153`: `MKDirectionsRequest.transportType`, with `requestsAlternateRoutes`, `departureDate` and
  `arrivalDate`, kept per request. `MapRequestProbe` runs 14 checks on an iPhone 4S, iOS 6.1.3, and all pass.
- `WebAppController.swift:2827`: `CMDeviceMotion.heading`. The geometry is checked on the host against poses built from
  known headings, tilts and rolls, and `MotionHeadingProbe` runs 13 checks on an iPhone 4S, iOS 6.1.3, all passing.

Two more findings came out of the comparison of the overlays with the SDK's enumerations.
`Locale.MeasurementSystem` is a structure in the SDK (`metric`, `us` and `uk` are static values of a string identifier,
compared without case), and the overlay's was an enumeration, which no SDK program can switch over as one; the overlay
has the SDK's structure now, and `locale_language_test.lua` compares it with the host's. `OSLogPrivacy` is a frozen
structure in the SDK and an enumeration of four cases in the overlay, whose `mask:` forms are missing; no client can
switch over the SDK's, so it was left as it is and is a gap of its own.

A change that is not Telegram's: the lowering of the Calendar methods was by name, so the two overloads that return a
`DateInterval` lost their iOS 10 gate with the iOS 8 methods of the same name, and the runtime did not build from source.
A method whose signature names `DateInterval` is lowered only when `DateInterval` itself is implemented
(`names_unlowered_type` in `lowered.lua`; `lowering_test.lua` has the three overloads).

## What is not verified

- A live heading in a north reference frame. `CMDeviceMotion` takes `xMagneticNorthZVertical` and
  `xTrueNorthZVertical` only after the phone has been moved to calibrate (CMErrorDomain 101 otherwise), so the delivery
  paths' tag of the frame and the geometry are checked, and the heading a moving phone reports is not.
- `NSAttributedString(markdown:)` on a device is verified, with one exception below. `MarkdownDumpProbe`
  (`tests/device_probe/markdown_dump_main.m`) prints the runs and the presentation intents of every string in
  `markdown_corpus.txt` (763 strings, each in three syntax modes) to be compared line for line with
  `markdown_dump.expected`, the host Foundation's output of the same program. On an iPhone 4S, iOS 6.1.3, the two are
  identical. The first run, on 20 strings, found that the probe crashed on a null weak import (it compiled the parser
  without the source that defines the four attribute-name constants iOS 6 does not export) and that the parser
  crashed with an `NSRangeException` on nested emphasis; both are fixed. It also found that the parser agreed with the
  host on 15 of 60 cases, so the parser is now `RevenantMarkdownParser.m`, a port of cmark-gfm 0.29, checked on the host
  by `tests/markdown_parser_oracle_test.lua` against the host's own parser on the corpus, on every `<!--` string up to
  seven characters and on random sources. Matching the host meant copying what is a defect of cmark-gfm 0.29 or of
  Apple's fork, and these are kept on purpose, so a later "fix" shows up as a failing test: an attribute group
  (`^[`, text, `]` and parenthesised attributes) is read, its attributes dropped, a bracketed label after it swallowed
  and no link made; `^[x]: text` is a reference
  definition that consumes the line; a reference definition keeps the title it read before a failed rewind; a link
  title is the longest one the host's regular expression scans; an email autolink attempt shares its state with the
  next attempt in the same text and the rewind of the next starts at the end of the scanned region; a table whose
  start fails keeps the rest of its paragraph from forming one, and a paragraph before a table header takes no
  reference definitions; the emphasis opener limit is kept per delimiter position; once a `<!--` fails to close, no
  later `<!` construct is read as HTML; CDATA follows the host's regular expression; the text of a `<...>` autolink is
  unescaped; one leading U+FEFF is dropped from the string of every node (the host's UTF-8 to string conversion), besides
  the one skipped at the start of the document, and a NUL becomes U+FFFD in every syntax. The parser searches and
  splits strings literally: a non-literal replace did not see a carriage return followed by a combining mark, which the
  host reads as a line end. The exception is the URL object: iOS 6's `NSURL` rejects what the host keeps and
  does not map hosts through IDNA, so 30 strings in `markdown_url_corpus.txt` (87 of the 279 lines
  of the device's output differ from `markdown_url_dump.expected`, measured on an iPhone 4S on 2026-11-09) have the same text and runs but a different `NSLink`, or none: a no-break space,
  U+2003, U+3000, U+0085 or U+200B in a bare URL, a non-ASCII character or a combining mark in a host (the host
  gives `xn--` labels, the device a percent-encoded host), an ASCII character the host refuses in a host or port
  (`|`, `[`, `]`, `'`, an unclosed `[::1`), a scheme that does not start with a letter (`-a:b`, `+a:b`, `.mailto:a@b.c`
  are relative references on the host), and a leading U+FEFF in a host. The parser is not involved: both sides read
  the same destination. The `NSURL` backport (`URLWithString:encodingInvalidCharacters:`) follows macOS's `NSURL` (C55),
  and the parser tries it only when the device's own `NSURL` refuses the string; the host's markdown keeps what no
  `NSURL` holds (a space or a no-break space in a host, a scheme that does not start with a letter read as a relative
  reference), so the differences stay. A sample of 1500 link destinations made of such characters differed
  on 186 (12 percent), all of them this kind; the destinations of real documents are almost always ASCII and valid.
- The UIMenu initializers, the CallKit, CoreMedia and PhotosUI overlays and `INStartCallIntent` were typechecked
  together with Telegram's lines and built in the runtime. They have not run on a device.
- Nothing here draws a menu subtitle or a selected image, and no Live Photo, slow-motion or time-lapse asset exists on
  iOS 6.1.3, so those subtypes stay clear.
- `AVAudioPlayer`'s hint is measured on one device and one release.
- The WebKit members above compile and typecheck at armv7 against the lowered SDK, and the codec, the error mapping and
  the overlay have host tests. The engine is not built here, so `callAsyncJavaScript` and `createWebArchiveData` have not
  run in a page, and that `RevWebDataSource` answers `webArchive` is read from its header, not observed.
- `PDFView` has a host test for its layout (47 checks) and has been compiled for armv7. `PDFViewProbe`
  (`tests/device_probe/pdfview_main.m`) runs 32 checks on a device: the generated document, the find, the defaults, the
  automatic scale, the navigation and its history, the conversions, the limits of the scale, the two-up row and the
  drawing of a page. It compiles at armv7 against the lowered SDK, but it has not been built or run: a device build of
  the Backports needs `webkit-engine`, `swift-runtime` and the other packages of its target, which have no prebuilt
  here. The tiles, the scrolling, the pinch and the tap handling are therefore not exercised anywhere yet.
