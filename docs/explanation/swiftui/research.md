# SwiftUI and Combine on iOS 6 (armv7): research

Date: 2026-09-17. Paths in the text are from the repository root.
Everything marked "verified" was run on one machine (macOS, the emulator, an iPhone 4S and an iPad 2 on iOS 6.1.3).
The raw output of the firmware-cache analysis does not go into the repository: it contains symbol lists from
Apple's binaries. Estimates are marked separately.

## 1. Verdict

| Direction | Outcome |
|---|---|
| A. Port Apple's real SwiftUI to iOS 6 armv7 | **Not feasible.** The barriers are listed in section 2 with their numbers. None is passable with reasonable work, and together they add up to porting half of iOS 13 to 18. |
| B1. OpenCombine as the Combine implementation | **Works now.** Built for armv7 iOS 6 on the full Swift 6.4 runtime; 1437 of its 1453 own tests pass on the emulated iOS 6.1.3. |
| B2. OpenSwiftUI as the base of our own SwiftUI | **Not usable as a base; usable as a reference on how the real one is built.** The package requires iOS 18 and runs only on Apple's AttributeGraph or a third-party Compute, and Button, List, NavigationView and ScrollView are not implemented in it yet. |
| C. Run ready-made SwiftUI apps through the recompiler, with our implementation in place of Apple's framework | **Open, but the surface is reproduced completely** (section 2.3): an app built against Apple's interface links against ours with no unresolved symbols. The work is not proven; the probe is behind the recompiler. |
| B3. Our own SwiftUI implementation on top of iOS 6 UIKit | **Feasible, proven by a prototype.** 1465 lines of Swift give an app written in SwiftUI syntax that builds from source for armv7 and looks like a native iOS 6 app (screenshots below). The graph engine is also checked on hardware: 2.8 ms for a full screen update on an iPhone 4S. |

The recommended first step is section 8.

## 2. A. Apple's real SwiftUI

### 2.1 What it consists of (facts from the firmware caches, the toolchain module `apple.dyld`)

Verified on the local caches in `~/.revenant/dyld` (the analysis scripts and their output are not kept in the repository).

- **SwiftUI has never had an armv7 slice.** None of the 32-bit caches, up to the last 32-bit release 10.3.4, contains
  the `SwiftUI` or `Combine` images. In 16.0 and 18.0 the cache is arm64e only (26 caches). SwiftUI appeared in iOS 13,
  and the last system with an armv7 slice is 10.3.4, so there is no overlap in principle.
- **The stack's makeup (iOS 18.0).** `SwiftUI` (18.8 MB `__TEXT`) on top of `SwiftUICore` (11.4 MB), `AttributeGraph`
  (0.3 MB, the dependency-graph engine), `RenderBox` (1.3 MB, drawing), `CoreUI`, `CoreSVG`, `SFSymbols`,
  `CoreMaterial`, `UIFoundation`, `UIKitCore`, `Combine`, `CoreText`, `QuartzCore`, plus 40 Swift overlays in
  `/usr/lib/swift/*`. In 16.0 it is the same, without a separate SwiftUICore.
- **The transitive closure of dependencies:** 546 images, 616 MB `__TEXT`. Of these, **407 images and 402 MB** are
  missing from 6.1.3 (for 16.0, 444 images, of which 312 are missing).
- **Imports.** SwiftUI and SwiftUICore import 11,653 symbols, of which **10,907 are missing from 6.1.3**.
  Even counting only the ordinary frameworks: 610 of 720 from UIKitCore (`UIAlertController`, `UIAction`,
  `NSCollectionLayout*`, `UIAccessibilityCustomRotor`...), 94 of 156 from CoreText (private
  `CTFontDescriptorCreateWithTextStyleAndAttributes`, `CTFontGetLanguageAwareOutsets`...), 45 of 72 from libobjc
  (`objc_alloc`, `objc_opt_*`, `objc_release_x*`, the register entry points of ARC64), and 45 of 117 from QuartzCore.
