# revenant@swift-data

The SwiftData module for the port's armv7 releases: a Swift module named `SwiftData`, built
against the `revenant@swift-runtime` a port carries, so a program writes `import SwiftData`. It does
not build today: `revenant@swift-data` refuses on load, because `DefaultStore.swift` imports
`FoundationEssentials`, which the iOS 6 SDK does not provide.

The storage is the release's own Core Data - `NSPersistentContainer` and
`NSPersistentStoreDescription` from iOS 6.0, the backports' `NSPersistentHistory*`,
`NSPersistentCloudKitContainer`, `NSBatchDeleteRequest` and `NSFetchIndexDescription` below it -
and this package is the SwiftData API as a layer over it.

What is measured about that substrate, and what the port does and does not have, is in
`docs/reference/backports/SwiftData/Substrate.md`. Two things a caller should read there first: a Swift module
cannot be built for the 4.3 band (the runtime's own `Swift` module has a floor of iOS 6.0, because
every Core Data backport entry has `minimum: 6.0`), and `FetchDescriptor`'s predicate and sort
order are `Foundation.Predicate` and `Foundation.SortDescriptor`, which arrive with
`revenant@swift-foundation` and are not on the port yet.

## State of this package

**All 584 of the corpus's SwiftData rows are carried.** The last two were the history:
`ModelContext.fetchHistory(_:)` and `ModelContext.deleteHistory(_:)`, over the backports'
`NSPersistentHistory*` and the `HistoryProviding` conformance the review's first round called a
stub. The **seven** macros are declared with Apple's own `@attached`
roles and compile with no plugin on the machine, because `#externalMacro` is only resolved when a
macro is *used*.

All seven are `kind=function` rows, `Model()` among them: the corpus records a macro as a function
whatever it attaches, so `@Model` is a `function` row and not a `class` row — `@attached(member)`
generates a class, and the row's kind is about how the API table records the declaration, not what
the expansion produces.

**What is not done is the expansion, not the API.** `SwiftDataMacros` - the host executable
`@Model` and the rest expand through - is not written, and it is waiting on `revenant@swift-syntax`
(6ae40d50), which publishes the host compiler and the swift-syntax build a plugin is compiled
against. The rule that builds a plugin from sources is `toolchain/rules/macro/xmake.lua`, from that series;
this package will name it and nothing more.

Built, measured: `swiftc -target armv7-apple-ios6.1.3` over the whole module, the swift-runtime
built with the Core Data backports and swift-foundation's `FoundationEssentials` and
`FoundationInternationalization` on the search path: **0 errors**, a `Mach-O object arm_v7` of
**895464 bytes, 2836 defined and 433 undefined symbols**, the ten swift-foundation ones named in
`docs/reference/backports/SwiftData/Substrate.md` and in `on_test`. `-wmo -c` on its own writes that object;
the bitcode wrapper an earlier run produced came from asking for the module interface in the same
invocation, and a `-emit-library` link of it "succeeded" into a 16428-byte library with **zero**
defined symbols - which is how the check that now prints the counts came to exist.

The link is **not** finished, and for one reason only. The 433 undefined symbols of this build, as
`frameworks/Backports/tests/SwiftData/harness/symbols.lua` prints them, and they add up:

| count | what it is waiting for |
| --- | --- |
| 180 | the Swift runtime and the standard library, both in `libswiftCore`, which a program links |
| 162 | C symbols the frameworks carry |
| 36 | objc classes and metaclasses the frameworks carry |
| 34 | the port's own `Foundation` overlay |
| 7 | `Observation`, the runtime's own |
| 8 | `FoundationEssentials` |
| 3 | `FoundationInternationalization` |
| 430 | everything above |
| 3 | the classifier reading a mangled *generic parameter* as a module name: `_$s5Index…`, `_$s6Element…`, `_$s8Iterator…` are `Index`, `Element` and `Iterator`, not modules. A name it cannot place is counted, not dropped, so the total holds |
| **433** | |

The **11** swift-foundation ones are 8 + 3: `Predicate`, `SortDescriptor`, `Date`, `UUID`. They are
swift-foundation's, and f25214c6's run typechecked the module without linking it, so
`lib_FoundationEssentials.dylib` does not exist anywhere. Every other import of this module resolves
against the runtime and the Core Data backports. The harness names **ten** of them one by one in
`frameworks/Backports/tests/SwiftData/harness/symbols.lua`, and `on_test` fails when one of those
stops being undefined or when a swift-foundation symbol it does not name appears; the object this
table was measured from has eleven, so that check fails on it until the build is re-measured and the
list and the count are settled together.

**Which build verifies this package.** `swift-data` is in no `LIBRARIES` and no gate config, so
**the backports gate never builds it** - a green gate says nothing about it. Two things verify it,
and they are different jobs:

- the **armv7 build** is `./xmakew l -P . frameworks/Backports/tests/SwiftData/harness/build.lua <release>`, which runs the flags
  `modules/apple/swift.lua runtime_flags` builds, compiles the whole module, hands the object to
  `frameworks/Backports/tests/SwiftData/harness/symbols.lua` for the counts, and links it against a built
  `libCoreDataBackports.dylib`. Where the toolchain, the runtime and swift-foundation's two modules
  are is a fact about one machine's store and not about the package, so the script takes them in
  the environment and **names every variable it needs when one is missing**. At this tip, for
  `6.1.3`:
  ```
  COMPILE ERRORS 0
  OBJECT  SwiftData.o  895464 bytes  Mach-O object arm_v7
  SYMBOLS defined=2836 undefined=433
  ```
- the **committed check** is `xmake l frameworks/Backports/tests/SwiftData/harness/symbols.lua` with
  `REVENANT_SWIFTDATA_OBJECT` naming an object or the installed `libSwiftData.a`, which prints the same
  `SYMBOLS` and `UNDEFINED` lines and runs the ten-symbol check; and the package's `on_test`, which
  runs that check on what it installed. Its control is the same file with
  `REVENANT_SWIFTDATA_CONTROL=1`, which is how the check is shown to fail.

And the build is against swift-runtime `29dd4454` (recipe digest `875c24e4...`), while this tree
at `4d2e24e7` produces `0ccce571...` - the digest 4d2e24e7 regenerated for the backports' UIKit
7-12 and CarPlay series, which are `backports.lua` changes and so can move the port's headers. The newest
`backports=true` swift-runtime in the store is from 04:34 today, built against the older digest.
**This build has to be re-measured against the runtime this tree produces, and that is a long
job, not a quick one.**

Wired to the store, and the two places are where the wiring is: `DefaultStore` conforms to
`HistoryProviding` and holds `fetchHistory` and `deleteHistory` at
`frameworks/Backports/src/SwiftData/DefaultStore.swift:263`, and `ModelContext.fetchHistory` and
`deleteHistory` hand the descriptor to the store at
`frameworks/Backports/src/SwiftData/ModelContext.swift:254`. What is still missing is
`@Model`'s expansion: the seven macro names are declared and the module builds without any plugin, but
a program that writes `@Model` needs `SwiftDataMacros`.

The differential so far is one case, and it is measured on both sides: a probe model, `MissingValue.swift`, that is not kept in the repository is compiled against Apple's SwiftData on the host and typechecked against this
module for armv7, and the host's answer to a value the schema requires and the row does not hold
is a trap with those words - see `docs/reference/backports/SwiftData/Substrate.md`.
