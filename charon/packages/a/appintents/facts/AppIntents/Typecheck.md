# AppIntents typecheck: the runtime configuration and its result

The configuration the module needs, stated so that the typecheck command below is that configuration
and nothing else. Measured on 2026-10-17 from the `v-impl-appintents` worktree of charon.

## The configuration

- Toolchain: charon@swift 6.4.0 (`swiftc` under its package folder).
- SDK: iPhoneOS16.4 from the `iphoneos-sdk` 16.4 package.
- Runtime: charon@swift-runtime 6.4.0, installed variant `1b938f...`, built with the backports. Its
  `share/lift/vfs.yaml` is the overlay the module reads the lifted headers through.
- Target: `armv7-apple-ios6.1.3`.
- Backports: the runtime's lifted headers are on the overlay (`-Xcc -ivfsoverlay -Xcc vfs.yaml`), and
  `-DCHARON_APPINTENTS_PORT_HEADERS` is set, which is what the recipe sets when the runtime carries
  `CHARON_SWIFT_PORT_HEADERS`.
- Concurrency and language mode: no `-swift-version` is passed, so the compiler's default language mode
  applies. `-bundled-swift-runtime` and `-runtime-compatibility-version none` are as `modules/apple/swift.lua`
  `runtime_flags` gives them. No strict-concurrency flag is set.
- Not set: `-DCHARON_APPINTENTS_CORESPOTLIGHT` (the CoreSpotlight lift is not measured here) and
  `-DCHARON_APPINTENTS_CARRIES_LOCALIZED_STRING`. The module source includes `LocalizedStringResource.swift`
  unconditionally in this command, which is what the recipe does when the runtime has no
  `LocalizedStringResource`. That the runtime lacks it is not measured here.
- Not set: `-DCHARON_APPINTENTS_NSUSERACTIVITY_INTENT`. The lifted headers do not carry
  `NSUserActivity.intent` (iOS 12), so `widgetConfigurationIntent` is compiled out (see Spotlight.swift).

## The command

    swiftc -target armv7-apple-ios6.1.3 -clang-target armv7-apple-ios6.1.3 -sdk <iPhoneOS16.4.sdk> \
      -resource-dir <runtime>/lib/swift -Xfrontend -bundled-swift-runtime -runtime-compatibility-version none \
      -wmo -module-name AppIntents -O -file-prefix-map "$PWD=/appintents" -parse-as-library \
      -DCHARON_APPINTENTS_PORT_HEADERS -Xcc -ivfsoverlay -Xcc <runtime>/share/lift/vfs.yaml \
      -typecheck Sources/AppIntents/*.swift

run through `coordination/heavy.sh` (the fleet's slot queue).

## The result

- Baseline: 626 errors (`.agent-work/runs/v-impl-appintents/rename-probe/before.log`), mostly availability
  errors ("only available in iOS 13"). The flags of that run are not restated here; the run log is the record.
- With the overlay and the define, before the signature pass: 3 errors. `Items.swift:615` (the section
  builder passed item values where the section init takes `ValueType`s), `Spotlight.swift:222`
  (`NSUserActivity` is iOS 8, the extension had no availability), and `Spotlight.swift:226`
  (`NSUserActivity.intent`, not in the lifted headers).
- After: **0 errors**, exit 0, 58 warnings. The warnings are not failures and are not yet triaged.
- `DynamicOptionsProvider.ParameterDependency` (`typealias ParameterDependency = IntentParameterDependency`,
  unbound, as the 26.2 SDK declares it): accepted with no diagnostic in the protocol body. Swift rejects
  `public` on it ("'public' modifier cannot be used in protocols"), so it is written without the modifier,
  as protocol members are.

## Not measured

- The object: the module has been typechecked, not compiled to an object or linked on an armv7 image.
- `CORESPOTLIGHT` and `LocalizedStringResource`: whether each is present on this runtime (see above).
  Either can change the source set, so 0 errors here is evidence for this configuration only.

## Signature pass: top-level kinds

The counts below came from a Python script over the 26.2 skeleton's top-level rows. That script was deleted
(Python is not allowed in this band), so the counts are not reproducible from this repository
(`ai-rows.tsv`, 235 rows, 20 of them other modules' types the spec names: Foundation, CoreSpotlight, stdlib).

- 212 of the 215 AppIntents-owned top-level types match the SDK's kind.
- Converted to the SDK's kind, typecheck 0 errors: `AppDependency`, `IntentParameterDependency`,
  `IntentProjection`, `EntityProperty` (struct to `final class`), `EntityQueryPropertyDeclaration`
  (struct to `class`), `IntentDonationManager` (`final class` to struct). The class inits that delegate
  are `convenience`; a class setter is not `nonmutating`.
- Shape changes, typecheck 0 errors: `IntentValueQuery` is the SDK's protocol (it was a struct);
  `_ViewBridgeLoader` is the SDK's `AnyObject` protocol (it was a struct, and its `handler` seam is gone);
  `EntityQueryProperty` is the SDK's final class over five generics, inheriting
  `EntityQueryPropertyDeclaration`, which lost its `property` member.
- Carried: the 15 keypath-parameter initializers of `IntentPrediction`, as the skeleton declares them. They
  keep `parameters`; their display representation is nil, since the closure needs the intent's values, which
  the port does not have when it predicts. The closure initializer stores its closure, `@escaping` as the SDK
  declares it. The skeleton has no initializer on `TupleIntentPrediction`, so the package's closure initializer
  there, which the SDK does not declare, is removed (a later commit); the type is an empty struct with the SDK's
  generics and conformances.
- Not carried: the signature-level differences of every other container (the member pass is not run yet).
