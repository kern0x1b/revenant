# The surfaces Telegram 13.0.0 reached at the iOS 6 floor

A build of Telegram 13.0.0 for armv7 at iOS 6.0 stopped on three names the lowered SDK still gated, and a sweep of the
families around them found more. Each entry says what the name does on iOS 6.1.3 and what the port does with it. The
sources of Telegram stay as they are. `frameworks/Backports/tests/availability/telegram_lines.swift` holds Telegram's own
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

## What is not verified

- The UIMenu initializers, the CallKit, CoreMedia and PhotosUI overlays and `INStartCallIntent` were typechecked
  together with Telegram's lines and built in the runtime. They have not run on a device.
- Nothing here draws a menu subtitle or a selected image, and no Live Photo, slow-motion or time-lapse asset exists on
  iOS 6.1.3, so those subtypes stay clear.
- `AVAudioPlayer`'s hint is measured on one device and one release.
