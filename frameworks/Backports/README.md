# Backports

Lists the iOS SDK members that the minimum deployment target lacks, emits a skeleton that fails loudly for each one `src/` does not implement, and counts how many are implemented.

## Scope

`backports_min_ios` (xmake option, default `6.0`) is the oldest iOS the build supports. In scope: a member introduced after it, and every member of a framework absent at it. A framework's introduction is approximated as the lowest introduction version among its annotated members.

## Facts

- ObjC and C: the umbrella header is run through `clang -Xclang -ast-dump` as text and streamed. `AvailabilityAttr` gives the introduction.
- Swift: `swift-api-digester -dump-sdk -swift-only` writes JSON, with one module cache shared by all frameworks.
- Each framework is one TSV in `build/generated/backports/cache/<sdk version>-<generator digest>/`. Four shards run in parallel under `/bin/sh`.

## Skeleton

`build/generated/backports/skeleton/` holds `revenant_backports.h`, `registrar.m`, and per framework `<N>.m` and `<N>.c`.

- Each in-scope member gets a stub that aborts with its name, for example `not implemented: -[NSUUID UUIDString]`. The skeleton does not read `src/`: a stub is inert wherever `src/` implements its member.
- ObjC methods and properties are added with `class_addMethod` only when the class does not already respond to the selector, so the system's implementation wins, as in `attach.c`. Missing classes are created first, only when `objc_getClass` finds none, so a class `src/` implements is never created twice.
- C and Swift stubs are weak definitions bound to the mangled symbol, so the strong definition in `src/` wins at link time within a library.

## Implemented count

The implemented members are the symbols of the objects that `src/<Framework>` compiles to, read from `build/.objs` with `nm` (classes, C functions, global variables) and the same `nm` listing for methods (with their class or category and selector). A property counts when its getter is implemented. Swift members are never counted as implemented. The clang AST was the first source of these keys; reading it cost hours on each cold build.

## Commands

- `./xmakew l -P . frameworks/Backports/tools/generate.lua`: facts and skeleton, cached per module.
- `./xmakew l -P . frameworks/Backports/tools/exports.lua [libdir] [report]`: after a build, reads the objects in `build/.objs` and the dylibs in `build/iphoneos/armv7/release` once each, checks every key of the objects against them, and writes `exports.txt` (per kind: implemented, exported once, missing, duplicated, not public; then the missing, duplicated and not public lines) and `status.txt` (`implemented X of Y` per framework) beside `report`. It fails when a public symbol or method is missing, or when two libraries export the same class, function, global or method.
- `./xmakew l -P . frameworks/Backports/tests/backports_test.lua`: fixture test.
- `./xmakew f -P . -p iphoneos -a armv7 --component=Backports` then `./xmakew build -P . FoundationBackports`: one shared library per library of the former package, `lib<Name>.dylib` with its install name under `/usr/lib/revenant/org.revenant.backports`. Each compiles `src/<Framework>`, `src/attach.c` and the skeleton of its framework, which configure generates; `backports_min_ios` is the only minimum, with no bands. The component option configures only this component and what it needs, and the build reads the iOS 26.2 SDK, so the sources compile against the headers they are written for.
- `REVENANT_GEN_SDK=<iPhoneOS SDK folder>` overrides the SDK the toolchain resolves.

## Public symbols

