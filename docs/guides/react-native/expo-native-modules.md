# Expo native modules built for iOS 6

expo-file-system, expo-document-picker, expo-image-manipulator, expo-image and expo-camera build from their npm tarballs, with
patches in `packages/e/<name>/patches/`, into the one Swift module `ExpoAppModules`. Their coverage rows are `partial`, verified
`phone`: on the iPhone 4S (2026-11-16) the host registers each of them with its exports; their calls are not yet exercised.

## What each patch removes, why, and what JS sees

| Module | Removed | Why | What JS gets |
| --- | --- | --- | --- |
| expo-file-system | iOS 13/14 gates; `FileHandle(forReadingFrom:)`; `volumeAvailableCapacityForImportantUsage` | not in iOS 6 | handles are opened by path; `FileHandleBackports.swift` maps `read(upToCount:)`, `write(contentsOf:)`, `offset()`, `seekToEnd()` onto the refined Backports members; free space uses `volumeAvailableCapacityKey` |
| expo-document-picker | nothing; type names renamed (collision inside `ExpoAppModules`) | none | the module as published |
| expo-image-manipulator | nothing; `ImageFormat` renamed `ManipulatorImageFormat` | name collision | the module as published |
| expo-image | AVIF and SVG coders, HEIC coder, Apple WebP codec, SF Symbol effects and transitions, Live Text | the frameworks (CoreSVG, Symbols, VisionKit) or codecs do not exist on iOS 6 | `enableLiveTextInteraction` and SF Symbol effects log "needs iOS 16/17; this iOS has none" and do nothing visible; AVIF and SVG sources fail to decode and raise the image `onError` event; WebP decodes through SDWebImageWebPCoder (libwebp 1.6.0) |
| expo-camera | VisionKit scanner, `import Vision` symbology conversion, video codec enumeration, `NotificationCenter.notifications` | VisionKit and Vision are iOS 11/13; the async notification stream is iOS 15 | `isModernBarcodeScannerAvailable` is `false`; `launchScanner` throws `CameraScannerUnavailableException`; `getAvailableVideoCodecs` returns `[]`; a requested codec rejects with `CameraRecordingException`; `CameraView` barcodes scan through ZXingObjC (QR, 1D, PDF417) |

## Modules outside the Paseo application (block 3)

These packages are recipes with their iOS 6 patches (`packages/e/<name>/patches/`); each installs, its patch applies, and the host
(Swift module `ExpoAppModules`) compiles and links them, and the phone window of 2026-11-16 ran a probe in it (`frameworks/ReactNative/src/probe/modules.js`). expo-brightness,
expo-device, expo-network and expo-store-review answered their calls (`real`, `phone`); expo-linear-gradient is registered (`partial`, `phone`);
expo-secure-store is registered but the keychain refuses every write with errSecInteractionNotAllowed (-25308), with or without
`keychain-access-groups` in the signature: the iPad 2 and the iPhone 4S return it for every keychain call (see
`docs/reference/backports/Security/README.md`), so the row is `partial`, `phone`.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-secure-store | LocalAuthentication, `SecAccessControl`, the passcode-bound keychain class | iOS 8 | `canUseBiometricAuthentication` is `false`; `requireAuthentication: true` and `WHEN_PASSCODE_SET_THIS_DEVICE_ONLY` reject with an exception that names iOS 8; the rest is SecItem as upstream |
| expo-network | `NWPathMonitor` (Network.framework) | iOS 12 | the state comes from `SCNetworkReachability`: `WIFI`, `CELLULAR` or `NONE`; `ETHERNET` and `UNKNOWN` never appear; `isInternetReachable` equals `isConnected`, as upstream |
| expo-device | Mac Catalyst and iOS-app-on-Mac checks | iOS 13, 14 | the module as published, with the model names of the devices iOS 6 runs on added |
| expo-store-review | `SKStoreReviewController`, window scenes | iOS 10.3, 13 | `isAvailableAsync` is `false` and there is no native `requestReview`, so the JavaScript opens the store page by URL |
| expo-brightness, expo-linear-gradient | nothing | `UIScreen` brightness and `CAGradientLayer` exist on iOS 6 | the modules as published |