- **Metal is required.** `RenderBox` imports 32 Metal symbols (`MTLCreateSystemDefaultDevice`, the classes
  `MTLBinaryArchiveDescriptor`, `MTLCaptureManager`...). A neighbouring project's Metal driver for the SGX543 (A5) does
  not exist in any firmware, and Metal cannot be expressed on GLES 2.0. This is a separate, independent blocker.
- **The size of the ABI.** SwiftUI exports 17,534 symbols and SwiftUICore 33,260 (50,794 in all, 50,380 of them Swift
  symbols), including 2,648 nominal type descriptors and 390 protocol descriptors. AttributeGraph has 722 and Combine 2,016.

### 2.2 Possible routes, and why they are closed

1. **Binary translation from arm64 to armv7 (the recompiler).** The recompiler project brought the "C/ObjC utility" and
   "UIKit app in ObjC" levels to PASS, but its Swift level is **blocked by the object model**: guest Swift needs an
   8-byte `isa`/`superclass` at the same address where the host's objc4 needs a 4-byte one, and the same bytes 4..7 must
   be at once the high half of the guest isa and the host superclass. SwiftUI is 50 thousand Swift symbols and classes
   that inherit from UIViewController and UIView, which is exactly the most blocked case.
2. **"Supplying" the binaries from a firmware.** Beyond the object model: 407 missing images (402 MB) against the 512 MB
   of RAM in an iPhone 4S; Metal; private dyld SPI (`dyld_program_sdk_at_least`), which iOS 6's dyld does not have; the
   iOS 13+ ObjC ABI (register `objc_release_x*`, tagged pointers, `objc_opt_*`); CoreText and UIFoundation from another era.
3. **The legal framework.** Even if it worked, the toolchain does not distribute Apple's binaries. Only the model in which
   "the user takes the files from their own firmware" is acceptable (as Spire does); downloading firmware is allowed. This
   does not affect the verdict, because the route is closed technically.

**Conclusion on A: not feasible.** Not "hard", but impossible without full emulation of a 64-bit system: there is no
slice, no Metal, no object model, and 400 MB of missing images.

### 2.3 What the app itself requires from SwiftUI (measured, 2026-09-17)

The verdict of section 2.2 concerns porting Apple's framework. The separate question is what an app needs, and the
answer is different. Details and commands: `guest-bridge.md`.

The test app (`@main App`, `NavigationView`, `List`, `ForEach` over `Identifiable`, `NavigationLink`, `Toggle`, `Button`,
`Text` with interpolation, `@State`, `@StateObject`, `@Published`, `navigationTitle`), built against `SwiftUI.swiftinterface`
from SDK 16.4 for arm64, requires **127 symbols**: 64 from SwiftUI, 12 from Combine, 14 from the stdlib, and the rest C
and ObjC. Of the 64 SwiftUI symbols, 35 are functions and initializers and 29 are metadata. There is neither framework
code nor layouts of its types in the app: SwiftUI is resilient, the app's type metadata is built at run time, and the
whole graph goes through three entry points, `View._makeView`, `_makeViewList` and `_viewListCount`. The app does not
import the `_ViewInputs`, `_GraphValue` and `_ViewOutputs` types at all.

The protocol shapes were taken from the firmware caches and are the same in iOS 16.0 and 18.0: `View` has 6 requirements,
in the order "access to the conformance `Body: View`, access to the associated type `Body`, `_makeView`, `_makeViewList`,
`_viewListCount` (all three with default implementations), the getter `body`"; `App` has 4 requirements.

Our implementation, built for arm64 with the same compiler, covers this surface: 36 of the 64 symbols matched at first;
after aligning the shapes (`LocalizedStringKey`, the `View` entry points, `List<SelectionValue, Content>`, `ForEach`
without the `Content: View` constraint on the type itself, `ObservedObject.Wrapper`, alignment and builders as structs),
58; and with `-enable-library-evolution` (without it the compiler emits no method descriptors), **64 of 64**. The app was
then linked against our implementation: zero unresolved SwiftUI symbols.

That gives the architecture for the recompiler: the guest side is the app plus our SwiftUI built for arm64, plus the
guest's libswiftCore, all translated by its pipeline; the host side is 3 to 5 ObjC shims (a host `UIViewController`, a
table data source, a target-action object) and its bridges to UIKit. The object-model blocker does not arise in that
case: guest classes inherit not from Apple's classes but from these shims, and the recompiler already handles that case
in its ObjC app.

