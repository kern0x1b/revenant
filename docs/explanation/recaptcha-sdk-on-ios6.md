# Google reCAPTCHA Enterprise SDK on iOS 6 (armv7): feasibility

Date: 2026-11-11. Stage 1 of the work: research, with evidence. Each statement is marked as **measured** (a command or
a read of a file was run and its output is named here), **reasoned** (an inference from the measurements), or **not
verified** (this pass did not establish it).

## Question and verdict

Telegram 13.0.0 for armv7 on iOS 6.1.3 (iPhone 4S) signs in by phone number. When the server answers
`RECAPTCHA_CHECK_<method>__<siteKey>`, the client needs a token from Google's reCAPTCHA Enterprise iOS SDK, and the
token must come from the original SDK running in the app on the device. The current package
`telegram-build/bazel/packages/third-party/recaptcha` is a stand-in (UIWebView plus the web `enterprise.js`), which the
server does not accept.

- **Recommended: translate the SDK's original arm64 object code** with the recompiler (`docs/explanation/recompiler/`)
  and link it into the armv7 app against revenant's own Swift runtime and backports. Plausible, not proven. The SDK's
  instruction set is not the obstacle; the obstacles are the Swift and Objective-C object boundary, exceptions, and the
  Swift libraries the SDK calls. Estimate (reasoned): a prototype that reaches the SDK's `execute` on the device in 2 to
  4 weeks; a token on the device in 1 to 3 months.
- **Not recommended unless translation fails at the object model: an AArch64 interpreter in the app.** Nothing in the
  repository runs AArch64 guest code on a device (section 6b). Estimate 3 to 6 months.
- **Excluded:** running the SDK off the device (Mac, simulator, server), and a re-implementation of Google's protocol.
- **Open:** whether the SDK returns a token when App Attest is unsupported. On iOS 6 it is unsupported by design, and the
  consumer of that state is not traced (section 7).

## 1. Input and method

Input, read in place and not copied into the repository: `telegram-build/build/bazel/third-party/recaptcha/
RecaptchaEnterprise.xcframework/ios-arm64_arm64e/RecaptchaEnterprise.framework/RecaptchaEnterprise`, a static archive
(`ar`) with arm64 and arm64e slices, 12,206,256 bytes. **Measured:** the arm64 slice was extracted with `lipo -thin` into
scratch and removed at the end of the task. The framework's `Info.plist` gives `CFBundleShortVersionString` 1.0,
`MinimumOSVersion` 15.0, `DTXcode` 2620 (17C52), and the iphoneos 26.2 SDK. The generated Swift header says Swift 6.2.3.
The `.swiftmodule` is a directory with `arm64.swiftinterface` and `arm64e.swiftinterface` (128 lines each, compiled with
`-enable-library-evolution`, `-swift-version 6`, Swift 6.2.3) and the matching `.swiftdoc`; there is no binary
`.swiftmodule` file. The framework has a privacy manifest and no licence file.

