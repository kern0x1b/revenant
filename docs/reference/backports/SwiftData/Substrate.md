# What the port gives SwiftData, measured

Every line here is the output of a command run on 2026-09-28 in
(a workflow file kept outside the repository), against the packages as they are in the shared
store. The probe that reads them is `.agent-work/probe/` in the same worktree.

The toolchain, resolved once: `revenant@swift 6.4.0` at
`~/.xmake/packages/s/swift/6.4.0/f1d0e4f9eebe477396350986a88081e5` (`Apple Swift version 6.4
(swift-6.4-RELEASE)`), and `revenant@swift-runtime 6.4.0` at
`~/.xmake/packages/s/swift-runtime/6.4.0/29dd4454302f478db10876dc0bffa673`
(`configs.backports = true`, `REVENANT_SWIFT_RUNTIME_BACKPORTS = "coredata"`).

## Macro plugins can be built on this toolchain

`ls $SWIFT/lib/swift/host/plugins`:

```
libObservationMacros.dylib
libSwiftMacros.dylib
```

`ls $SWIFT/lib/swift/host` also carries `SwiftSyntax`, `SwiftSyntaxBuilder`,
`SwiftSyntaxMacros`, `SwiftSyntaxMacroExpansion`, `SwiftParser`, `SwiftDiagnostics`,
`SwiftCompilerPluginMessageHandling`, `SwiftBasicFormat`, `SwiftOperators`, `SwiftIDEUtils`,
`SwiftLibraryPluginProvider`, `SwiftIfConfig`, `SwiftWarningControl`, `SwiftRefactor` - a host
module each, with its dylib.

`packages/s/swift/xmake.lua:124-129` is what builds them (`SWIFT_BUILD_SWIFT_SYNTAX=ON`, the
`swift-syntax-lib` install component, and the `SwiftMacros`/`ObservationMacros` ninja targets),
and `packages/s/swift-runtime/xmake.lua:149` hands the directory to a port as
`SWIFT_PLUGIN_PATH`, which `rules/swift/xmake.lua:182` passes to every port compile as
`-plugin-path`.

**So `@Model`, `@Attribute`, `@Relationship`, `@Transient`, `@Unique`, `@Index` and `@ModelActor`
can be implemented, not stubbed.** What is missing is one line: `toolchain/rules/swift/xmake.lua` reads the
plugin path from the swift-runtime package alone (line 182), while it already collects every
dependency's `REVENANT_SWIFT_MODULES` (lines 170-176). A `SwiftDataMacros` plugin therefore needs
the same loop for a `REVENANT_SWIFT_PLUGINS` the package exports. Without it a port cannot load a
plugin of ours, and installing the plugin into the compiler's own directory would be a write
outside our package, where two builds of it would fight over one file name.

## `Foundation.Predicate` and `Foundation.SortDescriptor` are not on the port yet

`$SWIFTC <port flags> -typecheck` of one file per name:

```
want_codable_url       FOUND
want_partialkeypath    FOUND
want_predicate         MISSING: cannot find type 'Predicate' in scope
want_sortdesc          MISSING: cannot find type 'SortDescriptor' in scope
want_sortorder         MISSING: cannot find type 'SortOrder' in scope
want_valuetransformer  FOUND
```

They are not ours to add. The corpus assigns both to `swift-foundation`
((a workflow file kept outside the repository), `via = swift-foundation`, `owner-registry =
swift-foundation`, `registry = swiftlang/swift-foundation:Sources/FoundationEssentials/Predicate/
Predicate.swift` and `.../FoundationInternationalization/String/SortDescriptor.swift`), and
(a file of an earlier layout, not in the repository) - the toolchain package that builds them, work in progress in
`.agent-work/worktrees/api-foundation-swift` - is not in the shared store.