These three were rewritten and compiled into the host in the same build; the phone shows each registered, their calls are not
exercised, so the rows are `partial`, `phone`.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-web-browser | `SFSafariViewController`, `ASWebAuthenticationSession`; `PresentationStyle` renamed `WebBrowserPresentationStyle` | iOS 9, iOS 12; name collision inside `ExpoAppModules` | `openBrowserAsync` opens the URL in Safari and resolves `{type: "opened"}`; the style options are accepted and ignored; `dismissBrowser` raises "no web browser to dismiss"; `openAuthSessionAsync` rejects naming iOS 12 |
| expo-blur | `UIVisualEffectView` | iOS 8 | a Core Image Gaussian blur of a snapshot of the view behind, with a white or black tint; it is taken when the view is added, resized or its intensity changes and does not follow later changes behind it |
| expo-screen-orientation | trait collections, window scenes, `requestGeometryUpdate`, the safe-area notch test; the `RNSScreenWindowTraits` protocol is declared in Swift | iOS 8, 13, 16, 11 | the status-bar orientation and the size classes of the device idiom (iPhone: portrait regular/compact, landscape compact/compact); on the 4S `getOrientationAsync` answered unknown at start |

## MessageUI and printing (block 4)

These packages are recipes with iOS 6 patches; each installs, its patch applies, and the host compiles and links it. None has been
exercised on the phone, so their coverage rows are `real`, verified `build`.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-mail-composer | `UIAdaptivePresentationControllerDelegate`, the `presentationController` hook; the iOS 7 attachments are guarded; four names that collide inside `ExpoAppModules` are renamed | iOS 8, 13; attachments are an iOS 7 MessageUI API; the shared Swift module has one namespace | `isAvailableAsync` and `composeAsync` use `MFMailComposeViewController.canSendMail` and the compose sheet, both present on iOS 6; a request with attachments rejects with an exception that names iOS 7; interactive sheet dismissal is absent |
| expo-sms | the unused `UniformTypeIdentifiers` import; the iOS 7 MMS attachments are guarded | the framework is iOS 14; attachments are an iOS 7 MessageUI API | `isAvailableAsync` and `sendSMSAsync` use `MFMessageComposeViewController.canSendText` and the compose sheet, both present on iOS 6; a request with attachments rejects with an exception that names iOS 7 |
| expo-print | `WKWebView` and `WebKit`; `URLSession`; the iOS 7 and 8 printer options; the iOS 7 `NSData` base64 method; one colliding exception name | WKWebView and URLSession are iOS 8 and 7 and WebKit is not linked in the Hermes host; specific-printer printing and printer selection are iOS 8 | HTML is rendered to PDF by `UIMarkupTextPrintFormatter` and drawn through `UIPrintPageRenderer` (iOS 4.2); http URIs are fetched with `NSURLConnection`; `print` shows `UIPrintInteractionController` on iOS 6; `selectPrinter` and a `printerUrl` reject with an exception that names iOS 8; `base64` uses a small encoder on iOS 6 |
| expo-sensors | nothing; `CMPedometer` and `CMAltimeter` come from the CoreMotion backport (`CoreMotionBackports`, linked by the host) | both classes are iOS 8 | the module as published: accelerometer, gyroscope, magnetometer and device motion use `CMMotionManager` (iOS 4); Pedometer and Barometer call the backport classes; built and linked, not exercised on the phone |
| expo-cellular | nothing; the `CTRadioAccessTechnology*` constants and the per-service radio lookup come from the CoreTelephony backport (`CoreTelephonyBackports`, linked by the host) | the constants are iOS 7, the per-service property iOS 12 | the module as published: `getCellularGenerationAsync` maps the radio technology to 2G, 3G or 4G as upstream; built and linked, not exercised on the phone |
| expo-location | `CLLocation.ellipsoidalAltitude` replaced by `altitude` (EXLocation.m, Geocoder.swift) | `ellipsoidalAltitude` is iOS 15 | the services as published on `CLLocationManager` and `CLGeocoder`, with the later CoreLocation calls from the CoreLocation backport; the altitude is the iOS 6 `altitude`; background location and geofencing run through expo-task-manager (built, not exercised); built and linked, not exercised on the phone |
| expo-task-manager | nothing; the package's `Tests/` folder is left out of the host build, and the `UMAppLoader` pod it imports comes from the `unimodules-app-loader` recipe | the tests import `ExpoModulesTestCore`, which the host does not carry | the module as published; background fetch (iOS 7) and BGTask are absent on iOS 6, so a fetch task is never woken by the system and tasks run in the foreground or the `beginBackgroundTaskWithExpirationHandler` window; built and linked, not exercised on the phone |
| expo-video-thumbnails | three exception classes renamed (`VideoThumbnails…`) | their names collide with expo-image-manipulator's inside the shared Swift module | `getThumbnail` grabs a frame with `AVAssetImageGenerator` and saves a JPEG, all iOS 4 APIs; built and linked, not exercised on the phone |

