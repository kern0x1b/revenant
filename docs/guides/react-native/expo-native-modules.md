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
expo-secure-store is registered but the keychain refuses every write with errSecInteractionNotAllowed because the host was signed
without `keychain-access-groups`; `src/host/entitlements.xml` adds it and the row stays `partial`, `build` until a window shows the round trip.

| Module | Removed or replaced | Why | What JS sees |
| --- | --- | --- | --- |
| expo-secure-store | LocalAuthentication, `SecAccessControl`, the passcode-bound keychain class | iOS 8 | `canUseBiometricAuthentication` is `false`; `requireAuthentication: true` and `WHEN_PASSCODE_SET_THIS_DEVICE_ONLY` reject with an exception that names iOS 8; the rest is SecItem as upstream |
| expo-network | `NWPathMonitor` (Network.framework) | iOS 12 | the state comes from `SCNetworkReachability`: `WIFI`, `CELLULAR` or `NONE`; `ETHERNET` and `UNKNOWN` never appear; `isInternetReachable` equals `isConnected`, as upstream |
| expo-device | Mac Catalyst and iOS-app-on-Mac checks | iOS 13, 14 | the module as published, with the model names of the devices iOS 6 runs on added |
| expo-store-review | `SKStoreReviewController`, window scenes | iOS 10.3, 13 | `isAvailableAsync` is `false` and there is no native `requestReview`, so the JavaScript opens the store page by URL |
| expo-brightness, expo-linear-gradient | nothing | `UIScreen` brightness and `CAGradientLayer` exist on iOS 6 | the modules as published |

Not started because each needs a rewrite and a compiler to check it: expo-web-browser (`SFSafariViewController` is iOS 9 and
`ASWebAuthenticationSession` iOS 12: opening a URL in Safari is possible, an authentication session is not), expo-blur
(`UIVisualEffectView` is iOS 8; a blur on iOS 6 means rendering a snapshot through Core Image) and expo-screen-orientation (window
scenes and `requestGeometryUpdate` are iOS 13 and 16; the view-controller orientation path is the analog).

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

## How to check

`./xmakew l -P . frameworks/ReactNative/tools/coverage.lua` regenerates `docs/reference/react-native/coverage.md`;
`frameworks/ReactNative/tests/coverage_test.lua` and `isolate_test.lua` check the rules. On the phone the probe of
`host_install.lua window` reports each module's registration, exports and the calls above.