Tools (Apple's, from the Command Line Tools): `ar`, `lipo`, `nm`, `strings`, `swift-demangle`, `llvm-objdump --macho -d`.
**Measured:** all 319 object members were disassembled into one listing (261,038 lines). The call graph uses the symbol
names of `bl`, `b` and `adrp` references, and a breadth-first walk starts from five entry points: the two
`RecaptchaClient.execute` overloads with a completion, the async `execute`, and the `fetchClient` and `getClient` entries.

Limit: the graph does not follow indirect calls (`blr`, protocol witness tables, async function pointers, closures held
in data). The reached sets below are therefore lower bounds, and each statement says which graph it comes from.

## 2. What the SDK is

- **Measured:** 11,182 global definition lines (`nm -gU`), 7,991 unique names. The public module API, demangled:
  `Recaptcha` (`fetchClient(withSiteKey:completion:)`, `getClient(withSiteKey:completion:)`,
  `getClient(withSiteKey:withTimeout:completion:)`, `getClient(siteKey:completionHandler:)`, async `fetchClient(withSiteKey:)`);
  `RecaptchaClient` (`execute(withAction:completion:)`, `execute(withAction:withTimeout:completion:)`,
  `execute(_:completionHandler:)`, async `execute(withAction:withTimeout:)`); `RecaptchaAction`, `RecaptchaActionType`
  (login, signup, other), `RecaptchaToken` (`recaptchaToken`), `RecaptchaError` (an `NSError` subclass),
  `RecaptchaErrorCode`, `RecaptchaConstant`.
- **Measured:** 5,101 distinct module functions. From the five entry points, 186 are reached in the static graph. Most
  internal types have obfuscated names (`RCa` to `RCgcf`). The protobuf runtime is compiled in (`RCAx_GPB*`, 594 symbols
  defined in the archive), so it is not an external dependency.
- **Measured:** 54 call sites of `__isPlatformVersionAtLeast` with platform 2 (iOS): 16.0 (3 sites), 17.0 (1), 18.0 (50).
  There is no check against 14.0 (App Attest) or 15.0.
- **Measured:** `DCAppAttestService` is used by one reached function, the closure of `static RCfni.rcfnp(_:)`. It sends
  `sharedService`, then `isSupported`, and stores the result as one byte at offset +0x18 of an object of class `RCfpo`
  (the wrapper with `generateKeyWithCompletionHandler:`, `attestKey:clientDataHash:completionHandler:` and
  `generateAssertion:clientDataHash:completionHandler:`). The code after the store does not branch on it.
- **Measured:** a second class, `RCfqf`, conforms to the same protocol. Its operations report an error (type `RCcna`). Nothing in the static graph names the code that chooses between `RCfpo` and `RCfqf`, or the code that
  reads the flag: those calls go through protocol witness tables (section 7).

## 3. Instructions

**Measured,** over all member objects: base ARMv8.0 integer code; load-acquire and store-release (`ldar` 171, `stlr` 296);
exclusive pairs (`ldaxr` 87, `stlxr` 87, `clrex` 87). No LSE atomics (`cas`, `ldadd`, `swp`), no pointer authentication,
no `svc`, no `mrs`, no `dc zva`. NEON is minor (`movi.16b` 189, `ext.16b` 4, a few others). Traps: `brk` 904, `udf` 45.
Half-precision conversions were not counted separately (`fcvt` 14).

**Reasoned:** the instruction set is not what blocks translation. Two items need the recompiler to do more than it does
today: exclusive monitors are not yet atomic (`docs/explanation/recompiler/research.md`, section 8, "not done"), and the
87 exclusive pairs depend on that; and `brk` and `udf` must lower to traps (`docs/explanation/recompiler/how-it-works.md`,
"Scope and limits"). Both are checked only by lifting, and no lift has been run.

## 4. What `execute` needs: imports

**Measured,** from the static graph (lower bound):

| Group | Reached | External, whole archive | What it is |
| --- | --- | --- | --- |
| Objective-C classes and metaclasses | 9 | 42 | `DCAppAttestService`, `NSURLSession`, `NSURLSessionConfiguration`, `NSUserDefaults`, `NSLock`, `NSRecursiveLock`, `NSMutableDictionary`, `OS_dispatch_queue`, `OS_dispatch_source` |
| Swift Network | 9 | 11 | `NWPathMonitor`, `NWPath.Status` (reachability) |
| Swift CryptoKit | 8 | 25 | `SymmetricKey` |
| Swift Foundation | 7 | 100 | `Data` storage internals, bridging of `NSError` |
| Swift Dispatch | 8 | 15 | `DispatchTime`, `DispatchQoS` |
| Swift Concurrency runtime | 7 | 14 (`swift_task_*`, `swift_defaultActor_initialize`) | tasks run by the SDK |
| Swift standard library | 84 | 255 | |
| C and system | | 615 names; the reached set uses Keychain (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, `kSecClassGenericPassword`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), `___isPlatformVersionAtLeast`, `malloc_size`, `memcpy`, `memmove` | |

The whole-archive count is 1,095 undefined names that the archive does not define: 423 Swift names from other modules,
42 Objective-C classes and metaclasses, 615 C and system names, one unnamed literal, and 14 link-time markers of Swift
modules (`__swift_FORCE_LOAD_$_swiftUIKit`, `…swiftMetal`, `…swiftQuartzCore`, `…swiftXPC`, and others). Whether reached
code uses those modules is not verified.

Outside the static graph but in the module (the WebView path, reached through closures of the task `RCcfz`):
`WKWebView`, `WKWebViewConfiguration`, `WKScriptMessageHandler` (`userContentController:didReceive:`), `UIDevice`, and
CommonCrypto's `CC_SHA256`.

**Measured,** selectors sent by reached functions: `init`, `sessionWithConfiguration:`, `defaultSessionConfiguration`,
`setWaitsForConnectivity:`, `setTimeoutIntervalForResource:`, `sharedService`, `isSupported`, `standardUserDefaults`,
`removeObjectForKey:`, `dictionaryRepresentation`, `initWithDomain:code:userInfo:`, `initWithData:error:`, `lock`, `unlock`.
Selectors in the module but not on the static path: `loadHTMLString:baseURL:`, `evaluateJavaScript:completionHandler:`,
`addScriptMessageHandler:name:`, `initWithFrame:configuration:`, `dataTaskWithRequest:completionHandler:`,
`identifierForVendor`, `model`, `bundleIdentifier`, `infoDictionary`, `operatingSystemVersion`, `setObject:forKey:`.

**Measured,** strings in the archive: `https://www.recaptcha.net/recaptcha`; `https://www.gstatic.com/recaptcha/verify_key/orcas/prod/ios/verify_key.txt`;
`www.gstatic.com/recaptcha`, `www.gstatic.cn/recaptcha`, `www.recaptcha.net`; `recaptcha.mobile` (the script-message
handler name, in 10 objects); `recaptcha.client`; `type.googleapis.com/`; `RCA_client_events`; `com.google.recaptcha`;
error texts such as `Invalid Site Key.`, `Invalid Key Type.`, `Invalid Package Name.`, `Unexpected key type`,
`Execution timed out.`.

**Not recovered:** the request path below the base URL, the request body, and the protobuf field names. The path segments
are Swift short literals, which the compiler encodes as immediates, and the protobuf fields carry obfuscated names. So
the fields that reach the server (bundle identifier, app version, key type) are not established from the binary here.

## 5. What revenant already has for each import

**Measured,** by reading the tree (`frameworks/Backports`, `packages`, `tools`):

| Need | In revenant | Note |
| --- | --- | --- |
| Swift runtime, Concurrency, Dispatch overlay | `packages/s/swift-runtime/xmake.lua` lists `swift`, `swiftCore`, `swift_Concurrency`, `swiftDarwin`, `swiftSynchronization`; Dispatch overlay patches in `packages/s/swift-runtime/patches/overlays/` | package build not run here; the `swift_task_*` symbols are not found as text in the tree |
| Network | `frameworks/Backports/src/Network/` (`NWPathMonitor.swift`, `NWConnection.swift`) | ADR 0016: the overlay runs `NWPathMonitor` over `SCNetworkReachability`; symbol coverage not diffed |
| CryptoKit | `frameworks/Backports/src/CryptoKit/CryptoKit.swift`; `packages/s/swift-crypto` | `SymmetricKey` appears in swift-crypto patches |
| WKWebView and script messages | `frameworks/Backports/src/WebKit/WKWebView.m` (`initWithFrame:configuration:` at line 129, `loadHTMLString:baseURL:` at 517, `evaluateJavaScript:completionHandler:` at 644); `WKUserContentController.m` (`addScriptMessageHandler:name:` at 155) | the engine is described in `docs/explanation/webkit/architecture.md` |
| NSURLSession | `frameworks/Backports/src/Foundation/NSURLSession.m` (`dataTaskWithRequest:completionHandler:`, `sessionWithConfiguration:`); `NSURLSessionConfiguration.m` synthesises `waitsForConnectivity` and `timeoutIntervalForResource` | |
| DeviceCheck and App Attest | `frameworks/Backports/src/DeviceCheck/DCAppAttestService.m`: `isSupported` returns NO; the three operations return `revenant_device_check_unsupported()` | an honest "unsupported", not a fake success |
| Keychain | `frameworks/Backports/src/Security/` | `SecItemCopyMatching` is mentioned there; the other calls were not checked one by one |
| CommonCrypto | `frameworks/Backports/src/CommonCrypto/` | directory present; `CC_SHA256` not checked |
| `NSProcessInfo.operatingSystemVersion` | `frameworks/Backports/src/Foundation/NSProcessInfo+OperatingSystemVersion.m` | |
| Frameworks iOS 6 lacks | `tools/bazel-overlay.lua` (Telegram overlay) writes `REVENANT_WEAK_FRAMEWORKS`: each SDK framework iOS 6 does not have is a weak import, and a revenant backport that exists takes its symbols | a missing DeviceCheck or Network image does not stop dyld on iOS 6 |

**Gaps this pass sees:** whether the Concurrency runtime is built and runs on iOS 6; a symbol-by-symbol diff of the 1,095
external names against the built libraries (needs the built packages, so CI); an armv7 module interface for the Swift
compile of Telegram (section 6a).

## 6. The variants

### 6a. Translate the SDK's object code (recommended)

Lift the 319 members with rellume (`recompiler/src/xlate/`), generate the bridges at the Objective-C boundary (the
`NSError` and `NSObject` subclasses the SDK exposes, and the protobuf runtime's Objective-C classes), and link into the
Telegram armv7 app with revenant's Swift runtime and backports. The stand-in package keeps its module name
`RecaptchaEnterprise` and the public surface of section 2; its sources are replaced by the translated object.

Why it fits (measured or from the existing docs): the instructions are plain (section 3); the protobuf runtime is an
Objective-C library and uses the existing Objective-C path; the Swift classes at the boundary are few and public
(`Recaptcha`, `RecaptchaClient`, `RecaptchaAction`, `RecaptchaToken`, `RecaptchaError`, `RecaptchaConstant`); the
ivar-layout reconciliation for guest subclasses of host classes is in `docs/explanation/recompiler/research.md` (the
general translation fixes, item 2).

Blockers and risks, each to be checked by lifting:

1. **The Swift object model** (`research.md`, section 7). A guest Swift object has an 8-byte isa; the host Objective-C
   runtime is 32-bit. The public classes that subclass host classes use the existing bridge. Pure Swift classes with only
   guest ancestry use the shadow mechanism (`src/runtime/swift_classes.m`).
2. **Swift ABI at the link with Telegram.** Telegram's armv7 Swift code needs a module interface for `RecaptchaEnterprise`.
   The shipped module has an `arm64.swiftinterface` (the public API, 128 lines) but no armv7 slice, so the armv7 compile
   of Telegram needs a copy of that interface with the target changed to armv7 (a text change; the interface uses
   library evolution, so the compiler does not rely on the arm64 layout). Not verified with an armv7 compile.
3. **Exceptions.** The archive has 14 Objective-C catch sites (`objc_begin_catch`) and 15 `__Unwind_Resume` sites, and
   the protobuf runtime raises `RCAx_GPBCodedInputStreamException`. None of the catch sites is on the static path, which is
   only a lower bound. The recompiler does not yet unwind exceptions through translated frames (`how-it-works.md`, "C++
   runtime"; `research.md`, section 8). Swift `throws` is not affected: `swift_willThrow` (483 sites) and
   `swift_errorRetain` (341) are ordinary returns.
4. **Exclusive monitors** (section 3): the 87 `ldaxr`/`stlxr` pairs need the atomicity the recompiler does not yet give.
5. **Traps** (section 3): `brk` 904 and `udf` 45 must lower to traps, not to a failed lift.
6. **Coverage of the Swift overlays** (Network, CryptoKit, Foundation internals, Concurrency). Presence is not coverage;
   the 1,095-name diff is the measurement that answers it.

Early experiment, to run in stage 2 on CI (heavy, so the coordinator orders it): lift all 319 members into one guest image,
link them into an armv7 test program with the backports, and call `fetchClient` and `execute` on iOS 6. The first failing
symbol or crash names the next blocker, and the lift failures and the unresolved names are counted.

### 6b. An AArch64 interpreter in the app

**Measured:** no AArch64 execution engine runs on a device in this repository. `packages/d/dynarmic` is an A32 (armv7)
guest JIT for the emulator; its recipe is `on_install("macosx|arm64")`, so its host is macOS on arm64, and it cannot run
on an armv7 device. `emulator/src/foundation/cpu.cpp` uses `Dynarmic::A32`.

**Reasoned:** an interpreter would be new code. The SDK's own instruction set is small (section 3), but the code it runs
is not only the SDK's: the Swift runtime, Foundation's Swift code and the Concurrency runtime are 64-bit as well, so the
interpreter would run them too, and every crossing into host WebKit and Objective-C would need pointer conversion (the
boundary of 6a, at run time). CPU cost on the 4S is not measured. Estimate 3 to 6 months.

### 6c. Run the SDK outside the device

Excluded by the owner's rule that the token binds to the app on the device. App Attest keys are bound to the device. The
xcframework has a simulator slice (`ios-arm64_x86_64-simulator`), but App Attest is not available in the simulator (Apple's
documentation for `DCAppAttestService`; not measured here). No simulator runtime is installed on this Mac:
`xcrun simctl list runtimes` printed none.

### 6d. A re-implementation of Google's protocol

Not the original SDK, so excluded by the brief. It would also need the request schema, which section 4 says is not
recovered.

## 7. A token without App Attest

**Measured:** on iOS 6 the SDK sees `isSupported == NO`, because revenant's DeviceCheck backport says so. The SDK keeps the
flag and has a second, error-returning provider (`RCfqf`).

**From Google's documentation** (fetched 2026-11-11, `docs.cloud.google.com/recaptcha/docs/instrument-ios-apps`):

- the app's minimum is iOS 15 ("Set the minimum SDK of your app to iOS 15"); the framework's `MinimumOSVersion` is 15.0;
- "reCAPTCHA uses Apple's App Attest as part of its detection engine." The page does not say whether App Attest is
  required, what happens on unsupported devices, or whether a token is still returned. Its only token statement is that a
  token is returned "if the integration is successful";
- the SDK "makes use of reflection and dynamic code" to update the detection system.

**Not known:** what the SDK does with `isSupported == NO` and the provider's error. The consumer is reached through the
protocol witness table of `RCfpb`, which the static graph does not follow. It can be found by tracing those witness calls,
or observed at run time after translation.

**Not known:** whether Google's server accepts a token from this path for Telegram's site key. Only a real flow answers
that, and Telegram's server check needs a phone number, which is out of scope for this stage.

**Can be checked in stage 2 without a phone number:** that the translated SDK completes `execute` on the device and returns a
non-empty token. That sends a request to Google, so the owner must choose the key: Telegram's site key, or a Google
reCAPTCHA Enterprise testing key with a fixed score, which Google's documentation describes for local development (created
in the owner's Google Cloud project).

## 8. Telegram's call pattern

**Measured,** in the read-only reference checkout `~/Git/reference/Telegram-iOS-release-13.0.0`:

- `submodules/TelegramUI/Sources/AppDelegate.swift` lines 613 to 660: `Recaptcha.fetchClient(withSiteKey:)` once per site key,
  cached as promises; `execute(withAction:)` runs only for method `signup` (`RecaptchaAction.signup`), and any other method
  gives a nil token.
- `submodules/TelegramCore/Sources/Network/Network.swift` lines 634 to 641: the token is awaited with a 15-second timeout,
  which yields `RECAPTCHA_TIMEOUT`.
- `submodules/MTProtoRustEngine/Sources/MTProtoRustEngine/RustNetworkSession.swift` lines 775 to 777: the same verification
  from the Rust engine's branch.

## 9. Legal frame

- The input is the xcframework that Telegram's repository carries. It is read locally and not redistributed. Nothing derived
  from it (translated objects, lifted IR, listings, scratch) is committed to revenant or to any other repository. The
  recipe will refer to the xcframework by the owner's local path, as the stand-in package does.
- **Measured:** the GitHub repository `GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk` is under Apache-2.0. Its
  LICENSE, section 4, allows redistribution with notices, and section 4(b) requires modified files to carry notices. The
  text has no clause on reverse engineering or decompiling. The framework itself has no licence file, only a privacy
  manifest, so that its terms equal the repository's is an inference, not verified. The owner should confirm it.
- This section is an engineering reading of the licence text, not legal advice.

## 10. What was run in this stage

- **Run:** the calculations of sections 2 to 4 and 7, from `ar`, `lipo`, `nm`, `strings`, `swift-demangle` and
  `llvm-objdump` on the listed input, plus the call graph of section 1, and the greps of the revenant tree in section 5.
  Web reads: the Google documentation and the LICENSE of the repository (section 7 and 9).
- **Not run:** a lift, a device run, any request to Google, any simulator run.
- Scratch lived under `.cache/scratch/recaptcha-sdk/` of the main checkout and was removed at the end of the task.

## 11. Next steps and decisions

1. Approve variant 6a for stage 2, and the first experiment on CI (section 6a): lift the 319 members, count the lift
   failures and the unresolved names, and find the first runtime blocker on the 4S.
2. Choose the site key for the device test (Telegram's, or a Google testing key the owner creates). Both send requests to
   Google.
3. Confirm the licence of the xcframework binary (section 9).
4. Trace the consumer of `isSupported` (section 7). It is a static task that can run first in stage 2, before translation.

## 12. Stage 2: the object-model probe (measured on the iPhone 4S)

Question: can a Swift class with a host ancestor (`NSObject`, `NSError`, `NSOperation`), as 13 of the SDK's Swift classes
are, run in the guest Swift runtime (an arm64 `libswiftCore` 6.4.0 built from source, translated with the program) while
the host Objective-C runtime (armv7, 32-bit) still sees it as a class? The probe is a small arm64 program with the same
shapes: an open `NSObject` subclass with a `String`, an array, an optional and a closure as fields, a `final` subclass of
it, a `final` subclass of `NSOperation`, an `NSObject` subclass with a `String` field, and a pure Swift class. It was
translated with `translate.lua` and run on the phone, one test per run.

**Worked (measured):**

- A pure Swift class (guest ancestry only): create, field, method.
- The Objective-C view of the host-layout classes: the five words of the rewritten `class_t` are right (`isa`, `super`,
  `cache`, `vtable`, `data`); `class_getSuperclass` returns `NSObject`, `ProbeClient` and `NSOperation`.
- An open `NSObject` subclass: allocation, `init` (`objc_msgSendSuper2` into the host `NSObject`), methods, `String` and
  array fields, creating a second `NSObject` subclass object from a method, and its `deinit` running when the last
  reference goes.

**Did not work (measured, three crashes, one cause):** `[super init]` of a `final` subclass (of `ProbeClient` and of
`NSOperation`) and `[super dealloc]` of the `NSObject` subclass after its `deinit` body. The Swift code builds the
`objc_super` with `swift_getObjectType(self)`. The guest runtime reads that class as a 64-bit `ClassMetadata` (`Superclass`
at +8, `Data` at +32) while the program rewrote it in place to the 32-bit layout (`super` at +4, `cache` at +8, `data`
at +16). It does not see a Swift class and returns the same constant (a metadata-pool address in the guest runtime's data)
for every class; the host `objc_msgSendSuper2` dereferences a null superclass. The runtime was traced: `raw_class=0x105f92a8` for
`ProbeSub`, `ProbeOperation` and `ProbeToken`, while the open class `init` calls (static class from the code) were right.

**Why this is not a local bug:** the two layouts cannot share one cell (`super32` at +4 is inside the 8-byte `isa` the guest
reads; `cache32` at +8 is the guest's `Superclass`). Every runtime path that reads the metadata of such a class is
affected: `swift_getObjectType`, `type(of:)`, `as?` casts, `swift_dynamicCastClass`, protocol conformance lookup. Instance
layout has the same problem: the guest reads the 8-byte `isa` of a host-layout instance and sees the first field in its high
half.

**Verdict: the in-place host layout works only for the cases above and fails in general.** The alternatives are in section 13.

**A separate failure, not caused by an ancestor:** `String(describing: PureSwift.self)` (a metatype of a pure Swift class)
aborts in `_swift_release_dealloc` (the object's `destroy` slot is zero). It needs its own investigation.

## 13. Stage 2: milestone 1 and the blocker table

All 319 objects went through the recompiler (milestone 1). Blockers, from the lift of the whole archive: the arm64 guest
overlays that the SDK imports (Foundation 59 + 22 names, CryptoKit 18, Dispatch 9, Network 8, Darwin 2), the generated
bridges still missing for about 114 imported functions, the 14 Objective-C exception catch sites, and 127 "cannot decode
function" entries in the guest `libswiftCore` (most are jump-table words that `ld64` lists as function starts; the fix is in
the recompiler, `JumpTables::IsData`, covered by the `jumptable` host test).