What the measurement does not prove: that the app works. Linking checks names and shapes, not behaviour; nothing was run.
The first real answer comes from the recompiler's probe: this same app, translated to armv7, on the screen.

## 3. B1. OpenCombine: verified

Source: `OpenCombine/OpenCombine` (MIT, last commit 1c6f02c, 2023-10). No dependencies except a small C++ helper.

Built with a script that no longer exists (the recipe of the package `revenant@combine` builds it now): Swift 6.4
(`revenant@swift`), `-target armv7-apple-ios7.0`, the runtime and overlays of the Swift overlay project's trial builds,
linked for iOS 6.0, install name `@executable_path`. The toolchain's import check against the 6.0 and 6.1.3 caches gives
**0 strong missing**.

Tests: 1453 upstream tests (`URLSessionTests.swift` is excluded, because it inherits from `NSURLSession`, which is
iOS 7) run through our own XCTest shim (233 lines; now `frameworks/Combine/tests/XCTest.swift`, and the test list is
collected by `frameworks/Combine/tools/discover.lua` for the `CombineTests` target).

| where | tests | passed | failed | crashes |
|---|---|---|---|---|
| host, macOS arm64 | 1469 | 1464 | 5 | 0 |
| iLEmu, iPhone4,1, iOS 6.1.3 | 1453 | 1437 | 1 | 15 |

The single failure on iOS 6 (`MapKeyPathTests.testMapKeyPathReflection`) reproduces on the host too: the test compares
reflection text that changed in newer Swift.

Crashes (one per run; each was skipped and the run went on):
- 7 × `DispatchQueueSchedulerTests`: a trap in `SchedulerTimeType.Stride.magnitude`. It is `Int(_nanoseconds: Int64)`, and
  `Int` is 32-bit on armv7. **Apple has exactly the same API shape:** in `Schedulers+DispatchQueue.swift` (Apache-2.0)
  `public var magnitude: Int` is the storage itself, and in `Dispatch.swiftinterface` of SDK 16.4
  `public typealias Magnitude = Swift.Int`. So on 32-bit platforms Apple's Combine does not represent intervals larger
  than ±2.1 s either. It comes from `SignedNumeric.Magnitude`. A useful upstream fix: store `Int64`, make the public getter
  `Int(clamping:)`, and guard the magnitude tests with `#if` on the word size. This affects every 32-bit platform of
  OpenCombine (wasm32, armv7 Linux and Android).
- 1 × `DispatchQueue.async(group:qos:flags:)` and 1 × `DispatchQueue.concurrentPerform`: a crash inside iOS 6's libdispatch,
  from the Swift overlay (QoS is an iOS 8 API). Passed to the Swift overlay project.
- 1 × `Dictionary._conditionallyBridgeFromObjectiveC` (the JSONDecoder path): a trap in the overlay. Passed to the Swift
  overlay project.
- 5 × `Timer.tolerance` → the weak `CFRunLoopTimerSetTolerance` (iOS 7) is NULL. Passed to the backports project, which
  **already implements it** (`frameworks/Backports/src/Foundation/NSTimer+Tolerance.m`); the run must be repeated after it is merged.

The current results of the same tests against Combine are in `docs/reference/combine/test-results.md`.

## 4. B2. OpenSwiftUI and OpenAttributeGraph: state

Verified by reading the sources (the upstream OpenSwiftUI at cc24a30 and OpenAttributeGraph at 1d8e762, both MIT).

- **The package's platform is iOS 18** (`Package.swift:900-907`); its public availability floor drops to iOS 13 only
  through macros. It requires swift-tools 6.3, swift-syntax and macros.
- **The graph engine is taken from outside.** `OPENATTRIBUTESHIMS_*` selects Apple's `AttributeGraph`, a third-party
  `Compute`, or `DanceUIGraph`. Its own `OpenAttributeGraph` is a skeleton: `OAGAttribute.cpp` contains 29 TODOs and
  returns `OAGAttributeNil` for creating, reading and writing values, `OAGCompareValues` returns false, and weak attributes
  are TODOs. CI runs only the variant with Compute and the variant with Apple's AG.
