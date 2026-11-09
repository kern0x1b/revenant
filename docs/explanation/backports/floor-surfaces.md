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
`beginFindString` path), selecting text by touch, and `PDFThumbnailView`. `PDFDocument` cannot be edited: `insertPage`,
`PDFPage(image:)` and writing a changed document are not implemented, so a `PDFDocument()` stays empty. Telegram's
document scanner builds such a document, and it also needs VisionKit, which iOS 6 does not have.

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
- `LocationUtils.swift:153`: `MKDirectionsRequest.transportType`, with `requestsAlternateRoutes`, `departureDate` and
  `arrivalDate`, kept per request. `MapRequestProbe` runs 14 checks on an iPhone 4S, iOS 6.1.3, and all pass.
- `WebAppController.swift:2827`: `CMDeviceMotion.heading`. The geometry is checked on the host against poses built from
  known headings, tilts and rolls, and `MotionHeadingProbe` runs 13 checks on an iPhone 4S, iOS 6.1.3, all passing.

A change that is not Telegram's: the lowering of the Calendar methods was by name, so the two overloads that return a
`DateInterval` lost their iOS 10 gate with the iOS 8 methods of the same name, and the runtime did not build from source.
A method whose signature names `DateInterval` is lowered only when `DateInterval` itself is implemented
(`names_unlowered_type` in `lowered.lua`; `lowering_test.lua` has the three overloads).

## What is not verified

- A live heading in a north reference frame. `CMDeviceMotion` takes `xMagneticNorthZVertical` and
  `xTrueNorthZVertical` only after the phone has been moved to calibrate (CMErrorDomain 101 otherwise), so the delivery
  paths' tag of the frame and the geometry are checked, and the heading a moving phone reports is not.
- `NSAttributedString(markdown:)` on a device: `MarkdownDumpProbe` (`tests/device_probe/markdown_dump_main.m`) prints the
  runs and the presentation intents of 20 strings in three syntax modes, to be compared line for line with
  `markdown_dump.expected`, which is the host Foundation's output of the same program. It ran on an iPhone 4S, iOS 6.1.3,
  and found two things. The probe itself crashed on a null weak import, because it compiled the parser without the
  source that defines the four attribute-name constants (`NSPresentationIntentAttributeName` and three more, which iOS 6
  does not export); it now defines them. The parser crashed with an `NSRangeException` on `***both*** _under_ __strong__
  *nested **inside** em*`: it attached an attribute over the length of the source span, not over the text it had
  appended, and the markers it removes make the two differ. That is fixed. What remains is that the parser is partial. It
  agrees with the host on 15 of 60 cases, and the full syntax, the one Telegram's `BrowserMarkdown` uses (`options: .init()`),
  differs on 11 of 20 strings: no `NSListItemDelimiter` attribute, table alignments always left, no `NSAlternateDescription`
  for a link or image title, a backslash hard break and a two-space break not split into `\n` runs with
  `NSInlinePresentationIntent` 128, inline HTML not marked with 256, Setext headings read as text and a rule, an ordered
  list not starting at its own number, a nested list not inside its parent item's intent chain, bare URLs not linked, and
  adjacent or nested emphasis misread. Nothing in the Swift host test reaches this parser (it calls the host's), so the
  probe is the only check, and a parser that follows CommonMark is the next piece of work for this name.
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
