# Third-party components

Two files of a third-party project are vendored, under its own licence:

| From | What | Licence | Upstream commit |
| --- | --- | --- | --- |
| [OpenSwiftUI](https://github.com/OpenSwiftUIProject/OpenSwiftUI) (`Sources/OpenSwiftUICore`) | `View/Image/SymbolVariants.swift` → `eidolon/Sources/SwiftUI/SymbolVariants.swift`; `View/Text/Typesetting/TypesettingLanguage.swift` and `View/Text/Text/Text+Scale.swift` → the declarations in `eidolon/Sources/SwiftUI/TextSettings.swift` | MIT, Copyright (c) 2023-2025 Kyle-Ye | `efa103755b95bd5a6ab42681a261c7cc66be6f75` |

Each vendored file carries a header naming the upstream, the path, the commit, the licence and what was
changed for this port. The following are used at build or test time and come from
[Charon](https://github.com/kern0x1b/charon) packages or from their own upstreams.

| Component | Version | Licence | Where it comes from |
| --- | --- | --- | --- |
| [Styx](https://github.com/kern0x1b/styx) | 2026.09.20 (`f5fe651`) | MIT | the `charon@styx` package, a fork of [OpenCombine](https://github.com/OpenCombine/OpenCombine) (MIT, Copyright its authors; the licence text is kept in the fork); the Combine implementation the module re-exports as module `Combine`. `combine/` runs the upstream OpenCombine tests, cloned into `src/`, and is kept as the record of that ancestor |
| Swift runtime and standard library | 6.4 | Apache-2.0 with Runtime Library Exception | the `charon@swift-runtime` package; the runtime an app built with Eidolon carries |
| libc++ / libc++abi | 23.1.1 | Apache-2.0 with LLVM exceptions | the `charon@libcxx` package |
| [OpenSwiftUI](https://github.com/OpenSwiftUIProject/OpenSwiftUI) | `b13f093dcc71` | MIT | the result-builder shapes in `eidolon/Sources/SwiftUI/Tables.swift` — `buildIf`, both `buildEither` overloads and `buildLimitedAvailability`, and the `_ConditionalContent` storage enum — follow OpenSwiftUI's `ViewBuilder` and `ConditionalContent`; Apple's constraints and Eidolon's own node plumbing are ours. OpenSwiftUI has no `Table` at this commit — no `Table`, `TableColumn`, `TableColumnBuilder`, `KeyPathComparator` or `SortOrder` file exists in it (checked against the file list of `b13f093dcc71`) — so the sort order, the header and its arrow are written here from Apple's 26.2 interface and are not derived from it |

Eidolon re-implements the shape of Apple's public SwiftUI API and contains no code or assets of Apple's. The lists of
public type and modifier names in `bridge/` are identifiers only. `bridge/prepare-fw.sh` makes a local, git-ignored copy
of a framework from the reader's own iOS SDK to compare against; that copy is not part of this repository and must not
be committed or passed on.