- **Drawing.** Everything is written around RenderBox types (`ORBPath`, `ORBDisplayList`, `ORBLayer`: 27 files). Without
  RenderBox, what remains is the CALayer path, `CGDrawingView`: colours, images, `CAShapeLayer` shapes, and text through
  `NSStringDrawing` (with private UIFoundation SPI). `.drawing` elements (Canvas) on this path are a no-op with a TODO comment.
- **Widgets.** There are stacks, `Spacer`, `Divider`, `GeometryReader`, `ForEach`, shapes, `Image`, `Text`, `Toggle`,
  `ProgressView`, `Slider`, `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`, animations,
  `UIHostingController`. **Missing:** `ScrollView`, `List`, `NavigationStack`, `NavigationView`, `NavigationLink`,
  `TextField`, `LazyVStack`, `Grid`, `TabView`, `DragGesture`; `Button` is an empty stub (`Status: Empty`, `body` = `EmptyView`).
- **System requirements in the code.** `UIScene` (64 uses), `_UIUpdateSequenceInsertItem` (an iOS 17 SPI),
  `CAFrameRateRange` (iOS 15), `safeAreaInsets` (iOS 11), `os_unfair_lock` (iOS 10), `AttributedString` (473 uses, iOS 15),
  `dyld_program_sdk_at_least`, SF Symbols, and 63 `@_silgen_name` into private CoreText. For iOS 6, the integration layer
  would have to be rewritten entirely.
- **What is useful in it.** The structure and names of the real SwiftUI's internal mechanisms (ViewGraph, DisplayList,
  DynamicProperty, Semantics), 61 UI snapshot tests, and OpenSwiftUI's document `Docs/SwiftUICompatibilityGaps.md`. As a reference:
  yes. As the base for iOS 6: no.

## 5. B3. SwiftUI: architecture and prototype

### 5.1 Architecture

The module is called **`SwiftUI`**: an app is compiled from sources that start with `import SwiftUI`, without any change to
the text. Combine comes from the package `combine` (`@_exported import Combine` in `src/Core.swift`; OpenCombine, the
upstream of that package, can be built with `-module-name Combine` if wanted).

Layers:

1. **Description**: `View`, `@ViewBuilder` (variadic through parameter packs in Swift 6), `TupleView`, `Group`, `AnyView`,
   `Optional` and `_ConditionalContent` for `if`, `ForEach`.
2. **The node graph**: a tree of `Node`s that mirrors the tree of views: `CompositeNode` (a user View, which holds state and
   computes `body`), `GroupNode` (transparent containers), `LayoutNode` (nodes that own a `UIView`), `ContainerNode`.
   Matching is by position and dynamic type: if the type matches, the node is updated in place; if not, it is recreated.
3. **Dynamic properties**: `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`. The storage lives
   in the node, not in the view value; on each `body` computation the property values are written into a copy of the struct
   at field offsets taken from Swift's metadata (`_forEachField`, a stdlib SPI). This is the same technique Apple uses
   (DynamicPropertyCache) and OpenSwiftUI uses.
4. **Transactions**: a state change marks the node dirty and schedules `DispatchQueue.main.async`. When it is flushed, nodes
   are redrawn from the root to the leaves, descendants of already-redrawn nodes are skipped, then the hosts rebuild their
   `UIView` subtrees and ask for relayout, and lists in which something changed reload their rows.
5. **Layout**: our own model "proposal → size → placement", as in SwiftUI: each node has `sizeThatFits(ProposedSize)` and
   `place(CGRect)`. A stack measures its children's minimum and maximum sizes, sorts them by flexibility and gives the
   remainder to the least flexible first; `Spacer` has a minimum of 8 and infinite flexibility; `padding` and `frame` are
   wrapper nodes.