Eight rows depend on those two types and are therefore not in this delivery:
`FetchDescriptor.init(predicate:sortBy:)`, `FetchDescriptor.predicate`, `FetchDescriptor.sortBy`,
`DataStoreBatchDeleteRequest.predicate`, `HistoryDescriptor.predicate`, `HistoryDescriptor.sortBy`,
`HistoryDescriptor.init(predicate:)`, `HistoryDescriptor.init(predicate:sortBy:)`.

The predicate is also not translatable into an `NSPredicate` from outside swift-foundation: the
node types of `PredicateExpression` are internal to it, and the only public way to run one is
`Predicate.evaluate(_:)`. A fetch whose descriptor carries a predicate would filter in memory with
`evaluate(_:)`, which is what `DataStoreError.preferInMemoryFilter` documents.

## What Core Data of the release, and of the backports, carries

A Swift probe against the backports-built runtime at `armv7-apple-ios6.1.3` compiles, so these are
all callable from Swift at that release: `NSPersistentStoreDescription`,
`NSPersistentCloudKitContainer`, `NSPersistentCloudKitContainerOptions(containerIdentifier:)`,
`NSPersistentHistoryChangeRequest.fetchHistory(after:)`, `NSPersistentHistoryChange`,
`NSPersistentHistoryTransaction`, `NSManagedObjectContext.transactionAuthor`,
`-[NSManagedObjectContext executeRequest:error:]`, `NSBatchDeleteRequest`, `NSFetchIndexDescription`,
`NSEntityDescription.indexes`, `NSAttributeDescription.valueTransformerName`,
`NSAttributeDescription.attributeValueClassName`, `allowsExternalBinaryDataStorage`,
`NSManagedObjectID.uriRepresentation`, `NSManagedObjectID.isTemporaryID`, `undoManager`.

Three that the registry does **not** carry, read out of the port's headers (the CoreData framework's headers
in the runtime's port overlay, `REVENANT_SWIFT_PORT_HEADERS`):

| name | mark still in the port's header | registry |
| --- | --- | --- |
| `NSEntityDescription.uniquenessConstraints` | `API_AVAILABLE(macosx(10.11),ios(9.0))` | (a workflow file kept outside the repository): `status: absent` |
| `NSPersistentStoreDescription.cloudKitContainerOptions` | `API_AVAILABLE(macosx(10.15),ios(13.0),...)` | (a workflow file kept outside the repository): `status: inert` |
| `NSPersistentCloudKitContainerOptions.databaseScope` | `API_AVAILABLE(macosx(11.0),ios(14.0),...)` | (a workflow file kept outside the repository): `status: absent` |

Their own `reason` fields say why, and they are right: a uniqueness constraint the store of iOS 6
cannot enforce would let in the duplicates the model forbids, and no release this port runs on has
CloudKit, so there is no database for a scope to name and nothing to mirror. That is a wall at a
seam, not a gap in the surface: `Schema.Unique` keeps its constraints in the
schema and `ModelContext.save` enforces them, and `ModelConfiguration.cloudKitDatabase` decides the
store's kind and is readable, while the mirroring it asks for is the wall.

## `NSUUIDAttributeType` does not exist at 6.1.3, and nothing carries it

`NSAttributeDescription.h:30` of SDK 26.2:

```
NSUUIDAttributeType API_AVAILABLE(macosx(10.13), ios(11.0), tvos(11.0), watchos(4.0)) = 1100,
```

and no file under `the deleted registry package registry/` carries it (grep: no match). The
pilot's draft stored a `UUID` as a string and said "on iOS 6"; the reason is iOS **11**, not the
release. The type-preserving answer at 6.1.3 is `NSTransformableAttributeType`
(`NSAttributeDescription.h:32`, `ios(3.0)`) with a value transformer, which is what
`Schema.Attribute.Option.transformable(by:)` is for.

## `registeredObjects` is iOS 3.0

