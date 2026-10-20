# Third-party components

Two files of a third-party project are vendored, under its own licence:

| From | What | Licence | Upstream commit |
| --- | --- | --- | --- |
| [OpenSwiftUI](https://github.com/OpenSwiftUIProject/OpenSwiftUI) (`Sources/OpenSwiftUICore`) | `View/Image/SymbolVariants.swift` → `frameworks/SwiftUI/src/SymbolVariants.swift`; `View/Text/Typesetting/TypesettingLanguage.swift` and `View/Text/Text/Text+Scale.swift` → the declarations in `frameworks/SwiftUI/src/TextSettings.swift` | MIT, Copyright (c) 2023-2025 Kyle-Ye | `efa103755b95bd5a6ab42681a261c7cc66be6f75` |

Each vendored file carries a header naming the upstream, the path, the commit, the licence and what was
changed for this port. The following are used at build or test time and come from
[toolchain](https://github.com/kern0x1b/revenant/tree/main/toolchain) packages or from their own upstreams.

| Component | Version | Licence | Where it comes from |
| --- | --- | --- | --- |
| [Combine](https://github.com/kern0x1b/revenant/tree/main/frameworks/Combine) | 2026.10.19 | MIT | [OpenCombine](https://github.com/OpenCombine/OpenCombine) at `1c6f02c7ed81` (MIT, Copyright its authors) with the patches of the `revenant@combine` package, built by the `Combine` target of `frameworks/Combine`, whose `docs/reference/combine/third-party.md` carries OpenCombine's notice; the Combine implementation the module re-exports as module `Combine`. The `CombineTests` target there runs OpenCombine's own tests against it |
| Swift runtime and standard library | 6.4 | Apache-2.0 with Runtime Library Exception | the `revenant@swift-runtime` package; the runtime an app built with SwiftUI carries |
| libc++ / libc++abi | 23.1.1 | Apache-2.0 with LLVM exceptions | the `revenant@libcxx` package |
| [OpenSwiftUI](https://github.com/OpenSwiftUIProject/OpenSwiftUI) | `b13f093dcc71` | MIT | the result-builder shapes in `frameworks/SwiftUI/src/Tables.swift` — `buildIf`, both `buildEither` overloads and `buildLimitedAvailability`, and the `_ConditionalContent` storage enum — follow OpenSwiftUI's `ViewBuilder` and `ConditionalContent`; Apple's constraints and SwiftUI's own node plumbing are ours. OpenSwiftUI has no `Table` at this commit — no `Table`, `TableColumn`, `TableColumnBuilder`, `KeyPathComparator` or `SortOrder` file exists in it (checked against the file list of `b13f093dcc71`) — so the sort order, the header and its arrow are written here from Apple's 26.2 interface and are not derived from it |

SwiftUI re-implements the shape of Apple's public SwiftUI API and contains no code or assets of Apple's. The lists of
public type and modifier names in `frameworks/SwiftUI/tests/data/api/` are identifiers only. `tools/api-surface.lua prepare` makes a local copy
of a framework from the reader's own iOS SDK to compare against, in a run folder outside the tree; that copy is not part of this repository and must not
be committed or passed on.

## Trademarks

SwiftUI, UIKit, Combine, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this project is compatible with. There is no affiliation. This repository contains no code or assets of Apple's.