6. **Mapping to iOS 6 UIKit**: `Text` → `UILabel`, `Button` → `UIButton(type: .roundedRect)` (the same skeuomorphic look),
   `Toggle` → `UISwitch`, `TextField` → `UITextField(.roundedRect)`, `Color` → `UIView`, `List` → `UITableView` with our own
   data source, `NavigationView` → `UINavigationController` as a child controller, `NavigationLink` → a row with a
   disclosure arrow and `pushViewController`, `navigationTitle` → `navigationItem.title`, `App`, `WindowGroup` and `@main`
   → `UIApplicationMain` with our own delegate, and `UIHostingController<Content>` as in Apple's.

### 5.2 What is already done

The module `frameworks/SwiftUI/src/` (the SwiftUI project; the Swift module is still called `SwiftUI`) is about 24,000
lines. The full list of what is supported, ignored and missing is kept in [the ledger](../../reference/swiftui/ledger.md), and it is checked against the build
(`coverage.lua --check`). The count the ledger holds today, over the SwiftUI and SwiftUICore interfaces of SDK 26.2 and
the part Apple declares available on iOS (the slice comes from `tools/apple_names.lua modifiers`): **646 of 1208 types,
289 of 289 `View` modifiers**, of which 202 work, 87 are declared and ignored (each writes a line to the log and to
`/var/revenant/swiftui-ignored.txt`), and no `unimplemented` stubs are left. Over the full interface, including the
macOS, tvOS and watchOS part: 664 types and 311 modifiers, of which 206 work. The list of ignored items is closed: only
things with nothing to match on iOS 6 go there; everything that depended on our engine was turned into working code or
stubs.

The build goes against the package `revenant@swift-runtime` 6.4.0 (the toolchain, main 70c716c), the same runtime the other
ports use, with the target `armv7-apple-ios6.0` and **availability checking enabled**. That found and fixed places the
earlier build, with `-disable-availability-checking`, passed over silently (`CGPathAddRoundedRect`, iOS 7, in the rounded
shapes; `-[NSCalendar component:fromDate:]`, iOS 8). Core Data is available through the package's overlay: `@FetchRequest`
works on top of `NSFetchedResultsController`. Checks: 265 checks of the engine in iLEmu on iOS 6.1.3 and on a live iPad 2
(6.1.3), and 38 snapshot scenarios in the app (iPod4,1 on iOS 6.0), all of which pass. When the runtime moved to the
package, and again when the `needsMount` and `needsLayout` gates were added to the layout, all snapshots matched byte for
byte. The guest build for the recompiler (arm64, library evolution) satisfies 64 of 64 symbols of the test app built
against Apple's SDK.