`NSManagedObjectContext.h:157-160` declares `insertedObjects`, `updatedObjects`, `deletedObjects`
and `registeredObjects` with no availability of their own, inside a class available from
`ios(3.0)`; the release has had them since the first version of Core Data. The pilot's claim that
iOS 6 has no `registeredObjects` is false, and `ModelContext.insertedModelsArray` is built on
`insertedObjects`.

## A Swift module cannot be built for the 4.3 band

One probe file, four runtime/deployment pairs, `-typecheck`:

```
runtime=0731ba0a deployment=4.3   FAIL: compiling for iOS 4.3, but module 'Swift' has a minimum deployment target of iOS 6.0
runtime=29dd4454 deployment=4.3   FAIL: compiling for iOS 4.3, but module 'Swift' has a minimum deployment target of iOS 6.1.3
runtime=0731ba0a deployment=6.0   OK
runtime=29dd4454 deployment=6.0   FAIL: compiling for iOS 6.0, but module 'Swift' has a minimum deployment target of iOS 6.1.3
runtime=29dd4454 deployment=6.1.3 OK
```

The floor is the `Swift` module of the runtime itself, and it is a property of the runtime and of
the Core Data backports under it: every entry of (a workflow file kept outside the repository) and of
`registry/CoreData/*.json` has `"minimum": "6.0"`, so there is no `CoreDataBackports` for a band
below 6.0 and the runtime's Core Data overlay cannot be built for one. A module that imports Core
Data - which is all of SwiftData - exists therefore for the 6.0 and 6.1.3 bands and not for 4.3.
Moving that floor is the Core Data band's call, not this package's.

## The overlay is keyed by the exact SDK path