## AVIF and SVG decision (2026-11-16)

- SVG: not feasible. SDWebImageSVGCoder renders through CoreSVG, which iOS 6 does not have. A different renderer would be a new
  port, not a patch of expo-image.
- AVIF: feasible in principle (libavif with dav1d and libyuv), but none of the three is packaged. It is a separate task; until
  then AVIF is removed and fails loudly as above.

## Pods

`sdwebimage 5.21.7`, `sdwebimage-webp 0.14.6` and `zxingobjc 3.6.4` are packages under `packages/s` and `packages/z`.
`isolate.lua` adds the `add_requires` lines only for the modules in `RN_EXPO_REAL` that use them (`POD_REQUIRES`); `isolate.lua build`
fails with "make the copy again" when a copy predates that. `src/expo/xmake.lua` writes each pod's module map and flags into
`build/expo-core/implicit.rsp`.

## Contacts and calendar (block 5)

expo-calendar is a recipe with an iOS 6 patch (packages/e/expo-calendar/patches); it installs, its patch applies, and the host compiles and links it. It has not been exercised on the phone.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-calendar | nothing; `MissingCurrentViewControllerException` renamed `CalendarMissingCurrentViewControllerException` | the name collides with expo-sharing's inside the shared Swift module `ExpoAppModules` | the module as published: EventKit (`EKEventStore`, `EKEvent`, `EKCalendar`) and the EventKitUI event and edit view controllers are present on iOS 6; the iOS 17 write-only permission branches are behind `#available` and are not taken; built and linked, not exercised on the phone |

expo-contacts is a recipe with one name patch (packages/e/expo-contacts/patches) and the later `CNLabel*` constants in the Contacts backport. Its host build is not green, so its coverage row is partial and its calls are not verified.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-contacts | `Image` renamed `ContactImageRecord`; three exceptions colliding with expo-file-system renamed; the ContactsUI form and picker sources are not built, pending a separate backport task | the first two are name collisions inside `ExpoAppModules`; `CNContactViewController` and `CNContactPickerViewController` are iOS 9 and have no backport yet, and the task forbids a throwing shim | contact data operations through the Contacts backport are compiled but not verified; `presentFormAsync`, `presentContactPickerAsync` and the next form functions are absent until a ContactsUI backport over `ABPersonViewController`, `ABNewPersonViewController` and `ABPeoplePickerNavigationController` lands |

## Media library (block 5)

expo-media-library is a recipe with an iOS 6 patch (packages/e/expo-media-library/patches); it installs, its patch applies, and the host compiles and links it. It has not been exercised on the phone.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-media-library | nothing removed; `AssetInfo`, `MediaType`, `PermissionsModuleNotFoundException` and the three permission requester classes renamed with an `ExpoML` prefix | their names collide with expo-image-picker's inside the shared Swift module `ExpoAppModules` | the module as published against the Photos backport over AssetsLibrary: `getMomentsAsync` returns the AssetsLibrary Event collections, the audio media-type constant has its SDK value, and the Photos change-details extensions resolve through the backported `swiftPhotos` runtime; audio assets and all phone behaviour are not verified |

## How to check

`./xmakew l -P . frameworks/ReactNative/tools/coverage.lua` regenerates `docs/reference/react-native/coverage.md`;
`frameworks/ReactNative/tests/coverage_test.lua` and `isolate_test.lua` check the rules. On the phone the probe of
`host_install.lua window` reports each module's registration, exports and the calls above.