The engine is incremental: a subtree is not redrawn if the view value has not changed (a byte-by-byte comparison, like
`compareValues` in Apple's code) and the environment is the same.

### 5.3 Probe: the app

`frameworks/SwiftUI/examples/showcase/DemoApp.swift` (246 lines) is an app in ordinary SwiftUI syntax: `@main struct
DemoApp: App`, a `NavigationView` with a `List`, a card with `@State` (a counter, a switch, an input field), a `@StateObject`
model with `@Published`, `@EnvironmentObject` in the rows and on the detail screen, `ForEach` over `Identifiable`, a
conditional view, and a `NavigationLink` to the detail screen.

It is built by the target `SwiftUIDemo` into `SwiftUIDemo.app` (armv7, `MinimumOSVersion 6.0`). The toolchain's import check
against 6.0 and 6.1.3 gives 0 strong missing.

A run in iLEmu (iPod4,1, iOS 6.0, launched through SpringBoard, touches from a scenario, run `app10` of the run script of
the time):

| list | switch | details | favourites |
|---|---|---|---|
| two taps on "+": the `@State` updated the text | the switch added a conditional red text, and the row height was recomputed | navigation through `NavigationLink`, the title from `navigationTitle`, the back button | "Add to favourites" through `@EnvironmentObject`: the star appeared in the list on the previous screen |

All elements were drawn with native iOS 6 controls: `roundedRect` buttons, `UISwitch`, `UITextField`, the blue navigation
bar, and a table with disclosure arrows. So the goal "modern SwiftUI code looks like a native iOS 6 app" is met for this set.

Running it on a device could not be verified under the rules: an app launched from `/var/tmp` does not get a display
(`GSRegisterPurpleNamedPort`, error 1100). For a UI launch the app must be installed in `/Applications`, which the device
rules do not allow.

### 5.4 Probe: the engine on hardware

`frameworks/SwiftUI/tests/probe/main.swift` is a windowless probe: it builds a tree, changes state through `@Published`,
flushes transactions, prints the `UIView` tree with frames, and times it. It ran on an **iPhone 4S, iOS 6.1.3** (through the
device module of the toolchain, the files only in `/var/tmp`, deleted after the run; the output of the run is not kept in
the tree):

- the tree was built, a change to `@Published` added a new `ForEach` row, showed a conditional block and changed widths:
  matching and layout work on the hardware;
- **2.83 ms** for a full screen update (200 updates in 0.566 s), worst case 3.71 ms;
- **6.0 ms** for the first build and layout of the screen.

So the 60 Hz frame budget (16.6 ms) holds on an iPhone 4S with room to spare, even when the whole screen is redrawn without
incrementality.

A limit found at the same time: `UIFont`/`GSFontCreateWithName` crashes on iOS 6 in a process without a UIApplication
(`_CFRuntimeSetCFMPresent`), so windowless probes with text are possible only inside an app.

### 5.5 Bugs found and fixed by the prototype (useful for the future implementation)

- Parent links of nodes were set only on update, not on the first build. Because of that a list did not learn that its
  row had changed, and a conditional element inside a row did not appear.
- A stack gave the remainder to its children without regard to their minimum sizes, so text in a row wrapped too early.
- Transaction flushing must go from parents to children; otherwise nodes that were already recreated get recomputed.

### Correction to the coverage count

The count "646 of 1208 types, 289 of 289 modifiers" is correct as a count of **names**, and it stays that way, but it cannot
measure completeness. The typed comparison of `swift-api-digester` (Apple's SwiftUI interface for iOS 16.4 against our
module, `tools/api_surface.lua`) shows what the name count cannot see: of 4740 Apple declarations, **927 are missing and 314
are present with a different signature** (calls covered by our default values are not counted). The reason the name count is
blind is that a comparison by name does not distinguish overloads, and accepts `Shading.linearGradient` as
`ShapeStyle.linearGradient`. The same comparison and scenarios taken from real code also found three silent falsehoods that
the names did not show: the `.updating` of a gesture did not call the body (gestures were matched by the closure's type
through `Mirror`), `animatableData` of our own shapes, effects and layouts was read nowhere, and `GeometryEffect` was
recorded as "ignored" with a wrong reason (`CALayer.transform` exists since iOS 2). All three are fixed. The rest of the list
is the work queue (the generated `gaps.txt`, which `tools/api_surface.lua` writes).

### Techniques from related systems (review of 19.09)

The sources of OpenSwiftUI (`DynamicPropertyCache`, `PropertyList`, `DynamicBody`), Tokamak (the Fiber reconciler,
`Mutation`/`commit`) and SwiftCrossUI (`ViewGraphNode`: a cache of layout results, `bottomUpUpdate`) were read; Flutter,
Compose, React and Salsa were read from their documentation. What we take from them, in decreasing order of usefulness:

| Technique → source | In SwiftUI | Status |
| --- | --- | --- |
| Identity of an `if`/`else` branch, not only of its type → SwiftUI's structural identity, Compose's group key, Flutter's `Widget.canUpdate` | `GroupNode` remembers the `_ConditionalContent` branch, and when it changes it drops the subtree: in Apple, the `@State` of the two branches is different | **done**, tested |
| Early cutoff: the same value does not invalidate → AttributeGraph, backdating in Salsa | `StateStorage` compares the old and the new value byte by byte | **done**, tested |
| A "proposal → size" cache in the layout node, invalidated upward through the parents → SwiftCrossUI `resultCache`, Tokamak `propagateCacheInvalidation` | a stack measures its children three times, that is about 3^depth measurements of a leaf | **done**: on the iPad 2, depth 3 went from 1174 to 56 ms per update, depth 6 from 5.3 s to 139 ms; growth is linear. At least 32 entries are needed: nested stacks alternate axes, and the proposals multiply; with 6 entries, eviction brought the exponent back |
| A cache of DynamicProperty fields per type → OpenSwiftUI `DynamicPropertyCache` | `_forEachField` runs on every `render()` now | cheap, queued |
| An `Equatable` path for comparing views → `EquatableView`, React `memo` | `viewsEqual` is byte-wise only, and a closure in the view breaks the cutoff | cheap, queued |
| A "changed" flag on properties plus tracking of the environment keys read → `_DynamicPropertyBuffer.update`, `PropertyList.Tracker`; skipping the parent's recomputation (Compose) | now any environment change recomputes the whole subtree | architectural, after a measurement |
| Bottom-up layout that stops when the size is unchanged → SwiftCrossUI, Flutter's relayout boundary | **partly done**: `mount()` (syncing the subviews) and `place()` are now skipped for nodes whose size and frame did not change; on the iPad 2, updating one row of six at depth 3 fell from 82 to 10 ms. Stopping the propagation of the size itself upward (when a child's size changes but the parent's does not) is not done: now `invalidateLayout()` marks all ancestors dirty at once |
| The environment as an immutable list with a shared tail → OpenSwiftUI `PropertyList` | about 55 fields are copied into each node | a large rework, later |
| A separate phase applying changes to UIKit → Tokamak `Mutation` | `syncSubviews` matches the subviews in O(n²); transitions attach naturally to `.insert`/`.remove` | later |
| Our own `Observation` (`withObservationTracking`) → how OpenSwiftUI wraps `updateBody` | would close "not at all" for `@Observable` | large; needs a proven macro plugin |

On the same measurement (iPad 2, six rows of nested stacks of depth d, with only the first row changing), skipping
`mountContents()` and `place()` for unchanged nodes gave: d=1, 14 → 3.4 ms; d=3, 82 → 10 ms; d=5, 18 ms per update against
128 ms for a full screen build. The phase breakdown (`render`, `mount`, `layout`) is instrumented in `SwiftUIProbe`.

A second pass over the same measurement (a centralized skip in `reconcile()`: a node whose view did not change
byte-for-byte and whose environment is the same does not get `update()` at all; `GroupNode`, `ForEachNode` and the
`.padding()`, `.frame()` and `.background()` wrappers reset the layout only on a real change) cut the number of size
computations on a deep screen by about a third (iPad 2: d=3, 2135 → 1354; d=5, 3863 → 2501 per update), and a plain screen
went from 2.2 to 1.6 ms. The update time of one row barely changed (d=3, 10–11 ms): it is set by the changed chain itself,
not by its neighbours. The remaining calls are the legitimate work of the changed branch, plus one that cannot be removed:
the `content:` closure of `ForEach` is a new closure every time, so the enclosing stack always "changed" by a byte-wise comparison.

The same pass found a hidden hierarchy bug: the wrappers `PaddingNodeM`, `FrameNodeM` and `BackgroundNodeM` adopted their
content (`adopt(...)`) onto themselves, not onto the inner node `inner`, which holds the size cache and the layout flag.
So the upward walk in `invalidateLayout()` skipped `inner`: a change under `.padding()` did not reset the cache of the padding
itself. Before, an unconditional reset in `GroupNode.update()` hid this; when I made that reset conditional, the test
"a deep change is measured again" failed, which is how the bug was found. Now the content is adopted by `inner`, and two tests
(the deep chain, and "the box with padding grows with its content") fail without the fix.

Measuring the deep screen also found a scheduler bug: a nested `ObservableObject` observer whose view had not changed
byte-for-byte was skipped on update when its ancestor had already been redrawn, and the ancestor was exactly what skipped
the equal view. Now only nodes that were really redrawn in this pass are skipped (there is a test).

Not taken: a port of OpenAttributeGraph (C++ that relies on 64-bit metadata), the double Fiber tree and asynchronous body
recomputation (UIKit on iOS 6 runs only on the main thread, so there is nothing to interrupt), a renderer abstraction (there
is one backend), Compose's slot table (it needs a compiler plugin), a full diff of a virtual tree (we already have a tree with
state), and a general dependency engine such as Adapton (marks with early cutoff are enough).

