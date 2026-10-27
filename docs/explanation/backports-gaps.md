# Backports: members that do not do what the real API does

Audit of `frameworks/Backports/src` and `toolchain/src/swift-runtime/overlay`, written 2026-10-27 on branch `work/stub-audit`. It is an audit only: no code was changed, nothing was built, and the device-only items below are not verified.

Legend: `B/` is `frameworks/Backports/src/`; `O/` is `toolchain/src/swift-runtime/overlay/`. Telegram paths are from `~/Git/reference/Telegram-iOS-release-13.0.0/` (read-only grep). Cat is the category and Size is S, M or L (both defined below).

## Scope and method

- Read: the files the scans flagged in `B/` and `O/`, and the body of each member a row cites, except where the row says it was not read.
- Scans, kept in scratch and not committed: a constant-return and empty-body scan of every member (1172 rows: 903 constant, 269 empty, over 686 selectors); the Swift `@available` lines (22 in `B/`, 4 in `O/`); the say-once call sites; and the refusal strings (`ENOTSUP`, `errSecUnimplemented`, `kAudio_UnimplementedError`, `NSFeatureUnsupportedError`, `VNErrorUnsupportedRequest`, `revenant_unsupported`, "not implemented").
- Telegram use: a grep for each selector or class name, then the matching line read. Word matches were noisy, so a row says "yes" only where the call itself was read. Where a guard around the call was read, the row says so.
- Real behaviour: each member's real behaviour is taken from the public Apple reference for that member, as the auditor knows it. It was not fetched in this pass. Check it against the SDK header before a fix.
- Owner rule applied: no iOS 6 gap is acceptable unless hardware absent on the A5 (iPhone 4S, iPad 2) makes the behaviour impossible. Where a behaviour can be reproduced, the Fix column says how.

Categories:

- F: fails or refuses (the error is invented, or refused by design).
- E: no effect (an empty body, or a value stored and never read).
- C: a constant or approximate answer where the real system computes a value.
- S: say-once (accepted, logged once, no effect).
- A: an `@available` gate hides a backported member from an iOS 6 target.
- H: hardware-justified (the honest answer, reproduced only where possible).
- D: a doc claim to correct.

Sizes: S is under a day; M is a few days, including a device test; L is a week or more, or waits on an owner decision.

## Counts

| Category | Telegram-used | Not Telegram | Total |
|---|---:|---:|---:|
| F | 6 | 4 | 10 |
| E | 7 | 5 | 12 |
| C | 8 | 9 | 17 |
| S | 4 | 2 | 6 |
| A | 2 | 1 | 3 |
| H | 3 | 3 | 6 |
| D | 0 | 1 | 1 |
| Total | 30 | 25 | 55 |

| Size | Telegram-used | Not Telegram | Total |
|---|---:|---:|---:|
| S | 9 | 11 | 20 |
| M | 9 | 7 | 16 |
| L | 12 | 7 | 19 |

## Top 15 (Telegram-used, by what a user sees)

1. T20 `UIFindInteraction`: no find bar, no matches, nothing to move between (E, L).
2. T01 `selectionChanged`: no selection haptic (E, S).
3. T19 `setOverrideUserInterfaceStyle`: the dark override is stored and never drawn (S, L).
4. T12 `inheritedAnimationDuration` is always 0 (C, M).
5. T11 `textInputMode` is nil (C, M).
6. T18 `usesInterfaceType` is an approximation, and Telegram's cellular decision reads it (C, M).
7. T13 `PHChange.hasMoves` is NO, and the moves are never enumerated (C, M).
8. T02 `addPresentedHandler:` never calls the block (E, S).
9. T21 alternate icon: refused with `NSFeatureUnsupportedError` (F, L).
10. T23 Sign in with Apple: completes with an error (F, L).
11. T27 speech recogniser: `initWithLocale:` is nil and authorisation is refused (F, L).
12. T22 HEVC and AV1: no software decode path (H, L).
13. T24 device passcode: refused with an invented message (F, L).
14. T10 `leadingBarButtonGroups`: stored, never shown (S, M).
15. T30 `PresentationIntent`: gated to iOS 15 in the overlay (A, L).

The top 15 are ranked by how visible the gap is to a Telegram user, not by row order.

## Telegram-used members (30)

Sorted by size: S, then M, then L.

