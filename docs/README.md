# Documentation

The documents of revenant, by kind ([Diátaxis](https://diataxis.fr)): tutorials learn by doing, guides do one task, references are facts to look up, and explanations say why. Under each kind, a component's documents sit in its own folder; the documents about the whole repository sit directly under their kind.

## Repository-wide

| Document | About |
| --- | --- |
| [What revenant is for](explanation/platform.md) | the platform, its first targets and its limits |
| [Architecture](explanation/architecture.md) | the three layers, what each top-level folder is, and how an app built outside gets our libraries |
| [Loading the backports](explanation/backports-loading.md) | how the backport libraries are loaded |
| [Continuous checks](guides/ci.md) | what CI runs |
| [The machine: one cache, one clean](guides/machine.md) | where the build keeps its cache, and how to give it back |
| [Prebuilt packages](guides/prebuilt.md) | packages built elsewhere, and how to use them |

## Toolchain

| Document | About |
| --- | --- |
| [Write a port](tutorials/toolchain/port.md) | a tutorial: an xmake project from an empty directory to a `.deb` |
| [Checks and waivers](guides/toolchain/checks.md) | the checks a port runs, the waivers it states, and the release's libraries |
| [Run a port on an emulated device](guides/toolchain/emulate.md) | the emulator, for a port |
| [Write a package](guides/toolchain/packages.md) | a package in the repository's package store |
| [Working on the toolchain](guides/toolchain/contributing.md) | the contributor guide |
| [The toolchain's tests](reference/toolchain/tests.md) | the suites, and what runs where |
| [Rules, values and checks](reference/toolchain/rules.md) | the target rules and the values each one reads |
| [Commands](reference/toolchain/commands.md) | the xmake commands and the environment |
| [Packages](reference/toolchain/packages.md) | the packages and their versions |
| [Tools](reference/toolchain/tools.md) | the developer tools |
| [Third-party code](reference/toolchain/third-party.md) | the third-party code, and where each piece stands |
| [Why the toolchain is built this way](explanation/toolchain/design.md) | the design and its decisions |
| [Runtimes and backports](explanation/toolchain/runtimes.md) | why the runtimes and backports are built as they are |

## Emulator

| Document | About |
| --- | --- |
| [Build, run and test](guides/emulator/build-and-test.md) | requirements, options, boot and usage |
| [Contributor guide](guides/emulator/contributing.md) | the layout, what bites, the conventions |
| [How it works](explanation/emulator/how-it-works.md) | what is emulated and how the pieces fit |
| [Where the time goes](explanation/emulator/performance.md) | why the emulator is as slow as it is, and why not another emulator |
| [Performance measurements](reference/emulator/performance.md) | the measured runs and the counters of a boot |
| [Shared translation](explanation/emulator/shared-translation.md) | the design for translating the shared cache once |
| [iOS 6.1.3](explanation/emulator/ios-6.1.3.md) | what kept 6.1.3 from booting, and what fixed it |
| [Control surface](reference/emulator/control-surface.md) | the `--control-stdin` commands and the log lines |
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
| [Guest bridge](explanation/swiftui/guest-bridge.md) | the sample app and the slot table of the guest build (in Russian) |
| [Research](explanation/swiftui/research.md) | why Apple's SwiftUI cannot be ported (in Russian) |
| [Features](reference/swiftui/features.md) | the areas of the API that are implemented |
| [Completeness](reference/swiftui/completeness.md) | how much of Apple's interface is present, measured two ways |
| [Ledger](reference/swiftui/ledger.md) | what is implemented, ignored, simplified or missing (in Russian) |
| [Surface](reference/swiftui/surface.md) | the interface walker and the surface files the gaps are read from |
| [Host probes](reference/swiftui/host.md) | values measured from Apple's framework on the host |
| [Builder typechecks](reference/swiftui/typechecks.md) | the snippets the Table and TabContent builders must accept or refuse |
| [`TextSelection`](reference/swiftui/text-selection.md) | the one range the release can carry |
| [Third-party](reference/swiftui/third-party.md) | the code this module is derived from, and its terms, and the trademarks |

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
| [Research](explanation/recompiler/research.md) | the research behind it (in Russian) |
| [Corpus and benchmark](reference/recompiler/corpus.md) | what each check proves |

## Agent skills

| Document | About |
| --- | --- |
| [Install and use](guides/agent-skills/install.md) | the agents, what you need, and the status |
| [Contributor guide](guides/agent-skills/contributing.md) | the layout and how to check the skills |
| [Clean-machine tests](guides/agent-skills/clean-machine-tests.md) | the scenarios an agent must follow from an empty directory |