## 6. Compatibility: from the source versus the ABI

**From the source (what the prototype does).** Matching names and API shapes is enough. The limits are only linguistic: an
app must compile with our Swift 6.4 (verified: parameter packs, `some View`, result builders, property wrappers, macros;
Observation macros are not — `@Observable` is not supported).

**From the ABI (running ready-made SwiftUI app binaries through the recompiler).** It requires binary compatibility with the
real SwiftUI: 50,794 exported symbols, 2,648 nominal type descriptors, 390 protocol descriptors, plus resilient layouts
(library evolution: sizes and field offsets come from the metadata, not from the code), witness tables, and the whole private
part that the app's code refers to. Beyond the size, it runs into the same 64-to-32-bit object-model blocker as in section 2.2:
an app built for arm64 reaches Swift metadata with a 64-bit layout. **Estimate: not feasible; there is no point in this
direction,** because recompiling from source gives the same result without the ABI.

## 7. Effort estimates (an estimate, not verified)

For our own implementation, on top of the prototype, by one engineer:

| Level | What it includes | Time |
|---|---|---|
| Simple screens | what exists now, plus `ScrollView`, `Image` from resources, `Section`, `Alert`, `TabView`, `.sheet`, basic gestures and `withAnimation` animations, `onChange`, `@Environment`, cell reuse in lists, stable identity in `ForEach` | 1 to 1.5 months |
| A typical app | `LazyVStack`/`Grid`, `Form`, `Picker`, `Stepper`, `Slider`, `ProgressView`, `TextEditor`, focus, the keyboard, `NavigationLink(isActive:)`, programmatic navigation, something like `matchedGeometryEffect`, `AsyncImage`, `Canvas` through CoreGraphics, `Transaction`/`Animatable`, `PreferenceKey`, `GeometryReader`, localization, RTL, iPad layouts, `UIViewRepresentable` | 3 to 5 months |
| Broad API compatibility | cover the SwiftUI surface of iOS 13 to 15 so that foreign code compiles without changes: about 1,100 types and about 2,600 modifiers, an incremental dependency graph instead of redrawing subtrees, snapshot tests | 1.5 to 3 years |
| ABI compatibility | see section 6 | makes no sense |