The port's headers are a VFS overlay keyed on the SDK's full path, and there are sixteen installs
of `iphoneos-sdk/16.4` (one per the package's `additions` digest). A probe that picks an SDK by
hand reads unlowered headers and reports the backports' API as unavailable - which is exactly what
happened here first, and the fix is to read the SDK out of the overlay:

```
SDK=$(python3 -c 'import json,sys; o=json.load(open(sys.argv[1])); print(next(r["name"] for r in o["roots"] if r["name"].endswith("CoreData.framework/Headers"))[:-len("/System/Library/Frameworks/CoreData.framework/Headers")])' "$REVENANT_SWIFT_PORT_HEADERS")
```

A package's own build resolves the SDK from the toolchain, so a store whose SDK differs from the
runtime's would compile the module against unlowered headers; `on_test` should assert the
overlay's root and the build's `sdkdir` are the same path.

## The model executor: where a job runs, and what is not measured

`DefaultSerialModelExecutor` enqueues a job with

```swift
let unowned = UnownedJob(job)
let serial = self.asUnownedSerialExecutor()
context.perform { unowned.runSynchronously(on: serial) }
```

`UnownedJob(job)` is the standard library's own form of a job that is copyable and escapable: an
`ExecutorJob` is noncopyable and `~Escapable`, so `context.perform { job.runSynchronously(on:) }`
is rejected at SILGen with *"noncopyable 'job' cannot be consumed when captured by an escaping
closure"* — and a **typecheck does not diagnose that while the compile does**, which is how the
module was once green under `swiftc -typecheck` and not under `swiftc -c`. The compile is the check
that matters for this file.

`context.perform`, and not a `DispatchQueue` of the executor's own, because one queue is what
serialises the actor's work against the context's own operations. A second queue is the bug: a job
could read a row while the context was saving it. The release has **no way to ask an
`NSManagedObjectContext` for its queue** — `perform` and `performAndWait` are the whole of it — so
`perform` is the answer rather than a fallback.

**Where this differs from Apple's.** Apple's `DefaultSerialModelExecutor` is declared over the same
`ModelContext`, and the interface gives no way to see which queue it uses, so whether it uses the
context's or one of its own is not measurable from the interface — only the code, which is closed.
This port uses the context's. The observable consequence either way: a job runs off the caller's
thread, and a job that touches the context's rows does so on the same queue the context saves on.

**What is NOT measured.** That the job *in fact* runs on the context's queue. The compile says the
code is well formed; it does not say which queue the closure lands on. A probe for it needs a real
job, which means an actor using this executor and a way to read back the thread; the first draft of
one needed API that does not exist (`ExecutorJob` cannot be constructed from outside) and was
deleted rather than shipped looking right. So the claim rests on `perform` being the context's
queue, which is what its documentation says, and on this port's code **not** being run — the run is
the 6.1.3 emulator step, after `lib_FoundationEssentials.dylib` and the v0.8.14 runtime
re-measurement. A job on the wrong queue would show up there as a Core Data concurrency violation
or a hang, which is a run and not a typecheck.

## What the link still wants, and how it is watched

`swiftc -c` over the module for `armv7-apple-ios6.1.3` gives a `Mach-O object arm_v7` of 867740
bytes: **2786 defined, 425 undefined**. Of the undefined, 118 are the Swift standard library's and
62 the Swift runtime's (both in `libswiftCore`, which a program links), 39 are objc classes and C
symbols the frameworks carry, 6 are `Observation`'s, 3 the port's own `Foundation` overlay — and
**exactly 10** are swift-foundation's, which is `lib_FoundationEssentials.dylib`, which does not
exist because f25214c6's run output is its typecheck-only `check.sh` path:

```
_$s20FoundationEssentials9PredicateV8evaluateySbxxQpKF   ModelContext.fetch
_$s20FoundationEssentials9PredicateVMa / VMn              FetchDescriptor.predicate
_$s20FoundationEssentials4DateVMn                         HistoryTransaction.timestamp
_$s20FoundationEssentials4UUIDVACycfC / UUIDVMn          EditingState
_$s20FoundationEssentials4UUIDVSHAAWP                     EditingState: Identifiable
_$s30FoundationInternationalization14SortDescriptorV7keyPaths...   FetchDescriptor.sortBy
_$s30FoundationInternationalization14SortDescriptorVMa / VMn
```

The package's `on_test` names all ten, so the day the library lands — or the day one of them stops
being used — that is a failure with a name rather than a link that moved for a reason nobody wrote
down.

## `DefaultHistoryTransaction` is a public name of Apple's, and the port declares one too

The host's own SwiftData **ships `DefaultHistoryTransaction`**, and `ModelContext.fetchHistory`
answers `[SwiftData.DefaultHistoryTransaction]`. Measured on the host, from
`arm64e-apple-macos.swiftinterface` of the Command Line Tools SDK (Swift 6.4, macOS 27):

```
public typealias HistoryType = SwiftData::DefaultHistoryTransaction
final public func fetchHistory(_ descriptor: SwiftData::HistoryDescriptor<SwiftData::DefaultHistoryTransaction>) throws -> [SwiftData::DefaultHistoryTransaction]
```

So the port is not inventing a type where Apple has none: it is **re-declaring a public name** with
its own members, over Core Data's `NSPersistentHistoryTransaction` rather than over Apple's store.
Under R4 that is a name the port adds, and a program that imports both would see two of them.

The corpus asks for it, so the name is right — `DefaultHistoryTransaction`'s own rows are in
`sdk-26.2-surface.tsv` and Apple's interface declares it. What the port adds is a second definition
of the same name, and the one fact that keeps it honest: a transaction's identity here is the
release's `NSPersistentHistoryTransaction.transactionNumber`, the store identifier is its `storeID`,
and a token is that number per store — so the two are the same values read from the release rather
than Apple's own encoding. A program that only ever goes through this port's `ModelContext` cannot
tell them apart; one that mixed the two would, and that is the divergence the facts name.

The oracle for the history family ((a workflow file kept outside the repository)) uses the **bare** name on
purpose: it resolves to whichever module is in scope, which is what lets one source be both Apple's
program and the port's.
