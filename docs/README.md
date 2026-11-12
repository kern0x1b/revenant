# Documentation

The documents of revenant, by kind ([Diátaxis](https://diataxis.fr)): tutorials learn by doing, guides do one task, references are facts to look up, and explanations say why. Under each kind, a component's documents sit in its own folder; the documents about the whole repository sit directly under their kind.

## Repository-wide

| Document | About |
| --- | --- |
| [What revenant is for](explanation/platform.md) | the platform, its first targets and its limits |
| [Architecture](explanation/architecture.md) | the three layers, what each top-level folder is, and how an app built outside gets our libraries |
| [Decisions](explanation/decisions/README.md) | the architecture decisions, each with the check that enforces it |
| [Loading the backports](explanation/backports-loading.md) | how the backport libraries are loaded |
| [Vision text recognition on iOS 6](explanation/backports/vision-text.md) | `VNRecognizeTextRequest` on Tesseract: the languages, the differences from Vision, the measurements, and the packaging |
| [Open Backports members](explanation/backports-open-members.md) | the larger framework members that remain open |
| [Backports gaps](explanation/backports-gaps.md) | the implemented members that do not do what the real API does, by Telegram use and size |
| [Photos over AssetsLibrary](explanation/backports/photos-over-assetslibrary.md) | Telegram 13.0.0's Photos use against the AssetsLibrary-backed backport, and the status of each gap |
| [The Network framework surface Telegram 13.0.0 uses](explanation/backports/network-framework-surface.md) | the `Network` members Telegram calls, what the backport must answer, and why Reachability cannot find `NWPathMonitor` yet |
| [Google reCAPTCHA Enterprise SDK on iOS 6](explanation/recaptcha-sdk-on-ios6.md) | whether Google's original SDK can run on iOS 6: its measured imports and gates, what revenant already provides, the variants with their blockers, and the decisions for the owner |
| [The reCAPTCHA SDK work split](explanation/recaptcha-work-split.md) | the remaining work on the SDK as parallel blocks: how to build the arm64 guest runtime, and for each block its goal, measurable criterion, code and test |
| [What iOS 6.1.3 can reach over TLS](explanation/backports/tls-reach-ios-6.md) | the firmware's SecureTransport versions and ciphers, the hosts it reaches, and the proposed BoringSSL fix |
| [Metal on iOS 6](explanation/backports/metal-on-ios6.md) | the Metal render path and the fragment-pass compute that ship in v1 through air2es, the driver-level backlog for v2, the device findings, and the licence rules for both |
| [Nested frameworks in the lowered overlay](explanation/backports/lowered-nested-frameworks.md) | why the overlay copies the headers of a framework nested in a mapped framework, such as MPSCore in MetalPerformanceShaders |
| [The surfaces an app reaches at the iOS 6 floor](explanation/backports/floor-surfaces.md) | the names Telegram 13.0.0 reached after the first three (AVAudioPlayer with a file type hint, UIMenu with a subtitle, PHImageContentMode.default): what each does on iOS 6.1.3, the Swift overlays that carry them, and what is not drawn, measured or provided |
| [Shadowed classes: a system class that a proxy completes](explanation/backports/shadowed-classes.md) | the generated `shadowed-classes.txt` list: which iOS 6 system classes a proxy outruns (CASpringAnimation), the format, the criterion, and the rebind a consumer applies to their imports |
| [What the lowering takes as implemented](explanation/backports/lowered-implemented-names.md) | how a name reaches the lowered member list through `BACKPORT_IMPL`, which definitions the line scan misses, the Swift overlay modules (`UniformTypeIdentifiers`, `IOSurface`, `SceneKit`, `Vision`, `CoreML`) that a consumer must put on its search path, and why a name the release exports is lowered and not backported |
| [AIR from Apple's Metal compiler: the metal-toolchain package](explanation/backports/metal-air-prebuilt.md) | the local package that would give AIR for Telegram's shaders, the official download it needs, and what it is blocked on (Xcode) |
| [air2es kernels: the kernel lowering](explanation/backports/air2es-kernels.md) | how a Metal kernel becomes an ES 1.00 fragment pass, its named refusals, the measured Telegram kernel, and what is still open |
| [air2es on iOS Metal sources: per-shader verdicts](explanation/backports/air2es-ios-verdicts.md) | the verdict for each entry point of the measured Metal corpus, the changes measured against it, and the refusal groups still open |
| [enhanceGenerateLUT on ES 2: design](explanation/backports/air2es-enhance-lut-design.md) | how the Telegram enhance kernel that builds the contrast LUT could be expressed as ES 2 passes, what was measured, what is only planned, and why it stays refused until the owner decides |
| [Metal v2: the GPU-driver reverse-engineering landscape](explanation/backports/metal-v2-driver-re-landscape.md) | the methods of Asahi, Mesa, Vita3K and related projects, read for method, and what they change for the SGX543 driver question |
| [The Network framework surface Telegram uses](explanation/backports/network-framework-surface.md) | the Network framework members Telegram 13.0.0 calls and where the backport stands |
| [Photos over AssetsLibrary](explanation/backports/photos-over-assetslibrary.md) | Telegram's use of Photos and where the backport stands |
| [Below the driver: the SGX543 GL path on the iPhone 4S](explanation/backports/below-the-driver.md) | the stack from glDrawElements to the kernel, the in-process shader compiler, whether Apple's compiled shaders are reachable, and the ranked options below the driver |
| [From a clean clone](guides/getting-started.md) | the steps from a clone to a green test run and a built Backports library |
| [The machine: one cache, one clean](guides/machine.md) | where the build keeps its cache, and how to give it back |
| [Prebuilt packages](guides/prebuilt.md) | packages built elsewhere, and how to use them |
| [Proving code unused](guides/unused-code.md) | the ways code is reached besides its name, and how to check a removal for them |

## Toolchain

| Document | About |
| --- | --- |
| [Write a port](tutorials/toolchain/port.md) | a tutorial: an xmake project from an empty directory to a `.deb` |
| [Checks and waivers](guides/toolchain/checks.md) | the checks a port runs, the waivers it states, and the release's libraries |
| [Rebind a prebuilt image's imports](guides/toolchain/rebind.md) | `revenant.rebind`: moving a prebuilt armv7 image's imports to the Backports library that exports them, its limits, and the lines for Classicgram |
| [Carry a framework and order the Backports](guides/toolchain/frameworks-and-link-order.md) | a framework from a package in the bundle, and the Backports libraries before the Swift runtime in an application's link line |
| [Run a port on an emulated device](guides/toolchain/emulate.md) | the emulator, for a port |
| [Build a Rust crate for iOS 6](guides/toolchain/rust.md) | a Rust staticlib for armv7 on iOS 6.0, built by the `rust` rule |
| [Build libsql for iOS 6](guides/toolchain/libsql.md) | the libsql package for armv7 iOS 6.0: its Rust build with the pinned nightly, the link checks and the test |
| [Write a package](guides/toolchain/packages.md) | a package in the repository's package store |
| [Swift C++ interoperability on iOS 6](guides/toolchain/swift-cxx-interop.md) | the armv7 iOS 6.0 interop mode against the bundled libc++, and the thread-local and std checks |
| [Working on the toolchain](guides/toolchain/contributing.md) | the contributor guide |
| [The toolchain's tests](reference/toolchain/tests.md) | the suites, and what runs where |
| [Rules, values and checks](reference/toolchain/rules.md) | the target rules and the values each one reads |
| [Commands](reference/toolchain/commands.md) | the xmake commands and the environment |
| [Packages](reference/toolchain/packages.md) | the packages and their versions |
| [ld64](reference/toolchain/ld64.md) | the linker package: Apple's ld64 from cctools-port, its patches and why the port needs it |
| [Tools](reference/toolchain/tools.md) | the developer tools |
| [Optimisation measurements](reference/toolchain/optimisation.md) | the prototypes' numbers: emulator instructions, page misses and text size, and the codegen reproducers |
| [Third-party code](reference/toolchain/third-party.md) | the third-party code, and where each piece stands |
| [Guest memory](reference/toolchain/guest-memory.md) | the helper that reads a task's virtual, resident and peak size, and what the emulator answers for it |
| [Device codegen](reference/toolchain/codegen.md) | what the toolchain sets for the device's code generation, what was measured on the bench workloads, and what is held |
| [Why the toolchain is built this way](explanation/toolchain/design.md) | the design and its decisions |
| [Runtimes and backports](explanation/toolchain/runtimes.md) | why the runtimes and backports are built as they are |
| [The os_log fallback](explanation/toolchain/os-log.md) | how a message prints without the Backports runtime: the buffer layout, the privacy rules, and what is still provisional |
| [Rust on iOS 6](explanation/toolchain/rust.md) | the armv7 target, the pinned nightly, what iOS 6 lacks for std, and the 10.0 minimum in the objects |
| [libsql on iOS 6](explanation/toolchain/libsql.md) | why libsql builds the way it does for armv7 iOS 6.0: its shims, its imports and its limits |
| [Optimisation beyond flags](explanation/toolchain/optimisation.md) | the ranked candidates for the A5 that the flags do not reach: PGO, order files, LLVM codegen, launch cost |

## Emulator

| Document | About |
| --- | --- |
| [Build, run and test](guides/emulator/build-and-test.md) | requirements, options, boot and usage |
| [Contributor guide](guides/emulator/contributing.md) | the layout, what bites, the conventions |
| [How it works](explanation/emulator/how-it-works.md) | what is emulated and how the pieces fit |
| [Where the time goes](explanation/emulator/performance.md) | why the emulator is as slow as it is, and why not another emulator |
| [Snapshot and restore](explanation/emulator/snapshot.md) | what a booted machine holds, what a snapshot would save and restore, and the measured costs |
| [Performance measurements](reference/emulator/performance.md) | the measured runs and the counters of a boot |
| [Shared translation](explanation/emulator/shared-translation.md) | the design for translating the shared cache once |
| [Guest memory under parallel execution](explanation/emulator/memory-model.md) | the design for two-core guests to use the page tables, the exclusive monitor, and what is still open |
| [Load average and interface records](explanation/emulator/load-average-and-link-sysctl.md) | the `vm.loadavg` and `net.link.generic` answers, and what is not modelled |
| [Directory attribute listing](explanation/emulator/directory-attributes.md) | `getdirentriesattr`: what is matched to XNU, and what is not |
| [iOS 6.1.3](explanation/emulator/ios-6.1.3.md) | what kept 6.1.3 from booting, and what fixed it |
| [Control surface](reference/emulator/control-surface.md) | the `--control-stdin` commands and the log lines |
| [Fatal-fault report](reference/emulator/fault-report.md) | the fields of the fatal line and the fault words, and how their addresses are named |
| [Guest tests](reference/emulator/guest-tests.md) | the guest programs that check what only a running guest shows |
| [Graphics](reference/emulator/graphics.md) | the shader limits, the Vulkan driver path and the Core Image path |
| [Third-party](reference/emulator/third-party.md) | what is bundled or linked, and under which license |
| [Notice](reference/emulator/notice.md) | the notices to ship with a binary |

## Combine

| Document | About |
| --- | --- |
| [Use Combine](guides/combine/usage.md) | a short example |
| [Build and test](guides/combine/build-and-test.md) | the targets, the test daemon and the emulator |
| [Contributor guide](guides/combine/contributing.md) | the layout, the design, the rules and the traps |
| [How it works](explanation/combine/how-it-works.md) | how OpenCombine is pinned, patched and built as one module |
| [Features](reference/combine/features.md) | what the module provides, and what it adds to OpenCombine |
| [Package](reference/combine/package.md) | the package for the port's armv7 releases |
| [The layer of our own, and what was measured](reference/combine/combine-kit.md) | the record of the package's own layer |
| [Test results](reference/combine/test-results.md) | the upstream suite's results on iOS 6.1.3 and the known limits |
| [Third-party notice](reference/combine/third-party.md) | OpenCombine's MIT notice, which covers the code this module is built from |

## SwiftUI

| Document | About |
| --- | --- |
| [Build, run and test](guides/swiftui/build-and-test.md) | requirements, the build, the tools and the emulator |
| [Contributor guide](guides/swiftui/contributing.md) | the layout, the rules that matter, the test limits |
| [On a phone](guides/swiftui/on-device.md) | the demo's screens, drawn on an iPhone 4S |
| [How it works](explanation/swiftui/how-it-works.md) | why the module is built as it is, and its design |
| [Guest bridge](explanation/swiftui/guest-bridge.md) | the sample app and the slot table of the guest build |
| [Research](explanation/swiftui/research.md) | why Apple's SwiftUI cannot be ported |
| [Features](reference/swiftui/features.md) | the areas of the API that are implemented |
| [Completeness](reference/swiftui/completeness.md) | how much of Apple's interface is present, measured two ways |
| [Ledger](reference/swiftui/ledger.md) | what is implemented, ignored, simplified or missing |
| [Surface](reference/swiftui/surface.md) | the interface walker and the surface files the gaps are read from |
| [Host probes](reference/swiftui/host.md) | values measured from Apple's framework on the host |
| [Builder typechecks](reference/swiftui/typechecks.md) | the snippets the Table and TabContent builders must accept or refuse |
| [Maps](reference/swiftui/maps.md) | the map types and modifiers `expo-maps` takes, and what each does on iOS 6 |
| [Why MapKit](explanation/swiftui/maps.md) | why `Map` is an `MKMapView`, and how content, camera, style and selection reach it |
| [`TextSelection`](reference/swiftui/text-selection.md) | the one range the release can carry |
| [Third-party](reference/swiftui/third-party.md) | the code this module is derived from, and its terms, and the trademarks |

## Backports

| Document | About |
| --- | --- |
| [Demand: the API an app needs](guides/backports/demand.md) | how the demand tool lists what an app references from the SDK, against iOS 6.1.3 and the Backports |
| [Out-of-tree apps: the Backports an app links](guides/backports/out-of-tree.md) | how an app built outside the checkout takes the Backports from its package |
| [Write and install the Backports package](guides/backports/package.md) | the commands that write `org.revenant.backports` and the Swift runtime, and install them on the phone |
| [libSystem compatibility calls](reference/backports/libSystem/README.md) | the missing `clock_getres` and `*at` file operations, host comparisons, iOS 6 timestamp precision and path snapshot limitation |
| [Crutches](reference/backports/crutches.md) | the stand-ins the Backports lowering uses, what each measured, and what removes it |
| [GLSL ES 3.00 to 1.00 translator](reference/react-native/glsl-translator.md) | the glslang and SPIRV-Cross prototype on three.js's ES 3.00 programs: what translates on the host, the armv7 build, and what is still unmeasured |
| [OpenGL ES 3 on iOS 6](reference/backports/opengles-es3.md) | the ES3 entry points on the ES2 driver: what is forwarded, emulated and refused, and why no ES3 EAGL context yet |
| [AVFoundation: QR codes on iOS 6](reference/backports/AVFoundation/README.md) | the metadata output's QR path, what the iOS 6.0 cache shows, and what is still to measure on a device |
| [Photos on iOS 6](reference/backports/Photos/README.md) | the AssetsLibrary-backed PhotoKit surface, cache bound, and unsupported operations |
| [MediaPlayer on iOS 6: the remote command center](reference/backports/MediaPlayer/README.md) | which remote control events reach which command, what iOS 6 never sends, and what the iPhone 4S probe measured |
| [StoreKit on iOS 6: manage subscriptions](reference/backports/StoreKit/README.md) | the overlay over the SDK's module, why the call opens the Settings pane, and what was not measured |
| [Security on iOS 6](reference/backports/Security/README.md) | the access-control rules, Secure Enclave and shared-credential answers measured on macOS, and what the iOS 6 keychain did |
| [UIKit feedback generators on iOS 6](reference/backports/UIKit/FeedbackGenerators.md) | the impact, notification and selection generators as vibration patterns through AudioServices, by motor presence, and what is not measured |
| [CoreHaptics on iOS 6](reference/backports/CoreHaptics/README.md) | the Telegram continuous-haptic surface, its vibration-motor mapping, and what the iPhone 4S measurements could not establish |
| [UserNotifications: attachments on iOS 6](reference/backports/UserNotifications/Attachments.md) | what `UNNotificationAttachment` validates and keeps, and what iOS 6 does not show |
| [UserNotifications: delegate on iOS 6](reference/backports/UserNotifications/Delegate.md) | which delegate calls a local notification makes, what each presentation option does on iOS 6, and the default delegate that lowers the protocol |
| [UserNotifications: authorization on iOS 6](reference/backports/UserNotifications/Authorization.md) | how the status is read from the enabled remote notification types, how a request waits for the prompt, and the limits |
| [ActivityKit](reference/backports/ActivityKit/README.md) | the package `revenant@activitykit` |
| [ActivityKit: availability](reference/backports/ActivityKit/ActivityKit/Availability.md) | the availability of Live Activities, and what the module answers where there is none |
| [ActivityKit: reuse](reference/backports/ActivityKit/ActivityKit/Reuse.md) | what ActivityKit was compared against, and why |
| [ActivityKit: unplaced rows](reference/backports/ActivityKit/ActivityKit/Unplaced.md) | the 10 unplaced rows, and why none is a missing declaration |
| [AppIntents](reference/backports/AppIntents/README.md) | the package `revenant@appintents` |
| [AppIntents: comparators](reference/backports/AppIntents/AppIntents/Comparators.md) | the comparison operators, nine equalities that answered `true` for every pair |
| [AppIntents: counts](reference/backports/AppIntents/AppIntents/Counts.md) | the counts, and the ledger they are measured against |
| [AppIntents: foreground continuation](reference/backports/AppIntents/AppIntents/ForegroundContinuation.md) | the two rows of `ForegroundContinuableIntent`, and why they are not written yet |
| [AppIntents: macros](reference/backports/AppIntents/AppIntents/Macros.md) | the macro rows, and why the expansion cannot be compared on this machine |
| [AppIntents: next family](reference/backports/AppIntents/AppIntents/NextFamily.md) | the census, the pick and the order of the next family |
| [AppIntents: open contracts](reference/backports/AppIntents/AppIntents/Open-contracts.md) | the open rows, and what each one needs |
| [AppIntents: reuse](reference/backports/AppIntents/AppIntents/Reuse.md) | what AppIntents was compared against, and why |
| [AppIntents: services](reference/backports/AppIntents/AppIntents/Services.md) | the seams where the system side of AppIntents is not on these releases |
| [AppIntents: Spotlight](reference/backports/AppIntents/AppIntents/Spotlight.md) | the CoreSpotlight classes AppIntents extends |
| [AppIntents: unplaced rows](reference/backports/AppIntents/AppIntents/Unplaced.md) | the 291 unplaced rows, grouped by type |
| [AppIntentsMacros](reference/backports/AppIntentsMacros/README.md) | the macro plugins of AppIntents and TipKit; the package that would ship them, `revenant@appintents-macros`, does not exist yet |
| [AuthenticationServices: errors](reference/backports/AuthenticationServices/Errors.md) | the error structs, measured |
| [AuthenticationServices: ASCredentialUpdater](reference/backports/AuthenticationServices/CredentialUpdater.md) | the reporting methods on iOS 6, the error they throw, and the dylib a consumer takes |
| [CloudKit: CKError](reference/backports/CloudKit/CKError.md) | `CKError`, measured |
| [CloudKit: CKRecord](reference/backports/CloudKit/CKRecord.md) | `CKRecord`, not yet visible to Swift on armv7 and iOS 6.1.3 |
| [CoreImage: orientation](reference/backports/CoreImage/README.md) | the CGImagePropertyOrientation forms of CIImage on iOS 6, and the EXIF forms the release already has |
| [CoreML](reference/backports/CoreML/README.md) | `MLModel` load and compile in Swift, and the module a consumer builds |
| [CreateML](reference/backports/CreateML/README.md) | CreateML and CreateMLComponents on the port's armv7 releases: what is there, what is not, and the protobuf codec |
| [CreateML: CSV reading](reference/backports/CreateML/TabularData/CSVReading.md) | CSV reading in TabularData, measured, and what is carried |
| [CreateML: CSV writing](reference/backports/CreateML/TabularData/CSVWriting.md) | CSV writing in TabularData, measured, and what is carried |
| [CreateML: date parsing](reference/backports/CreateML/TabularData/DateParsing.md) | date reading in TabularData, measured, and what is carried |
| [Foundation: URL](reference/backports/Foundation/URL.md) | the percent-encoded accessors and the file path initialiser of iOS 16 `URL`, and the host oracle they are measured against |
| [Intents](reference/backports/Intents/README.md) | the responses, message and call intents and resolution results Telegram's extensions name, the Swift module for the key path forms, and what is measured on a device |
| [Metal: dispatchThreads](reference/backports/Metal/DispatchThreads.md) | compute dispatch by threads per grid, the edge group, and the pipeline limits |
| [Metal: linear texture alignment](reference/backports/Metal/LinearTextureAlignment.md) | the row alignment a device reports per pixel format, the padded-row readback fix, and the slice forms of getBytes and replaceRegion |
| [Metal: the background lifecycle](reference/backports/Metal/Lifecycle.md) | why an OpenGL ES context kills the app in the background, the variant table of the device probe, what is restored across the background, and the pixel check on the iPhone 4S |
| [MusicKit](reference/backports/MusicKit/README.md) | MusicKit for a legacy Apple platform |
| [NaturalLanguage](reference/backports/NaturalLanguage/README.md) | the Swift forms of the recognizer, tokenizer, tagger, model and embedding members, and their refined Objective-C names |
| [PassKit](reference/backports/PassKit/README.md) | the `capability3DS`, `capabilityEMV`, `capabilityCredit` and `capabilityDebit` aliases of `PKMerchantCapability` |
| [RealityFoundation: audio](reference/backports/RealityFoundation/Audio.md) | `Audio.swift`: deleted, and what brings it back |
| [RealityFoundation: SceneKit](reference/backports/RealityFoundation/SceneKit.md) | RealityFoundation and RealityKit below iOS 8.0 |
| [SafariServices](reference/backports/SafariServices/README.md) | `SSReadingList` on top of Safari's Reading List, measured on an iPhone 4S |
| [SceneKit](reference/backports/SceneKit/README.md) | the particle system's data model, the Swift module, and what the renderer does not draw |
| [Spatial](reference/backports/Spatial/README.md) | what is built here, and what is measured |
| [Spatial: sources](reference/backports/Spatial/Sources.md) | the files, the Float twin generated from the Double text, and the reasons behind the matrix and geometry code |
| [SwiftData](reference/backports/SwiftData/README.md) | the package `revenant@swift-data` |
| [SwiftData: substrate](reference/backports/SwiftData/Substrate.md) | what the port gives SwiftData, measured |
| [TipKit](reference/backports/TipKit/README.md) | the package `revenant@tipkit` |
| [TipKit: rendering](reference/backports/TipKit/TipKit/Rendering.md) | the seam: the tip is drawn in the app |
| [TipKit: reuse](reference/backports/TipKit/TipKit/Reuse.md) | what TipKit was compared against, and why |
| [UIKit](reference/backports/UIKit/README.md) | the UIKit Swift overlay: the surface's Swift constants and cases |
| [UIKit: CABackdropLayer](reference/backports/UIKit/CABackdropLayer.md) | the private backdrop layer that applications look up by name, and the blur it puts under its view on iOS 6 |
| [UIKit: CASpringAnimation](reference/backports/UIKit/CASpringAnimation.md) | the iOS 9 spring class on iOS 6, its curve and its keyframe delivery |
| [UIKit: keyboard notification for a new input](reference/backports/UIKit/KeyboardInputSwitch.md) | why an application that lays out above the keyboard missed the focus of a new input on iOS 6, and the frame change the backports post |
| [UIKit: UILabel background](reference/backports/UIKit/UILabelBackground.md) | the opaque white default of a code-made label on iOS 6 and the later default the backports give it |
| [UIKit: UITextField alignment](reference/backports/UIKit/UITextFieldAlignment.md) | the top vertical alignment a code-made text field starts with on iOS 6 and the centered start the backports give it |
| [UIKit: UICornerConfiguration](reference/backports/UIKit/CornerConfiguration.md) | per-corner radii, concentric corners and how a view is clipped to them on iOS 6 |
| [Vision](reference/backports/Vision/README.md) | the Swift forms of the landmark, recognised-text and contour accessors, and the missing landmark detector |
| [WeatherKit: CompassDirection](reference/backports/WeatherKit/CompassDirection.md) | `Wind.CompassDirection`, measured |
| [WeatherKit: WeatherCondition](reference/backports/WeatherKit/WeatherCondition.md) | `WeatherCondition`, measured |
| [WidgetKit](reference/backports/WidgetKit/README.md) | the package `revenant@widgetkit` |
| [WidgetKit: values](reference/backports/WidgetKit/Values.md) | the value types, measured |
| [WidgetKit: host](reference/backports/WidgetKit/WidgetKit/Host.md) | the seam: there is no widget host |
| [WidgetKit: providers](reference/backports/WidgetKit/WidgetKit/Providers.md) | the two intent providers, and the spellings they do not share with the timeline provider |
| [WidgetKit: reuse](reference/backports/WidgetKit/WidgetKit/Reuse.md) | what WidgetKit was compared against, and why |

## React Native

| Document | About |
| --- | --- |
| [What runs](reference/react-native/coverage.md) | React Native and the Expo SDK on iOS 6.1.3, module by module |
| [Patches against the spike](reference/react-native/patches.md) | the spike's patch copies compared file by file with the packages' |
| [Adding a module](guides/react-native/add-a-module.md) | the steps from a coverage row to a module checked on the phone |
| [The JavaScript bundle for the JavaScriptCore host](guides/react-native/jsc-bundle.md) | exporting an Expo application's bundle without Hermes |
| [Driving a host by touch](guides/react-native/touch.md) | the touch injector and its command line for a phone without XCUITest |
| [The icon and launch image](guides/react-native/app-assets.md) | making them from the application's Expo configuration |
| [Isolated host build](guides/react-native/isolated-build.md) | building the React Native host in your own folder and private cache |
| [Hermes](reference/react-native/hermes.md) | the Hermes 250829098.0.17 package for armv7 iOS 6.0: its pin, flags and measurements on the iPhone 4S |
| [Running Hermes bytecode on the phone](guides/react-native/hermes-probe.md) | building the probe, compiling its bytecode, staging, claiming the phone and running it |
| [Using Hermes as the engine](guides/react-native/use-hermes.md) | selecting Hermes beside JSC, the bytecode bundle, the Promise check and the first-run numbers on the iPhone 4S |
| [Why Hermes is built this way](explanation/react-native/hermes-engine.md) | the version, the JSI copy, no Boost.Context on ARM32, and the 32-bit heap encoding |
| [Build inputs](guides/react-native/build-inputs.md) | making the host's `build/` inputs from the packages, and comparing them with the spike |
| [Expo manifest for the host](guides/react-native/app-config.md) | giving the host the application's own `EXConstants.bundle/app.config` |
| [Installing the host](guides/react-native/install-the-host.md) | staging a built host and putting it on the claimed phone under its own bundle id |
| [Missing components and stubs](guides/react-native/loud-components.md) | the loud provider for Fabric components and the log line of a stub that is called |
| [JavaScriptCore startup on the Paseo bundle](explanation/react-native/jsc-startup.md) | where the nine seconds of `evaluateJavaScript` go on the iPhone 4S: parsing first, then lazy parsing, the collector and the compiler |
| [JavaScriptCore startup sampler](reference/react-native/jsc-sampler.md) | the native sampler's method, output format, symbolication, the phase and thread numbers and their limits |
| [SIGBUS from JIT code on the Paseo bundle](reference/react-native/jsc-dfg-fault.md) | the reproduction with lowered tier-up thresholds, the fault record at the JIT pool's end, the DFG-off controls and what is still open |
| [JavaScriptCore bytecode cache for the host](reference/react-native/jsc-bytecode-cache.md) | the prebuilt engine's JSScript and bytecode-cache API, how the host reaches its context, the build that did not finish, and what is not measured |

## WebKit

| Document | About |
| --- | --- |
| [Build and test](guides/webkit/build-and-test.md) | the full build, deploy and verification |
| [Contributor guide](guides/webkit/contributing.md) | the Safari substitution, the gotchas, the conventions |
| [Maintaining](guides/webkit/maintaining.md) | how the port is carried against a moving engine |
| [Architecture](explanation/webkit/architecture.md) | how the engine is loaded in place of the system one |
| [Network](explanation/webkit/network.md) | HTTPS on a system whose TLS stopped working, and the HTTP cache |
| [Memory and caches](explanation/webkit/memory-and-caches.md) | what 512 MB forces |
| [WebGL](explanation/webkit/webgl.md) | the ANGLE backend this port had to write |
| [Carrying a 64-bit JSValue on ARMv7](explanation/webkit/armv7-jit.md) | the value representation the 32-bit JIT carries |
| [Keeping the engine current](explanation/webkit/core-update.md) | how the engine is updated |
| [Engine configuration](explanation/webkit/engine-configuration.md) | why the engine is configured the way it is |
| [Features and the Settings pane](reference/webkit/features.md) | what works on the phone, and what the Settings pane writes |
| [Compatibility](reference/webkit/compatibility.md) | what this OS does not have, probed on the device |
| [Tests](reference/webkit/tests.md) | the host and device tests, and what each one covers |
| [Device checks](reference/webkit/device-suite.md) | the checks run on the phone |
| [Tools](reference/webkit/tools.md) | the probes, and what each one answers |
| [SDK usage](reference/webkit/sdk-usage.md) | what this port reads from Apple's SDKs |
| [Upstream](reference/webkit/upstream.md) | what belongs upstream, not here |
| [Measurements](reference/webkit/measurements.md) | what was measured on the phone, and the hypotheses the measurements refuted |
| [Third-party](reference/webkit/third-party.md) | every dependency, its licence, and the screenshots' trademarks |

## Recompiler

| Document | About |
| --- | --- |
| [Build and translate](guides/recompiler/build-and-translate.md) | the commands, the guest libraries, what a bind names, and how to translate a library |
| [Contributor guide](guides/recompiler/contributing.md) | the layout, the conventions, the devices |
| [How it works](explanation/recompiler/how-it-works.md) | the pipeline, the status, the Swift runtime's classes, the scope |
| [Library mode](explanation/recompiler/library-mode.md) | a translated library inside an app's process: the address constraint, the loader, the runtime in a foreign process |
| [Library mode measurements](reference/recompiler/library-mode.md) | what the phone measured: resident set, address map and threads next to an 85 MB host, the bases that link and run |
| [Research](explanation/recompiler/research.md) | the research behind it |
| [Corpus and benchmark](reference/recompiler/corpus.md) | what each check proves |

## Agent skills

| Document | About |
| --- | --- |
| [Install and use](guides/agent-skills/install.md) | the agents, what you need, and the status |
| [Contributor guide](guides/agent-skills/contributing.md) | the layout and how to check the skills |
| [Clean-machine tests](guides/agent-skills/clean-machine-tests.md) | the scenarios an agent must follow from an empty directory |