For comparison: the prototype itself (half a day of work) covered "a screen with a list, navigation, state and an observed model".

## 8. The recommended first step

1. **Pin OpenCombine as a toolchain component.** It already builds and passes its tests. It needs a package recipe
   (`revenant@combine`), a run after the backport of `CFRunLoopTimerSetTolerance` and the Swift overlay fixes are merged,
   and a decision on the upstream PR about `Stride.magnitude` on 32-bit.
2. **Continue SwiftUI from the prototype** in `frameworks/SwiftUI`, not from OpenSwiftUI: add snapshot tests in iLEmu (a reference PNG for each screen), and bring the "simple screens" level to completion.
3. **Close direction A**, and do not return to the real SwiftUI; from its analysis take only the map of the device
   (AttributeGraph as the graph engine, DisplayList as the drawing layer), which the prototype's architecture already reproduces.

## 9. What is not verified

- The keyboard and text input in the app (the touch scenario did not reach the field).
- Behaviour on the iPad 2 (neither the emulator nor the device was run there).
- The scrolling performance of a list with many rows (cells are not reused).
- Animations, gestures other than touch, `@Observable` and the Observation macros.
- An `xmake` rule for the toolchain (research; there was no integration).
- iLEmu on 6.1.3 does not bring up SpringBoard (a known blocker in backboardd), so the UI runs were on 6.0 (iPod4,1); on 6.1.3 only console probes were run.

## 10. How to reproduce

```
./xmakew build -P . CombineTests                               # Combine and the OpenCombine tests under armv7
./xmakew build -P . SwiftUI SwiftUIDemo SwiftUIProbe           # the SwiftUI module, SwiftUIDemo.app and SwiftUIProbe
./xmakew l -P . frameworks/SwiftUI/tools/emulate.lua snapshots      # the demo's scenarios in the emulator, through SpringBoard
```

The firmware analysis of section 2 was run with scripts that are not kept in the repository.
