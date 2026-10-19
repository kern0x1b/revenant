# The seams: where the system side of AppIntents is not on these releases

Every declaration of the framework exists in the module. What does not exist on iOS 6.1.3 (or 4.3, or
7.x) is the system service behind some of them. Each is named here, with what the module does instead
and what a caller reads back. Nothing here pretends to have drawn, indexed, phoned or run anything.

## Siri, Shortcuts, Spotlight, widgets, live activities

These are services, not frameworks: a daemon the release does not run, reached over XPC. The port
cannot run them, and a caller that wants one installs the handler the module names. Measured:
`~/.charon/dyld/6.1.3/` holds no `Siri`, `Shortcuts`, `knowledge` or `chronod` image, and the release's
own `SpringBoard` has no `SBIntents` class - the surfaces a shortcut would be reached through are all
of iOS 9 and later.

| the framework's call | the module's answer | the value a caller reads |
| --- | --- | --- |
| `AppShortcutsProvider.updateAppShortcutParameters()` | writes the app's shortcuts into `CharonShortcutStore` | `CharonShortcutStore.shared.appShortcuts()`, `.phrases()` |
| `IntentDonationManager.donate(intent:result:)` | appends an `IntentDonation` to a plist under Application Support | `IntentDonationManager.shared.donations()` |
| `IntentDonationManager.deleteDonations(matching:)` | removes from the same plist what the predicate matches | the store, read back |
| `RelevantIntentManager.updateRelevantIntents(_:)` | writes a plist beside the donations' | `RelevantIntentManager.shared.relevantIntents()` |
| `AppIntent.requestConfirmation(...)` | the request is handed to `IntentConfirmationRequest.handler`; with no handler the run continues as the caller asked | the handler's own answer |
| `AppIntent.requestChoice(between:dialog:)` | `IntentChoiceRequest.handler`; with no handler the first option | the handler's own answer |
| `OpenURLIntent.perform()` | `CharonURL.open(_:)` hands the URL to `CharonURL.handler` | the handler's own answer |
| `SetFocusFilterIntent.current` | `nil`: these releases have no focus filters, which is the framework's own answer for a device without them | `nil` |
| `CSSearchableIndex.indexAppEntities(_:priority:)` and its two deletes | not in the module: the rows are AppIntents' own extensions on the three CoreSpotlight classes, which the port's headers (`tools/gen/cmd_headers.lua`) are what make visible to Swift. The classes themselves are carried by the CoreSpotlight backports, and the AppIntents side of that seam is left for the round that brings the port's headers to CoreSpotlight | - |
| `NSUserActivity.widgetConfigurationIntent(of:)` and `.appEntityIdentifier` | not in the module: the same seam, for UIKit's iOS 17 `widgetConfigurationIntent` | - |
| `_ViewBridgeLoader.loadBridge()` | the SDK's protocol requirement; no conformer is carried, since the framework's own bridge is a SwiftUI loader and these releases have no SwiftUI | none: the requirement is declared and nothing answers it |
| `SnippetIntent.reload()` | the snippet's own call; the view behind it is the app's | - |

## The macros

`AppEntity(schema:)`, `AppIntent(schema:)`, `AppEnum(schema:)` and the three assistant ones,
`ComputedProperty`, `DeferredProperty` and `UnionValue`, are declared as the framework declares them,
with `#externalMacro(module: "AppIntentsMacros", ...)`. Expanding one needs the framework's own macro
plugin, which is not in the SDK's binaries for any release this port builds for: the plugin is a
swift-syntax executable the framework builds, and `AppIntentsMacros` is a module of its own with no
`.swiftinterface` in the 26.2 SDK either. A port therefore writes the conformance out, which is what
the macro attaches. `Macros.md` says what each one expands to.

## The unit and control-style enums

`IntentParameter`'s unit enums are plain case enums: the framework's own are `Measurement`'s
`UnitLength` and its siblings, and a parameter's `unit` is the case the app named. Their cases are the
framework's own list, in the framework's own order, and a case hashes as its place in that list.

## What is a real value here

`AssistantSchema.IntentSchema("OpenURLInTabIntent")` is a real value: the framework's own schema of a
system intent is its name, whether or not the app behind it is installed. The system apps (Books, Mail,
Photos, Safari, Files) are not on these releases, so what a schema names is not there - the schema is,
and the run behind it is the app's own to provide. That is the framework's own answer as well: a
schema of an intent whose app is absent is still its name.

## Where the module stops, and why

A Swift value of an arbitrary type has no honest zero, so where a declaration needs a value it has
not got, the read stops with a message that names what was read and where. That is the framework's own
answer at the same places - `AssistantSchema` reads
`fatalError("Do not reference schema types directly")`, `Never` is uninhabited, a parameter and a
property are made by their initializers, and a control's `perform()` returns nothing. The module does
the same and says more:

| where | the read that stops | why there is no value |
| --- | --- | --- |
| `AppDependency.wrappedValue` | the dependency that was never added to the `AppDependencyManager` | the manager holds what the app put there, and a key it never got has nothing to read |
| `IntentParameter.wrappedValue` | a parameter before the framework filled it in | the value is the caller's; the framework's own `requestValue` is the read that asks |
| `EntityProperty.wrappedValue` | a property the app gave no value for | the value is the entity's; the getter the app gave is the read |
| a comparator declared with a mapping and no value | its `value` | there is nothing to compare before the query runs, which is what the framework's own declaration means by it |
| `EntityQueryProperty` declared with no provider (the convenience init) | reading its entity stops | the query reads the entity through the provider it was given, when the keypath init is used |
| `CharonURL.placeholder` | a URL string that is not one | a URL is not a string every time, and a caller that writes a broken one gets the scheme's own empty URL rather than a crash |