| ID | Where | Member | Now | Real API (Apple reference) | Telegram 13.0.0 | Cat | Size | Fix |
|---|---|---|---|---|---|---|---|---|
| T01 | B/UIKit/UISelectionFeedbackGenerator.m:5-7 | `selectionChanged` | empty; no tick | plays the selection tick (UISelectionFeedbackGenerator) | yes, submodules/Display/Source/HapticFeedback.swift:21-22 | E | S | one pulse through `revenant_feedback_play`, as UINotificationFeedbackGenerator does |
| T02 | B/Metal/RevenantMetalDrawable.m:59-61 | `addPresentedHandler:` | empty; the block is never called | calls the block after the drawable is presented, with the drawable (MTLDrawable) | yes, submodules/TelegramCallsUI/Sources/MetalVideoRenderingView.swift:647 | E | S | fixed: the block is kept (copied into an array, as `addObject:`) and called once with the drawable after `present` has presented the renderbuffer and released the device (B/Metal/RevenantMetalDrawable.m). Verified: the SDK declaration and the body are checked by `backports/ios6members`, and the file compiles for armv7 iOS 6.0. Not run on device, and whether Telegram waits on it is not verified |
| T03 | B/StoreKit/AppStore.swift:4-8 (gate at :5) | `AppStore.showManageSubscriptions(in:)` | gated `@available(iOS 15.0, *)`, so iOS 6 does not see it; the body opens the subscriptions URL and returns | presents the subscriptions sheet in the scene and returns when it is dismissed (AppStore) | yes, submodules/TelegramUI/Sources/AppDelegate.swift:939 | A | S | drop the gate; the sheet cannot be reproduced, so the URL stays as the fallback and the doc says so |
| T04 | B/UIKit/UIPanGestureRecognizer+ScrollTypes134.m:10-20 | `allowedScrollTypesMask` | stored per recogniser; say-once when non-zero | limits the pan to scroll types: wheel, trackpad, touch (UIPanGestureRecognizer, iOS 13.4) | yes, submodules/ItemListUI/Sources/Items/ItemListEditableItem.swift:17; submodules/Display/Source/Navigation/NavigationModalContainer.swift:103 | S | S | keep the say-once; on device check that a touch pan is not blocked by the mask |
| T05 | B/UIKit/UIHoverGestureRecognizer.m:11-21 | `UIHoverGestureRecognizer` | say-once; `touchesBegan:` sets the state to failed, so it never recognises | recognises a pointer hovering over the view (UIHoverGestureRecognizer) | yes, submodules/TelegramUI/Components/ContextControllerImpl/Sources/ContextControllerImpl.swift:372 | S | S | keep; the verdict is hardware (see Hardware claims) |
| T06 | B/UIKit/UIPencilInteraction12.m:10-18 | `+preferredTapAction`, `+prefersPencilOnlyDrawing` | constant: ignore, and NO; the delegate is stored and never called | the user's double-tap action, and the delegate callbacks (UIPencilInteraction) | yes, submodules/DrawingUI/Sources/DrawingView.swift:171 | C | S | keep; no Apple Pencil on A5 hardware |
| T07 | B/AVFoundation/AVCaptureSession+ApplicationAudioSession7.m:27-29 | `-automaticallyConfiguresApplicationAudioSession` | constant NO; setting YES says once (:24, :35) | when YES, the session configures the shared audio session (AVCaptureSession) | yes, sets NO: submodules/Camera/CameraLegacy/Sources/LegacyCamera.swift:740; submodules/Camera/CameraNeo/Sources/CameraNeo.swift:97 | C | S | nothing for Telegram, which sets NO; the YES path needs the audio session configured, which no caller in this audit needs |
| T08 | B/CoreMotion/CMMotionActivityManager.m:5-7 | `+isActivityAvailable` | NO | YES only where the motion coprocessor (M7) exists (CMMotionActivityManager) | yes, submodules/LegacyComponents/Sources/TGNavigationBar.m:152; submodules/LegacyComponents/Sources/TGModernGalleryDefaultInterfaceView.m:51 | H | S | keep NO; the coprocessor is absent on A5. The activity handlers were not read in this pass |
| T09 | B/AVFoundation/AVCaptureMultiCamSession13.m:5-12 | `+isMultiCamSupported`; `-init` raises `NSInternalInconsistencyException` | NO; init raises | YES only on hardware that runs two cameras at once (AVCaptureMultiCamSession) | yes, submodules/Camera/CameraLegacy/Sources/LegacyCameraImpl.swift:8; submodules/Camera/CameraNeo/Sources/NeoCameraImpl.swift:10 | H | S | keep; Telegram checks the answer before it creates the session |
| T10 | B/UIKit/UITextInputAssistantItem.m:7-8, 37-46 | `leadingBarButtonGroups`, `trailingBarButtonGroups` | stored; say-once at :7; the groups are never shown | the groups in the keyboard's shortcut bar; iPad shows that bar above the software keyboard too (verify on iPad) | yes, submodules/AttachmentTextInputPanelNode/Sources/AttachmentTextInputPanelNode.swift:745; submodules/TelegramUI/Components/Wallet/WalletSendScreen/Sources/WalletSendAmountField.swift:373 | S | M | show the groups as the input accessory view's bar on the software keyboard |
| T11 | B/UIKit/UIResponder+TextInput7.m:7-10 | `-textInputMode` | nil | the keyboard's current input mode; Telegram reads its `primaryLanguage` (UIResponder, textInputMode) | yes, submodules/AttachmentTextInputPanelNode/Sources/AttachmentTextInputPanelNode.swift:338 (15 files mention `textInputMode`) | C | M | fixed: `-textInputMode` returns `+[UITextInputMode currentInputMode]`, the mode the iOS 6 keyboard reports (B/UIKit/UIResponder+TextInput7.m). iOS 6.1.3 UIKit has the `UITextInputMode` class with `+currentInputMode` and `-primaryLanguage` (dyld shared cache strings). Verified: the header needles and the body are checked by `backports/ios6members`, and the file compiles for armv7 iOS 6.0. Not run on device, so the language value is not measured; a per-app override is not kept |
| T12 | B/UIKit/UIView+KeyframeAnimation7.m:91-93 | `+inheritedAnimationDuration` | constant 0 | the duration of the animation block in progress, 0 outside one (UIView, inheritedAnimationDuration) | yes, submodules/Display/Source/NativeWindowHostView.swift:271 | C | M | fixed: `RevenantAnimationDurationInherited` answers from a per-thread stack (B/UIKit/RevenantAnimationDuration.m) that the animate entry points and begin/set/commit swizzles push and pop (B/UIKit/UIView+InheritedAnimationDuration9.m; keyframes push in B/UIKit/UIView+KeyframeAnimation7.m). Verified: host test `UIKitBackports_animation_duration_test` (stack logic, 10 checks plus the negative run); the swizzled UIKit entry points are compile-checked for armv7 iOS 6.0 only. Not run or measured on device |
| T13 | B/Photos/PHChange8.m:222-229 | `-hasMoves`, `-enumerateMovesWithBlock:` | NO; empty block | the moves between two fetch results (PHChange, hasMoves) | yes, submodules/LegacyComponents/Sources/TGMediaAssetFetchResultChange.m:42-47; submodules/LegacyComponents/Sources/TGMediaAssetsUtils.m:162 | C | M | fixed: the change details stay incremental when the order changes (the `ordered` test is gone); the moves are the common items outside the longest increasing subsequence of their before indexes (B/Photos/RevenantPhotoMoves.c, used by B/Photos/PHChange8.m), and `hasMoves` and `enumerateMovesWithBlock:` report them as (from = before index, to = after index). Verified: host test `PhotosBackports_photo_moves_test` (2005 checks; the move count equals NSOrderedCollectionDifference's inferred moves on macOS for 2000 random changes, plus the known rotation and reversal); PHChange8.m compiles for armv7 iOS 6.0. The Photos glue is not run against a library on device |
| T14 | B/UIKit/UITextInputTraits11.m:44-46 (inside a macro) | `-passwordRules` | stored; nothing reads it | the rules that drive the strong-password generator (UITextInputTraits, passwordRules) | yes, submodules/PasswordSetupUI/Sources/TwoFactorAuthDataInputScreen.swift:1102 | E | M | the generator is system UI; honour the rules in the app's own validation, or keep as a documented no-op |
| T15 | B/UIKit/UITextField+ContentType.m:5-13; B/UIKit/UISearchBar+ContentType.m:5-13; B/UIKit/UITextView+ContentType.m:5-13; B/UIKit/RevenantTextContentType.m:6-20 | `-textContentType` | stored on the object; no keyboard or AutoFill effect | the AutoFill suggestion and the keyboard type (UITextContentType) | yes, submodules/CodeInputView/Sources/CodeInputView.swift:148 (`.oneTimeCode`); submodules/PasswordSetupUI/Sources/TwoFactorAuthDataInputScreen.swift:1095 (`.username`); 11 files in all | E | M | map the content type to the keyboard type (number pad for a one-time code); the AutoFill suggestion itself is system UI |
| T16 | B/UIKit/UIListContentProperties.m:298-306 | `-allowsDefaultTighteningForTruncation` (on UIListContentProperties) | stored; no layout effect | the NSParagraphStyle property that tightens text before truncation (NSParagraphStyle) | yes, submodules/Pasteboard/Sources/Pasteboard.swift:89 sets the NSParagraphStyle property; the backport member for that class was not located | E | M | first locate the NSParagraphStyle member; this accessor belongs to UIListContentConfiguration, not to Telegram's call |
| T17 | B/SceneKit/SCNView.m:420-428 | `-isJitteringEnabled` | stored; the accumulation is approximated (crutch C20) | jittered frames accumulated for antialiasing (SCNView, jitteringEnabled) | yes, submodules/TelegramUI/Components/Premium/PremiumStarComponent/Sources/PremiumStarComponent.swift:144, 772 | C | M | measure the accumulated image on device against Apple's output; C20 stays open until then |
| T18 | B/Network/NWPathMonitor.swift:34-36 | `NWPath.usesInterfaceType(_:)` | derived from status, expense and interface names (approximation) | true when the path uses the interface type (NWPath, usesInterfaceType) | yes, submodules/Reachability/Sources/Reachability.swift:105, 123 (the cellular decision) | C | M | read the interface type from the interface itself, and test on cellular and Wi-Fi on device |
| T19 | B/UIKit/UIView+iOS13.m:15-18 | `-setOverrideUserInterfaceStyle:` | stored; say-once "dark-override"; nothing restyles | forces the view's trait collection to dark (UIView, overrideUserInterfaceStyle, iOS 13) | yes, submodules/LegacyMediaPickerUI/Sources/LegacyICloudFilePicker.swift:16; submodules/WebUI/Sources/WebAppController.swift:306 | S | L | a trait override that every control honours is a large restyle; the say-once is honest until then |
| T20 | B/UIKit/UIFindInteraction.m:80-114 | `presentFindNavigatorShowingReplace:`, `findNext`, `findPrevious`, `updateResultCount` | stores the session and a visible flag; draws no navigator; the three methods are empty | shows the find bar, counts the matches and moves between them (UIFindInteraction) | yes, submodules/BrowserUI/Sources/BrowserWebContent.swift:638, 653 | E | L | a find bar and a search over the page content; where the search runs (WebKit side or the app) is not decided |
| T21 | B/UIKit/UIApplication+AlternateIcon.m:5-18 | `-supportsAlternateIcons`, `-alternateIconName`, `-setAlternateIconName:completionHandler:` | NO; nil; the completion gets `NSFeatureUnsupportedError` (NSCocoaErrorDomain) | changes the Home Screen icon with a system alert, and reports the current one (UIApplication, iOS 10.3) | yes, submodules/TelegramUI/Sources/AppDelegate.swift:1022 (set); submodules/SettingsUI/Sources/Themes/ThemeSettingsController.swift:527-528 and submodules/TelegramUpdateUI/Sources/UpdateInfoController.swift:128 (read) | F | L | SpringBoard owns the icon, so no in-process change exists; decision needed. Storing and returning the name (M) keeps the screens consistent but changes nothing on the Home Screen |
| T22 | B/VideoToolbox/VTIsHardwareDecodeSupported11_0.m:17-20; docs/explanation/backports-open-members.md:114 | `VTIsHardwareDecodeSupported` | false for every codec but H.264, so HEVC and AV1 report NO | true when the hardware decoder exists (VideoToolbox, VTIsHardwareDecodeSupported) | yes, submodules/MediaPlayer/Sources/MediaDataReader.swift:9; submodules/MediaPlayer/Sources/ChunkMediaPlayerV2.swift:10 (AV1) | H, D | L | the NO is true for the A5; the gap is the missing software path, which the doc calls "no by design" (open-members:114). A software decoder reproduces playback |
| T23 | B/AuthenticationServices/ASAuthorizationController.m:41-45 | `-performRequests` | completes with an error through `revenant_complete` (by design: there is no Apple ID service) | runs Sign in with Apple and returns a credential (AuthenticationServices, ASAuthorizationController) | yes, submodules/SettingsUI/Sources/Privacy and Security/LoginEmailSetupController.swift:13; 4 more files | F | L | needs Apple's identity service, which is not hardware; keep the refusal and document it, or decide otherwise |
| T24 | B/LocalAuthentication/LAContext.m:46-66 | `-canEvaluatePolicy:error:` (through `revenant_errorForPolicy:`) | policy 1 (biometrics): `LAErrorBiometryNotAvailable`; policy 2 (device passcode): `LAErrorNotInteractive` with the invented text "Displaying the required authentication user interface is forbidden."; any other policy raises (:56-57) | reports whether the policy can be evaluated (LocalAuthentication, LAContext) | yes, submodules/LocalAuth/Sources/LocalAuth.swift:88 (device-owner policy); submodules/SettingsUI/Sources/Privacy and Security/PasscodeOptionsController.swift:349 and PasscodeOptionsScreen.swift:227 (biometrics) | F, H | L | biometrics: honest on A5 (no Touch ID). Passcode: the refusal and its text are invented; the device-passcode screen is system UI that an iOS 6 app cannot call |
| T25 | B/Vision/Vision130.m:100; B/Vision/VNHandlers.m:170-178 | `VNRecognizeTextRequest` | refused with `VNErrorUnsupportedRequest` ("is not supported on this release") | finds and reads text in an image (Vision, VNRecognizeTextRequest, iOS 13) | yes, submodules/ImageContentAnalysis/Sources/ImageContentAnalysis.swift:307 (Telegram gates it on iOS 13) | F | L | an OCR engine; not hardware (crutch C25 lists the request class as open) |
| T26 | B/Vision/Vision130.m:72; B/Vision/VNHandlers.m:170-178 | `VNClassifyImageRequest` | refused with `VNErrorUnsupportedRequest` | classifies an image with Apple's model (Vision, VNClassifyImageRequest, iOS 13) | yes, submodules/TelegramUI/Components/MediaEditor/Sources/ImageObjectClassification.swift:26 | F | L | a classifier model; a data and engine decision, not hardware |
| T27 | B/Speech/SFSpeechRecognizer.m:21-24, 36-39 | `+requestAuthorization:`; `-initWithLocale:` | the request stores a flag and answers Restricted without a prompt; `initWithLocale:` returns nil | builds a recogniser for a locale and asks the user (Speech, SFSpeechRecognizer) | yes, submodules/Media/LocalAudioTranscription/Sources/LocalAudioTranscription.swift:18-44 (handles nil) | F | L | an offline recogniser; iOS 6 ships no speech engine. Not hardware, and a large item |
| T28 | B/Speech/SFSpeechAudioBufferRecognitionRequest.m:11-21 | `-appendAudioPCMBuffer:`, `-appendAudioSampleBuffer:`, `-endAudio` | empty; the audio is dropped | feeds audio into the recognition task and ends the input (Speech, SFSpeechAudioBufferRecognitionRequest) | not grepped for these selectors; LocalAudioTranscription.swift:18-44 uses the recogniser | E | L | depends on T27 |
| T29 | B/Speech/SFSpeechRecognizer.m:9-19; B/Speech/SFSpeechRecognitionTask.m:7-15 | `+supportedLocales` (empty set); `+authorizationStatus` (Restricted after a request, else NotDetermined); `isFinishing`, `isCancelled` (NO) | constants | the locales the engine supports; the authorisation status; the task's state (Speech) | yes, submodules/Media/LocalAudioTranscription/Sources/LocalAudioTranscription.swift:18-44 | C | L | follows T27; with an engine these become computed |
| T30 | O/Foundation/PresentationIntent.swift:239, 281, 314, 336 | four members gated `@available(iOS 15.0, macOS 12.0, *)` | hidden from an iOS 6 target; the docs list the lowering as an open gap | Markdown presentation intents on attributed strings (Foundation, PresentationIntent, iOS 15) | yes, submodules/BrowserUI/Sources/BrowserMarkdown.swift:8-9 (attribute keys) | A | L | lower the intents to iOS 6 attributes, then remove the gates. Telegram's own availability check around the read was not read |

## Not Telegram-used members (25)

Sorted by size: S, then M, then L.

| ID | Where | Member | Now | Real API (Apple reference) | Telegram 13.0.0 | Cat | Size | Fix |
|---|---|---|---|---|---|---|---|---|
| N01 | B/CoreSpotlight/CSSearchableIndex.m:275-277 | `+isIndexingAvailable` | YES, always | whether the system indexes searchable items (CSSearchableIndex) | no; the class is used (SpotlightContacts.swift:43, 102, 175), this member is not | C | S | answer from the state of the Spotlight manager the class already drives (not verified) |
| N02 | B/Metal/RevenantMetalDrawable.m:32-35 | `-drawableID` | 0 for every drawable | a unique ID per drawable (MTLDrawable, drawableID) | no | C | S | count the drawables in `RevenantMetalNextDrawable` |
| N03 | B/Metal/RevenantMetalDrawable.m:63-66 | `-presentedTime` | 0 | the time the drawable was presented (MTLDrawable, presentedTime) | no; submodules/TelegramUI/Components/CoreList/CoreListDemo/PipelineDepthProbe.swift:16 is a comment | C | S | record the time in `present` |
| N04 | B/Metal/MTLHeap10.m:197; B/Metal/RevenantMetalBuffer.m:92 | `-setPurgeableState:` | NO, in a BOOL return | returns the previous MTLPurgeableState (MTLResource, setPurgeableState:) | no | C | S | keep the state per resource and return the previous one; the GLES buffer can ignore the memory side |
| N05 | B/GameplayKit/GKComponentSystem.m:22-30, 44-46 | `-updateWithDeltaTime:`, `-didAddToEntity`, `-willRemoveFromEntity`, `-encodeWithCoder:` | empty | updates each component with the time step; the entity hooks; archives the components (GKComponentSystem) | no | E | S | loop over the components and call their update |
| N06 | B/AppIntents/Spotlight.swift:150-156 | `NSUserActivity.appEntityIdentifier` | gated `@available(iOS 8.0, *)` at :150, so hidden from iOS 6 | the entity identifier an app attaches to an activity (NSUserActivity, appEntityIdentifier) | no (0 files) | A | S | lower the gate to the backport's floor and keep the value in the activity's userInfo |
| N07 | docs/explanation/webkit/network.md:39 | doc claim: iOS 6 "has no root store" for OpenSSL, so its verification stays off | the same paragraph says SecTrust checks against the system store | say what SecTrust reads, and why OpenSSL stays off | n/a (WebKit path) | D | S | correct the paragraph; no code change |
| N08 | B/Metal/RevenantMetalDevice.m:88-95 | `-supportsFeatureSet:`, `-supportsFamily:` | NO | YES for each feature set and GPU family the device has (MTLDevice, supportsFamily:) | vendored ffmpeg only (pass 1), not the app | H | S | keep; the GLES 2 hardware (SGX543) has no Metal family, so YES would be false |
| N09 | B/PassKit/PKPaymentAuthorizationController10.m:11-25; B/PassKit/PKPaymentAuthorizationViewController8.m:11-14 | `+canMakePayments`, `+canMakePaymentsUsingNetworks:` (both overloads) | NO | YES when the device can pay with cards (PKPaymentAuthorizationController) | no; submodules/AppLock/Sources/AppLock.swift:265, 290 test the class only; payments in submodules/InAppPurchaseManager use the StoreKit queue | H | S | keep; no NFC secure element on A5 devices |
| N10 | B/CoreMotion/CMPedometer.m:40-54; B/CoreMotion/CMAltimeter.m:20-22 | `-queryPedometerDataFromDate:...`, `-startPedometerUpdatesFromDate:...`, `-startPedometerEventUpdatesWithHandler:`, `-startRelativeAltitudeUpdatesToQueue:withHandler:` | empty; the handler is never called, so the caller waits | calls the handler with data or an error (CoreMotion, CMPedometer) | no (0 files for both) | E | S | call the handler once with an error that says the hardware is absent; steps from the accelerometer would be a separate L item |
| N11 | B/UIKit/UIPointerInteraction.m:44-49; B/UIKit/UIPreviewInteraction.m:32; B/UIKit/UIScribbleInteraction.m:11, 33, 43, 79, 89 | `-invalidate`, `-willMoveToView:`, `-cancelInteraction`, `+isPencilInputExpected`, `-isHandlingWriting` | empty bodies and NO | pointer, Force Touch and Scribble hardware features (UIPointerInteraction, UIPreviewInteraction, UIScribbleInteraction) | no (UIPointerInteraction is commented out in Telegram) | H | S | keep: no pointer, no pressure sensor, no Apple Pencil on A5 |
| N12 | B/SceneKit/SCNView.m:584-592 | `-debugOptions`, `-setDebugOptions:` | stored; nothing draws | draws the chosen debug overlays (SCNView, SCNDebugOptions) | no (0 files) | E | M | draw the wireframe and statistics in the GLES pass |
| N13 | B/SceneKit/SCNView.m:605-615 | `-usesReverseZ` | always NO; setting YES says once | reverse-Z depth (SCNView, usesReverseZ) | no | S | M | OpenGL ES 2.0 has no clip control; a projection and a greater depth test reproduce it (verify on device) |
| N14 | B/SceneKit/SCNView.m:466-474 | `-sceneTime`, `-setSceneTime:` | the scene clock read at wall time (approximation, C18) | the scene's time, which stops when paused (SCNView, sceneTime) | no (0 files) | C | M | stop the clock on pause; C18 stays open |
| N15 | B/UIKit/UIView+iOS13.m:32-40 | `+modifyAnimationsWithRepeatCount:autoreverses:animations:` | sets a global repeat count and autoreverse that outlives the block; say-once | applies the repeat count only to the animations in the block (UIView, iOS 13) | no (0 files) | S | M | scope the count to the animations the block adds |
| N16 | B/AVFoundation/AVAudioUnit.m:46-50 | `-loadAudioUnitPresetAtURL:error:` | returns NO with `kAudio_UnimplementedError` (NSOSStatusErrorDomain) | loads a preset file into the unit (AVAudioUnit) | no (0 files) | F | M | read the preset and apply its parameters; the error is invented |
| N17 | B/Network/NWListener.swift:40-41; B/Network/NWConnection.swift:133 | `NWListener` start; `NWConnection` server side | ENOTSUP when TLS has no server identity | the TLS error the identity check reports (Network, NWListener); the exact error is not verified | no; submodules/TelegramCore/Sources/Network/NetworkFrameworkTcpConnectionInterface.swift:140-147 uses `NWParameters(tls: nil)` | F | M | server-side SecureTransport on iOS 6 takes an identity; ENOTSUP is invented |
| N18 | B/Metal/RevenantMetalDrawable.m:49-57 | `-presentAtTime:`, `-presentAfterMinimumDuration:` | present now; the time is ignored | present at the time, and not before the minimum duration (MTLDrawable) | no (presentAtTime is not used) | E | M | schedule the present on a display link at the time |
| N19 | B/UIKit/UIContextMenuInteraction.m:19, 233; B/UIKit/UIControl+Menus14.m:167-186 | `previewViewController` (nil); `willMoveToView:` (empty); the delegate callbacks (nil or empty) | no menu is ever presented | presents the context menu and its preview (UIContextMenuInteraction, iOS 13) | no (prototype doc only) | C | L | depends on UIMenu, which is another worker's (UIMenuElement is skipped by the brief) |
| N20 | B/UIKit/UIEditMenuInteraction.m:26, 42, 46, 50; B/UIKit/UITextView+EditMenu16.m:10, 14; B/UIKit/UITextField+EditMenu16.m:10, 14 | `dismissMenu`, `reloadVisibleMenu`, `updateVisibleMenuPositionAnimated:`, the will-present and will-dismiss callbacks | empty; no menu appears | shows the edit menu over the text (UIEditMenuInteraction, iOS 16) | no (docs only) | E | L | depends on UIMenu (skipped by the brief) |
| N21 | B/UIKit/UIFieldBehavior.m:528-537 | `-childBehaviors` (empty array); `-addChildBehavior:`, `-removeChildBehavior:` | empty | field behaviours with child behaviours (UIFieldBehavior, iOS 9) | no (0 files) | C | L | needs a dynamics engine behind the behaviour |
| N22 | B/SceneKit/SCNPhysicsWorld.m:83-103 | ray and contact tests (empty arrays); `-updateCollisionPairs` (empty) | no hits and no contacts | ray and contact tests over the bodies (SCNPhysicsWorld) | no (0 files) | C | L | a physics engine behind the bodies |
| N23 | B/ReplayKit/RPScreenRecorder.m:24, 34, 45 | `-isRecording` (NO); `-cameraPreviewView` (nil); `-discardRecordingWithHandler:` (empty) | never records | records the screen (ReplayKit, RPScreenRecorder, iOS 9) | no (0 files) | C | L | capture the GLES frames of the app; this is a recorder, not a stub |
| N24 | B/BackgroundTasks/BGTaskScheduler.m:66-75 | `-submitTaskRequest:error:` | always NO, with NotPermitted or Unavailable | queues the task for the system to run later (BGTaskScheduler, iOS 13) | no (plist keys only) | F | L | iOS 6 has no scheduler to queue into; the codes are honest. The cancel methods at :77-83 are consistent with nothing stored |
| N25 | B/SceneKit/SCNView.m:594-603, 646-650 | `-overlaySKScene`, `-setOverlaySKScene:`, `-audioEnvironmentNode` | raise through `revenant_unsupported` | the SpriteKit overlay and the 3D audio environment (SCNView) | no (0 files) | F | L | the overlay needs SpriteKit (an iOS 7 API); the audio node needs a 3D mixer. docs/explanation/backports-open-members.md:359 lists them |

## Hardware claims (H and D)

| Claim | Where | A5 hardware | Verdict |
|---|---|---|---|
| Apple Pencil double-tap; Scribble | T06 (B/UIKit/UIPencilInteraction12.m:10-18); N11 (B/UIKit/UIScribbleInteraction.m) | none | honest; not reproducible |
| Pointer and hover | T05 (B/UIKit/UIHoverGestureRecognizer.m:11-21); N11 (B/UIKit/UIPointerInteraction.m:44-49) | none (touch only) | honest; not reproducible |
| Force Touch (3D Touch) | N11 (B/UIKit/UIPreviewInteraction.m:32) | no pressure sensor | honest |
| Scroll wheel, trackpad | T04 (B/UIKit/UIPanGestureRecognizer+ScrollTypes134.m) | none | honest; the touch pan must still work |
| Motion coprocessor (activity) | T08 (B/CoreMotion/CMMotionActivityManager.m:5-7) | M7 absent | honest NO |
| Barometer (altimeter) | N10 (B/CoreMotion/CMAltimeter.m:5-7) | absent | honest NO; the handler must still answer |
| Pedometer | N10 (B/CoreMotion/CMPedometer.m:40-54) | M7 absent | the handler must answer; steps from the accelerometer would be an L item |
| Two cameras at once | T09 (B/AVFoundation/AVCaptureMultiCamSession13.m:5-12) | Apple's requirement is newer hardware | honest NO |
| NFC | B/CoreNFC/NFCReaderSession.m:92-94 (`NFCNDEFReaderSession`; body not read) | no NFC on A5 | honest; body not checked |
| ARKit | B/ARKit/ARSession.m:66-97 (body not read) | ARKit needs newer hardware | honest; body not checked |
| Metal GPU families | N08 (B/Metal/RevenantMetalDevice.m:88-95) | GLES 2 only (SGX543) | honest NO |
| Touch ID | T24 (B/LocalAuthentication/LAContext.m:61-66, policy 1) | no Touch ID | honest; the passcode half is F |
| PassKit payments | N09 (B/PassKit/PKPaymentAuthorizationController10.m:11-25) | no NFC secure element | honest NO |
| HEVC and AV1 hardware decode | T22; docs/explanation/backports-open-members.md:114 (D) | no hardware decoder for them | the NO is true; the doc's "no by design" is the gap, since a software decoder reproduces playback |
| Keyboard shortcut bar | T10 | partly: the iPad hardware keyboard | not hardware for the software keyboard (verify on iPad) |

A grep of `docs/` for hardware-limit phrases ("hardware limit", "iOS 6 lacks", "not available on iOS 6", "no hardware", "A5 has no") found one such claim, at `docs/explanation/backports-open-members.md:114`. The wider `hardware` grep was not read in full.

## Swift and overlay gates

| Where | Gate | Member hidden from iOS 6 | Telegram | Verdict |
|---|---|---|---|---|
| B/StoreKit/AppStore.swift:5 | iOS 15.0 | `AppStore.showManageSubscriptions(in:)` | yes, submodules/TelegramUI/Sources/AppDelegate.swift:939 | gap, T03 |
| B/AppIntents/Spotlight.swift:150 | iOS 8.0 | `NSUserActivity.appEntityIdentifier` | no | gap, N06 |
| O/Foundation/PresentationIntent.swift:239, 281, 314, 336 | iOS 15.0, macOS 12.0 | four PresentationIntent members | yes, submodules/BrowserUI/Sources/BrowserMarkdown.swift:8-9 | gap, T30 |
| B/RealityKit/ARView.swift:148, 177 | unavailable | `init?(coder:)` with a fatal error | no | not verified (below) |
| B/AppIntents/Entity.swift:148 | unavailable | transient entity, made by the app | no | by design; no gap |
| B/Network/NWProtocolTLS.swift:123 | macOS 10.12 | nothing on iOS | no | no effect on iOS 6 |
| B/Spatial/*.swift (16 lines) | deprecated | none hidden | no | no gap |

The 22 Swift `@available` lines in `B/` are the 22 above (AppStore 1, Entity 1, NWProtocolTLS 1, Spotlight 1, ARView 2, Spatial 16). The overlay has 4.

## Refusals (F rows)

Every row here refuses or raises. The list gives the error each one returns.

- T21 alternate icon: `NSFeatureUnsupportedError` (NSCocoaErrorDomain), set, nil and NO for the rest.
- T23 Sign in with Apple: `revenant_error` in the completion, by design.
- T24 LAContext: `LAErrorNotInteractive` (policy 2, invented text), `LAErrorBiometryNotAvailable` (policy 1), and a raise for any other policy.
- T25 `VNRecognizeTextRequest` and T26 `VNClassifyImageRequest`: `VNErrorUnsupportedRequest`.
- T27 speech: `initWithLocale:` returns nil; `requestAuthorization:` answers Restricted.
- T09 `AVCaptureMultiCamSession` init: raises `NSInternalInconsistencyException` (H).
- N16 `loadAudioUnitPresetAtURL:error:`: `kAudio_UnimplementedError`.
- N17 NWListener and NWConnection: `ENOTSUP`.
- N24 `BGTaskScheduler submitTaskRequest:error:`: `NotPermitted` or `Unavailable`.
- N25 `overlaySKScene`, `setOverlaySKScene:` and `audioEnvironmentNode`: raise through `revenant_unsupported`.

The refusals in `B/Security` (SecAccessControl, SecKey, SharedWebCredentials) are skipped by the brief and are not in this table.

## Reviewed, not findings

- `B/Foundation/NSUUID.m:60-63`: the base `UUIDString` returns @"". It is unreachable, because `+allocWithZone:` (`NSUUID.m:33-38`) routes every `NSUUID` to `__NSConcreteUUID`.
- `B/Contacts/CNChangeHistoryEvent13.m`: the base visitor and encoder are empty, and that is an abstract base. The subclasses implement them.
- `B/AVKit/AVPictureInPictureController.m:60-63`: `+isPictureInPictureSupported` answers YES because the in-app picture-in-picture window is implemented (pan, double-tap close). The honest limit is that there is no system-wide picture-in-picture.
- `B/Metal/RevenantMetalDrawable.m:37-47` (`present`) is real. The `endEncoding` no-ops in `MTLComputeCommandEncoder8.m` and `MTLBlitCommandEncoder8.m` are correct, because the GLES dispatch runs synchronously (`MTLComputeCommandEncoder8.m:153-176`).
- `B/UIKit/UIFeedbackGenerator.m:44-46`: `prepare` is empty, and that is a hint. The impact and notification generators are implemented.
- `B/BackgroundTasks/BGTaskScheduler.m:77-83`: the cancel methods are empty, which is consistent with nothing being stored.
- `B/AVFoundation/AVAudioUnit.m:53-54`: the base `revenant_applyPendingParameters` is empty; the effect class at `:83-85` overrides it.
- `B/Metal/RevenantMetalDevice.m:68-86`: `isLowPower`, `isHeadless`, `isRemovable` and `hasUnifiedMemory` are fixed per hardware. `supportsTextureSampleCount:` is computed.
- `B/Photos/PHChange8.m`: insertions, removals and changes are implemented. Only the moves are not (T13).
- `B/Contacts/CNChangeHistory*`: the visitor dispatch is implemented.
- The `willMoveToView:` and `traitCollectionDidChange:` hooks, and the `UIPresentationController` hooks, are empty defaults.
- Metal debug markers and optimisation hints are no-ops with no observable effect.
- Telegram's own gates: `VNRecognizeTextRequest` sits behind `#available(iOS 13.0)` (`ImageContentAnalysis.swift:307`), and `VNDetectRectanglesRequest` behind `@available(iOS 11.0)` (`PGRectangleDetector.m:306-310`). The rectangle request is implemented (`B/Vision/VNHandlers.m:170, 280`), so it is not a finding.
- `accessibilityIgnoresInvertColors` (24 Telegram files): iOS 6 has no Smart Invert, so no effect is the true answer. Its body was not read.

## Not verified

- The constant scan covers 1172 rows (903 constant, 269 empty). The rows in this table were read individually. The remaining 235 non-UIKit, non-AV, non-Metal constants (`rest.txt` in scratch) were not classified one by one.
- `O/RealityKit`: `ARView.swift:148, 177` mark `init?(coder:)` unavailable with a fatal error. Whether Apple's `ARView` has that initialiser is not checked.
- `B/UniformTypeIdentifiers/UTType.swift:328-335`: `encode(to:)` writes the identifier string, and `decode` accepts either form. An earlier pass recorded that the SDK writes an object with an internal index, but the claim could not be found in `docs/` or `frameworks/Backports/` (a grep for "internal index" returned nothing). Check the SDK's encoding before changing either side.
- NSTextContentManager15.m (TextKit 2, partly stubbed) was not read in this pass. Telegram's `ChatInputTextNode.swift:32` uses an `NSTextLayoutManager` subclass, and that path is gated to iOS 16 (pass 1).
- `B/Metal/MTLBlitCommandEncoder8.m:60, 65, 80, 125, 129`: NSLog refusals for texture channel counts, region sizes, pixel formats and array slices. They were read in pass 1 and not classified.
- `B/ARKit/ARSession.m:66-97` and `B/CoreNFC/NFCReaderSession.m:92-94`: the verdict is hardware, but the bodies were not read in this pass.
- `B/CoreMotion/CMMotionActivityManager.m` and `CMAltimeter.m`: only the availability constants were read. The handlers are not checked, except that `CMPedometer` and `CMAltimeter` were read as empty.
- Telegram use was matched on the selector or class name. Guards around the call were read only where the table says so.
- `B/Network/NWPathMonitor.swift`: read in pass 1 only.
- The Telegram `supportsFamily` call (N08) is in vendored ffmpeg, from pass 1, not the app.
- Telegram's `AVCaptureSession` audio-session setter: the YES path was not checked against Telegram.
- Every device-only item (haptics, LAContext, CoreMotion, Speech, Vision, the picture-in-picture window) is untested on hardware.

## Skipped by brief

- SecAccessControl (`B/Security/SecAccessControl8.m:13-14`).
- SecKeyCopyExternalRepresentation (`B/Security/SecKey100.m:198-212`, errSecUnimplemented at :208).
- Shared web credentials (`B/Security/SharedWebCredentials8.m:15-16`).
- Secure Enclave.
- The os_log fallback.
- UIMenuElement. Its skip is why N19 and N20 depend on another worker's work.
- WebKit document-start work.

## Say-once call sites

Each call site of `revenant_say_once_for`, `revenant_menus_say_once` or `revenant_say_once`, with the first string literal on its line. That literal is the key, unless the line builds the key or passes it in; where the line has no literal, the cell reads `(no literal)`. The three helper definitions are left out.

| Call site | First string literal on the line |
|---|---|
| frameworks/Backports/src/AVFoundation/AVCaptureConnection+CameraIntrinsics11.m:20 | @"AVCaptureConnection.cameraIntrinsicMatrixDeliveryEnabled" |
| frameworks/Backports/src/AVFoundation/AVCaptureSession+ApplicationAudioSession7.m:24 | (no literal) |
| frameworks/Backports/src/AVFoundation/AVCaptureSession+ApplicationAudioSession7.m:35 | (no literal) |
| frameworks/Backports/src/Accessibility/RevenantBrailleMap.m:50 | @"AXBrailleMap.presentImage" |
| frameworks/Backports/src/Accessibility/RevenantChartDescriptors.m:629 | @"AXLiveAudioGraph.start" |
| frameworks/Backports/src/Accessibility/RevenantChartDescriptors.m:636 | @"AXLiveAudioGraph.updateValue" |
| frameworks/Backports/src/Accessibility/RevenantChartDescriptors.m:643 | @"AXLiveAudioGraph.stop" |
| frameworks/Backports/src/HealthKit/RevenantHKStore.m:18 | (no literal) |
| frameworks/Backports/src/JavaScriptCore/JSCAPI18.m:9 | @"JavaScriptCore.JSGlobalContextSetInspectable" |
| frameworks/Backports/src/JavaScriptCore/JSCAPI8.m:18 | @"JavaScriptCore.JSGlobalContextCopyName" |
| frameworks/Backports/src/JavaScriptCore/JSCAPI8.m:9 | @"JavaScriptCore.JSGlobalContextSetName" |
| frameworks/Backports/src/MessageUI/MFMailComposeViewController11.m:14 | @"MFMailComposeViewController.insertCollaborationItemProvider:completionHandler:" |
| frameworks/Backports/src/MessageUI/MFMessageComposeViewController7.m:111 | @"MFMessageComposeViewController.insertCollaborationItemProvider:" |
| frameworks/Backports/src/NotificationCenter/NCWidgetController.m:22 | @"NCWidgetController.setHasContent:forWidgetWithBundleIdentifier:" |
| frameworks/Backports/src/OpenGLES/EAGLContextMultiThreaded.m:103 | @"EAGLContext.multiThreaded" |
| frameworks/Backports/src/ReplayKit/RPScreenRecorder.m:18 | @"ReplayKit.RPScreenRecorder.available" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:190 | @"scenekit member speed" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:191 | @"scenekit member timeOffset" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:192 | @"scenekit member repeatDuration" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:194 | @"scenekit member fillMode" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:198 | @"scenekit member cumulative" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:199 | @"scenekit member valueFunction" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:203 | @"scenekit member group child duration" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:212 | @"scenekit animation class" |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:324 | @"scenekit animation " |
| frameworks/Backports/src/SceneKit/RevenantSCNAnimation.m:331 | @"scenekit keypath " |
| frameworks/Backports/src/SceneKit/RevenantSCNRenderer.m:1008 | @"scenekit %p %@" |
| frameworks/Backports/src/SceneKit/RevenantSCNRenderer.m:1285 | @"scenekit lights %p" |
| frameworks/Backports/src/SceneKit/RevenantSCNRenderer.m:734 | @"linear textures" |
| frameworks/Backports/src/SceneKit/SCNPhysicsWorld.m:6 | @"SCNPhysicsWorld" |
| frameworks/Backports/src/SceneKit/SCNView.m:150 | @"scenekit drawable" |
| frameworks/Backports/src/SceneKit/SCNView.m:613 | @"scenekit reverse z" |
| frameworks/Backports/src/SceneKit/SCNView.m:87 | @"scenekit no context" |
| frameworks/Backports/src/UIKit/NSLayoutManager+Text13.m:18 | @"default-hyphenation" |
| frameworks/Backports/src/UIKit/NSLayoutManager+Text7.m:102 | @"glyph-font-substitution" |
| frameworks/Backports/src/UIKit/NSParagraphStyle+Text15.m:14 | @"default-hyphenation" |
| frameworks/Backports/src/UIKit/RevenantBarAppearance.m:208 | (no literal) |
| frameworks/Backports/src/UIKit/UIAccessibility13.m:34 | @"voice-control" |
| frameworks/Backports/src/UIKit/UIApplication+Scenes.m:57 | @"scene-refresh" |
| frameworks/Backports/src/UIKit/UIApplication+Scenes.m:6 | (no literal) |
| frameworks/Backports/src/UIKit/UICollectionView+SelectionFocus14.m:17 | @"collection-selection-follows-focus" |
| frameworks/Backports/src/UIKit/UIContextMenuInteraction.m:286 | @"sheet" |
| frameworks/Backports/src/UIKit/UIEditMenuInteraction.m:34 | @"edit-menu" |
| frameworks/Backports/src/UIKit/UIEditMenuInteraction.m:39 | @"edit-menu-present" |
| frameworks/Backports/src/UIKit/UIFontPickerViewController.m:152 | @"font-picker" |
| frameworks/Backports/src/UIKit/UIHoverGestureRecognizer.m:14 | @"hover-recognizer" |
| frameworks/Backports/src/UIKit/UIImage+Symbols.m:27 | @"symbol" |
| frameworks/Backports/src/UIKit/UILabel+LineBreakStrategy14.m:19 | @"line-break-strategy" |
| frameworks/Backports/src/UIKit/UILabel+Tightening9.m:16 | @"label-tightening" |
| frameworks/Backports/src/UIKit/UIMenuSystem.m:41 | @"rebuild" |
| frameworks/Backports/src/UIKit/UIMenuSystem.m:47 | @"revalidate" |
| frameworks/Backports/src/UIKit/UINavigationItem+Groups16.m:30 | @"navigation-item-16" |
| frameworks/Backports/src/UIKit/UIPanGestureRecognizer+ScrollTypes134.m:18 | @"scroll-types" |
| frameworks/Backports/src/UIKit/UIPencilInteraction12.m:60 | @"pencil" |
| frameworks/Backports/src/UIKit/UIPointerInteraction.m:56 | @"pointer-interaction" |
| frameworks/Backports/src/UIKit/UIPointerLockState.m:55 | @"pointer-lock" |
| frameworks/Backports/src/UIKit/UIPrintInteractionController+Options7.m:21 | @"print-copies" |
| frameworks/Backports/src/UIKit/UIPrintInteractionController+Options7.m:33 | @"print-paper" |
| frameworks/Backports/src/UIKit/UIResponder+ItemsConfiguration.m:16 | @"items-configuration" |
| frameworks/Backports/src/UIKit/UIScreenshotService.m:28 | @"screenshot-service" |
| frameworks/Backports/src/UIKit/UIScribbleInteraction.m:51 | @"scribble" |
| frameworks/Backports/src/UIKit/UIScribbleInteraction.m:97 | @"indirect-scribble" |
| frameworks/Backports/src/UIKit/UISimpleTextPrintFormatter+Attributed7.m:61 | @"print-attributed" |
| frameworks/Backports/src/UIKit/UISplitViewController+PrimaryEdge11.m:18 | @"split-primary-edge" |
| frameworks/Backports/src/UIKit/UITabBar+Layout7.m:14 | @"tabbar-layout" |
| frameworks/Backports/src/UIKit/UITabBar+Tint10.m:20 | @"tabbar-unselected" |
| frameworks/Backports/src/UIKit/UITabBar+Tint10.m:36 | @"tabbaritem-badge" |
| frameworks/Backports/src/UIKit/UITabBar+Tint10.m:48 | @"tabbaritem-badge" |
| frameworks/Backports/src/UIKit/UITableView+SelectionFocus14.m:17 | @"table-selection-follows-focus" |
| frameworks/Backports/src/UIKit/UITableView+Updates11.m:77 | @"table-separator-reference" |
| frameworks/Backports/src/UIKit/UITextFormattingCoordinator.m:41 | @"font-panel" |
| frameworks/Backports/src/UIKit/UITextInputAssistantItem.m:7 | @"input-assistant-groups" |
| frameworks/Backports/src/UIKit/UITextInputTraits11.m:12 | @"%@: the keyboard of iOS 6 makes no smart substitutions, so the value is kept and read back and typing is as before" |
| frameworks/Backports/src/UIKit/UITextInputTraits11.m:51 | @"passwordRules" |
| frameworks/Backports/src/UIKit/UITextView+TextKit7.m:180 | @"textview-link-attributes" |
| frameworks/Backports/src/UIKit/UITextView+TextScaling13.m:18 | @"text-scaling" |
| frameworks/Backports/src/UIKit/UIView+ContentSizeAdjusting.m:11 | @"content-size-adjusting" |
| frameworks/Backports/src/UIKit/UIView+FocusGroup14.m:18 | @"focus-group" |
| frameworks/Backports/src/UIKit/UIView+InvertColors.m:16 | @"invert-colors" |
| frameworks/Backports/src/UIKit/UIView+iOS13.m:18 | @"dark-override" |
| frameworks/Backports/src/UIKit/UIView+iOS13.m:34 | @"modify-animations" |
| frameworks/Backports/src/UIKit/UIViewController+Previewing.m:8 | @"previewing" |
| frameworks/Backports/src/UIKit/UIViewController+iOS13.m:22 | @"dark-override" |
| frameworks/Backports/src/UIKit/UNLocationNotificationTrigger10.m:146 | @"region" |
| frameworks/Backports/src/UIKit/UNUserNotificationCenter.m:218 | (no literal) |
| frameworks/Backports/src/UIKit/UNUserNotificationCenter.m:324 | @"title" |
| frameworks/Backports/src/UIKit/UNUserNotificationCenter.m:326 | @"category" |
| frameworks/Backports/src/UIKit/UNUserNotificationCenter.m:516 | @"categories" |
| frameworks/Backports/src/UIKit/UNUserNotificationCenter.m:599 | @"present" |