A key is public when the SDK both declares it and exports it: a class, C function, global or method declared in a framework's headers (from the clang AST, as the facts are), and for classes, functions and globals, also exported by a framework's `.tbd` (`tools/public.lua` scans each framework's `.tbd` for the names the headers declare). Methods are public through the headers alone. A key that is not public is counted and does not fail the check, and each class that is not public is listed.

`__NSConcreteUUID` is the one class the report lists as not public among the Foundation keys of the objects. The iOS 26.2 SDK's `Foundation.tbd` exports `_OBJC_CLASS_$___NSConcreteUUID`, but no Foundation header declares it, so it is not a declared symbol. The iOS 6.1.3 shared cache (read with `toolchain/modules/apple/dyld.lua`, `exported_by`) does not export it from Foundation, while it exports `NSUUID` and `NSTimer`; the class exists there only in Objective-C metadata, as a private class. An iOS 6 target never exported it, so the backport owes no export for it.

Methods of a `Revenant<Name>` proxy count as methods of `Name` when the library also exports `_OBJC_CLASS_$_<Name>`: the alias makes the proxy the class at run time (`revenant_alias.h`).

Methods are read from the libraries with `toolchain/modules/apple/objc.lua` (`binary_inventory`), which folds categories into their class, and from the objects with `nm`, which lists each method implementation as `-[Class sel]` or `+[Class sel]`. The objects are read once, in batches, for both reports.

## Limits

Swift types, variables and protocols are counted but not stubbed. The skeleton emits no protocol objects: a protocol that `src/` defines is registered at load only when its file uses it, because clang emits a protocol's metadata only in a translation unit that references it. So each such file ends with `revenantEmitProtocols`, which takes `@protocol` of every protocol the file defines (`UIKit/QuartzCoreProtocols10.m`, `HomeKit/HMHomeDelegateProtocols8_0.m`, `Foundation/NSURLSessionStreamTask9.m`). The object files carry the metadata and `tests/QuartzCore/protocols_test.m` checks it on the host; it has not been run on a device. `_OBJC_CLASS_$_` class symbols are not emitted either, so an app that links an absent class does not link yet. C global variables are not stubbed. Subframeworks and enum constants are excluded. ObjC type encodings are empty.

## Open gaps

Partly backported. Each of these builds, and the part it does not cover is missing from the module, so a program that uses it fails to compile against the backport rather than running with a fake:

- `UniformTypeIdentifiers` (`swiftUniformTypeIdentifiers`, wrapper `revenant@uniformtypeidentifiers`): `UTType` with its 140 standard constants, conformance, supertypes, tags, extension and MIME lookups, and the `URL` helpers. Missing: the `NSItemProvider` extension (an iOS 8 class), bridging to `UTTypeReference` (an iOS 14 Objective-C class) and `URLResourceValues.contentType`. The standard types are a table generated from the macOS 27 UTI database, with English descriptions. `JSONEncoder` writes the identifier as a string, where the SDK writes an object with an internal index, so the bytes differ; decoding accepts both. `tests/UniformTypeIdentifiers/main.swift` compares 2,439 lines of output with the host.
- `CryptoKit` (`swiftCryptoKit`, wrapper `revenant@cryptokit`): `SHA256`, `SHA384`, `SHA512` and their digests, `HMAC`, `SymmetricKey` and `AES.GCM`. The AES block is CommonCrypto ECB; CTR and GHASH are software, because the iOS 6 CTR mode is not verified. Missing: `SHA3`, `Insecure`, `ChaChaPoly`, `HKDF`, `Curve25519`, `P256`, `P384`, `P521`, HPKE, Secure Enclave and key wrapping. `tests/CryptoKit/main.swift` compares 377 lines of output with the host, including the error cases.
- `NaturalLanguage` (`NLLanguageRecognizer`, `NLTokenizer` and the `NLLanguage` constants in `src/Foundation`): the dominant language and the tokens match the host on `tests/NaturalLanguage/main.m`. `languageHypothesesWithMaximum:` and its probabilities are word-count shares, not Apple's model, and that test does not compare them.
- `UserNotifications` (`src/UIKit/UNUserNotificationCenter.m`): the center delivers over `UILocalNotification`. `tests/uikit_test.lua` checks its members.
- `Network` (`swiftNetwork`, wrapper `revenant@network`): `NWConnection` over TCP and UDP POSIX sockets on the queue it starts on, `NWPathMonitor` over `SCNetworkReachability`, and `NWEndpoint` with the address types. A refused TCP connect goes to `waiting`, as on iOS. Missing: TLS (`NWProtocolTLS`, `NWParameters(tls:tcp:)`), the TCP and UDP option types, `NWListener`, `NWBrowser` and the rest of the framework. `NWInterface.type` reads the interface name (`en` wifi, `pdp_ip` cellular, `lo` loopback), so it is an approximation. `tests/network_test.lua` compares the connection, path and endpoint results with the host on the same socket exchanges. The overlay no longer uses the `nw_*` C seam, so the iOS 12 gate is gone.
- `WidgetKit` (wrapper `revenant@widgetkit`): the timeline, its entries and reload policy, the provider context, the value types, the configurations and the four providers, the control types, the Dynamic Island types and `ActivityConfiguration`. Missing: the rows that need SwiftUI (the `EnvironmentValues` members, the two `ControlWidget*` constructors and the three `body` members) and the rows whose type belongs to another module, which the digester does not print. [WidgetKit](../../docs/reference/backports/WidgetKit/README.md) says what the seam is and [its providers](../../docs/reference/backports/WidgetKit/WidgetKit/Providers.md) what 240 of 340 rows means. The swift job builds the target and requires the wrapper.

The large members still open, with a design note for each, are in `docs/explanation/backports-open-members.md`.

These framework targets fail before building on iOS 6 while Telegram's demanded API is missing:

- `BackgroundTasksBackports`: `BGContinuedProcessingTask` and `BGContinuedProcessingTaskRequest` are iOS 26 APIs.
- `VisionKitBackports`: the document scanner needs `VNDocumentCameraViewController`, `VNDocumentCameraScan` and `VNDocumentCameraViewControllerDelegate`.
- `StoreKitBackports`: Telegram calls `AppStore.showManageSubscriptions(in:)`, which is not backported.
- `AuthenticationServicesBackports`: Telegram's authorization flows need `ASAuthorizationController`, its delegate and presentation protocols, `ASAuthorizationAppleIDButton`, the passkey provider, assertion and registration types, and `ASCredentialUpdater`.
- `NetworkBackports`: Telegram needs the Swift `NWProtocolTCP.Options`, `NWListener`, `NWProtocolFramer` and `NWProtocolFramerImplementation` overlays. `NWConnection`, `NWEndpoint` and `NWParameters` are implemented.
- `WebKitBackports`: BrowserUI needs `WKSnapshotConfiguration`, `WKContextMenuElementInfo`, `WKDownloadDelegate`, `WKURLSchemeHandler` and `WKURLSchemeTask`.

`WidgetKit` and `WidgetCenter` are provided by the Swift overlay. `PassKitBackports` provides `PKPaymentNetworkAmex`, `PKPaymentNetworkDiscover`, `PKPaymentNetworkMasterCard` and `PKPaymentNetworkVisa`.

## Lowering gaps

These demand-map references are SDK declarations whose availability lowering belongs to `toolchain/modules/apple/lowered.lua`:

- `Accelerate.kvImage420Yp8_Cb8_Cr8` and `Accelerate.kvImageARGB8888` are enum values used by TelegramVoip's `OngoingCallContext.swift`.
- `Foundation.PresentationIntent` is the Swift overlay type used by BrowserUI's `BrowserMarkdown.swift`; the Objective-C `NSPresentationIntent` implementation is already in `src/Foundation/NSPresentationIntent15.m`.

The Swift overlays below are built as targets of this component, and each builds only for an iOS its backport reaches. Below that release the build refuses, and the wrapper package refuses on load, with "not yet backported". None of these is a supported minimum: each closes when its backport makes it build at iOS 6.

- `swiftRealityFoundation` and `swiftRealityKit` below iOS 8: they load SceneKit, and the SceneKit members they import (`SCNHitTestResult`, `-[SCNView hitTest:options:]`, `+[SCNNode nodeWithGeometry:]`) are not backported yet. RealityKit's UIKit part is open too. [RealityFoundation below iOS 8](../../docs/reference/backports/RealityFoundation/SceneKit.md) says what brings them back.
- `MusicKit` (wrapper `revenant@musickit`): `src/MusicKit/Catalog.swift` uses `URLComponents`, which the iOS 6 SDK declares for iOS 7 and later ("only available in iOS 7.0 or newer"), and `URLQueryItem` with `queryItems`, which need iOS 8. Its build refuses with "not yet backported" before it compiles.
- `SwiftData` (wrapper `revenant@swift-data`): `src/SwiftData/DefaultStore.swift` imports `FoundationEssentials`, which the iOS 6 SDK does not provide ("no such module 'FoundationEssentials'"). Its build refuses with "not yet backported" before it compiles.
- `CreateML` (wrapper `revenant@createml`): `src/CoreML/ShapedArray.swift` names `MLMultiArrayDataType`, which the SDK's CoreML declares for iOS 11 and later only ("cannot find type 'MLMultiArrayDataType' in scope"). The `CoreML` target refuses with "not yet backported", and so do `CreateMLComponents` and `CreateML`, which need it.

None of the four is built or required by the swift job, and their wrappers refuse on load with the same message.
