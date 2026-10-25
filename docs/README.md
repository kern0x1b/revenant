# Documentation

The documents of revenant, by kind ([Diátaxis](https://diataxis.fr)): tutorials learn by doing, guides do one task, references are facts to look up, and explanations say why. Under each kind, a component's documents sit in its own folder; the documents about the whole repository sit directly under their kind.

## Repository-wide

| Document | About |
| --- | --- |
| [What revenant is for](explanation/platform.md) | the platform, its first targets and its limits |
| [Architecture](explanation/architecture.md) | the three layers, what each top-level folder is, and how an app built outside gets our libraries |
| [Decisions](explanation/decisions/README.md) | the architecture decisions, each with the check that enforces it |
| [Loading the backports](explanation/backports-loading.md) | how the backport libraries are loaded |
| [Open Backports members](explanation/backports-open-members.md) | the larger framework members that remain open |
| [From a clean clone](guides/getting-started.md) | the steps from a clone to a green test run and a built Backports library |
| [Continuous checks](guides/ci.md) | what CI runs |
| [The machine: one cache, one clean](guides/machine.md) | where the build keeps its cache, and how to give it back |
| [Prebuilt packages](guides/prebuilt.md) | packages built elsewhere, and how to use them |
| [Proving code unused](guides/unused-code.md) | the ways code is reached besides its name, and how to check a removal for them |

## Toolchain

| Document | About |
| --- | --- |
| [Write a port](tutorials/toolchain/port.md) | a tutorial: an xmake project from an empty directory to a `.deb` |
| [Checks and waivers](guides/toolchain/checks.md) | the checks a port runs, the waivers it states, and the release's libraries |
| [Run a port on an emulated device](guides/toolchain/emulate.md) | the emulator, for a port |
| [Build a Rust crate for iOS 6](guides/toolchain/rust.md) | a Rust staticlib for armv7 on iOS 6.0, built by the `rust` rule |
| [Write a package](guides/toolchain/packages.md) | a package in the repository's package store |
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
| [Rust on iOS 6](explanation/toolchain/rust.md) | the armv7 target, the pinned nightly, what iOS 6 lacks for std, and the 10.0 minimum in the objects |
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
| [`TextSelection`](reference/swiftui/text-selection.md) | the one range the release can carry |
| [Third-party](reference/swiftui/third-party.md) | the code this module is derived from, and its terms, and the trademarks |

## Backports

| Document | About |
| --- | --- |
| [Demand: the API an app needs](guides/backports/demand.md) | how the demand tool lists what an app references from the SDK, against iOS 6.1.3 and the Backports |
| [Crutches](reference/backports/crutches.md) | the stand-ins the Backports lowering uses, what each measured, and what removes it |
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
| [CloudKit: CKError](reference/backports/CloudKit/CKError.md) | `CKError`, measured |
| [CloudKit: CKRecord](reference/backports/CloudKit/CKRecord.md) | `CKRecord`, not yet visible to Swift on armv7 and iOS 6.1.3 |
| [CreateML](reference/backports/CreateML/README.md) | CreateML and CreateMLComponents on the port's armv7 releases: what is there, what is not, and the protobuf codec |
| [CreateML: CSV reading](reference/backports/CreateML/TabularData/CSVReading.md) | CSV reading in TabularData, measured, and what is carried |
| [CreateML: CSV writing](reference/backports/CreateML/TabularData/CSVWriting.md) | CSV writing in TabularData, measured, and what is carried |
| [CreateML: date parsing](reference/backports/CreateML/TabularData/DateParsing.md) | date reading in TabularData, measured, and what is carried |
| [MusicKit](reference/backports/MusicKit/README.md) | MusicKit for a legacy Apple platform |
| [RealityFoundation: audio](reference/backports/RealityFoundation/Audio.md) | `Audio.swift`: deleted, and what brings it back |
| [RealityFoundation: SceneKit](reference/backports/RealityFoundation/SceneKit.md) | RealityFoundation and RealityKit below iOS 8.0 |
| [Spatial](reference/backports/Spatial/README.md) | what is built here, and what is measured |
| [Spatial: sources](reference/backports/Spatial/Sources.md) | the files, the Float twin generated from the Double text, and the reasons behind the matrix and geometry code |
| [SwiftData](reference/backports/SwiftData/README.md) | the package `revenant@swift-data` |
| [SwiftData: substrate](reference/backports/SwiftData/Substrate.md) | what the port gives SwiftData, measured |
| [TipKit](reference/backports/TipKit/README.md) | the package `revenant@tipkit` |
| [TipKit: rendering](reference/backports/TipKit/TipKit/Rendering.md) | the seam: the tip is drawn in the app |
| [TipKit: reuse](reference/backports/TipKit/TipKit/Reuse.md) | what TipKit was compared against, and why |
| [UIKit](reference/backports/UIKit/README.md) | the UIKit Swift overlay: the surface's Swift constants and cases |
| [UIKit: CASpringAnimation](reference/backports/UIKit/CASpringAnimation.md) | the iOS 9 spring class on iOS 6, its curve and its keyframe delivery |
| [WeatherKit: CompassDirection](reference/backports/WeatherKit/CompassDirection.md) | `Wind.CompassDirection`, measured |
| [WeatherKit: WeatherCondition](reference/backports/WeatherKit/WeatherCondition.md) | `WeatherCondition`, measured |
| [WidgetKit](reference/backports/WidgetKit/README.md) | the package `revenant@widgetkit` |
| [WidgetKit: values](reference/backports/WidgetKit/Values.md) | the value types, measured |
| [WidgetKit: host](reference/backports/WidgetKit/WidgetKit/Host.md) | the seam: there is no widget host |
| [WidgetKit: providers](reference/backports/WidgetKit/WidgetKit/Providers.md) | the two intent providers, and the spellings they do not share with the timeline provider |
| [WidgetKit: reuse](reference/backports/WidgetKit/WidgetKit/Reuse.md) | what WidgetKit was compared against, and why |

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
| [Build and translate](guides/recompiler/build-and-translate.md) | the commands, the guest libraries and what a bind names |
| [Contributor guide](guides/recompiler/contributing.md) | the layout, the conventions, the devices |
| [How it works](explanation/recompiler/how-it-works.md) | the pipeline, the status, the Swift runtime's classes, the scope |
| [Research](explanation/recompiler/research.md) | the research behind it |
| [Corpus and benchmark](reference/recompiler/corpus.md) | what each check proves |

## Agent skills

| Document | About |
| --- | --- |
| [Install and use](guides/agent-skills/install.md) | the agents, what you need, and the status |
| [Contributor guide](guides/agent-skills/contributing.md) | the layout and how to check the skills |
| [Clean-machine tests](guides/agent-skills/clean-machine-tests.md) | the scenarios an agent must follow from an empty directory |
