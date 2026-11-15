# Expo native modules built for iOS 6

expo-file-system, expo-document-picker, expo-image-manipulator, expo-image and expo-camera build from their npm tarballs, with
patches in `packages/e/<name>/patches/`, into the one Swift module `ExpoAppModules`. Their coverage rows are `partial`, verified
`build`: the host links them and starts under the old runtime; their calls are not yet exercised on the phone.

## What each patch removes, why, and what JS sees

| Module | Removed | Why | What JS gets |
| --- | --- | --- | --- |
| expo-file-system | iOS 13/14 gates; `FileHandle(forReadingFrom:)`; `volumeAvailableCapacityForImportantUsage` | not in iOS 6 | handles are opened by path; `FileHandleBackports.swift` maps `read(upToCount:)`, `write(contentsOf:)`, `offset()`, `seekToEnd()` onto the refined Backports members; free space uses `volumeAvailableCapacityKey` |
| expo-document-picker | nothing; type names renamed (collision inside `ExpoAppModules`) | none | the module as published |
| expo-image-manipulator | nothing; `ImageFormat` renamed `ManipulatorImageFormat` | name collision | the module as published |
| expo-image | AVIF and SVG coders, HEIC coder, Apple WebP codec, SF Symbol effects and transitions, Live Text | the frameworks (CoreSVG, Symbols, VisionKit) or codecs do not exist on iOS 6 | `enableLiveTextInteraction` and SF Symbol effects log "needs iOS 16/17; this iOS has none" and do nothing visible; AVIF and SVG sources fail to decode and raise the image `onError` event; WebP decodes through SDWebImageWebPCoder (libwebp 1.6.0) |
| expo-camera | VisionKit scanner, `import Vision` symbology conversion, video codec enumeration, `NotificationCenter.notifications` | VisionKit and Vision are iOS 11/13; the async notification stream is iOS 15 | `isModernBarcodeScannerAvailable` is `false`; `launchScanner` throws `CameraScannerUnavailableException`; `getAvailableVideoCodecs` returns `[]`; a requested codec rejects with `CameraRecordingException`; `CameraView` barcodes scan through ZXingObjC (QR, 1D, PDF417) |

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
`frameworks/ReactNative/tests/coverage_test.lua` and `isolate_test.lua` check the rules. On the phone the log shows no module
errors at start (A/B run under swift-runtime 0a2b76cd).
