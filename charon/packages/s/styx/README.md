# Combine for the port's armv7 releases

One Swift module, built for armv7 by `packages/s/styx/xmake.lua` against the
`charon@swift-runtime` a port carries. A port takes it with
`add_requires("charon@styx", {alias = "combine"})` and `add_packages("combine")`
beside the runtime and libcxx, and writes `import Combine`.

## Where the module comes from

| | |
| --- | --- |
| Upstream | [OpenCombine](https://github.com/OpenCombine/OpenCombine), MIT — the reimplementation of Apple's Combine |
| Upstream commit | `1c6f02c7ed8140c0ba7a783aaddb6e0685a0037b` (OpenCombine's `HEAD`; its `0.14.0` tag is `8576f0d579b27020beccbccc3ea6844f3ddfc2c2`) |
| The fork | [kern0x1b/styx](https://github.com/kern0x1b/styx), MIT, `2026.09.20` — the upstream plus the fold of its three modules into one named `Combine`, the C++ helper, the iOS 6 adaptations, and the layer below |
| Pinned commit | `aea2b9115261ddb201c3b6e50cf5a84060b87df3` |
| The licence | the upstream's `LICENSE`, installed with the package under `licenses/LICENSE`: MIT License, Copyright (c) 2019 Sergej Jaskiewicz |
| The fork's own terms | the fork changes the sources and adds the layer in `files/CombineKit`; it claims no new licence over Sergej Jaskiewicz's work, and the upstream's copyright and permission notice travel with the code unchanged |

The recipe pins that commit, keeps the licence beside the install, and hashes its own
sources and recipe into a readonly digest config, so a changed recipe or a changed file is
a different package with its own install path.

## What the layer of our own is

`files/CombineKit/` is a thin layer of our own, compiled into the same module so that it
sees the fork's internal helpers. No vendored file is edited. It carries what the fork
does not have and Apple's declaration does:

| File | Carries |
| --- | --- |
| `MergeKit.swift` | the behaviour the merge and combineLatest families share: `MergeInner` and `CombineLatestChild`/`CombineLatestInner` |
| `Publishers.Merge.swift` | `Publishers.Merge` through `Merge8`, `MergeMany`, the `merge(with:)` operators, their equality |
| `Publishers.CombineLatest.swift` | `Publishers.CombineLatest`, `CombineLatest3`, `CombineLatest4`, the `combineLatest` operators, their equality |
| `Publishers.CollectByTime.swift` | `Publishers.TimeGroupingStrategy`, `Publishers.CollectByTime`, `collect(_:options:)` |
| `EquatableHashableAndCodable.swift` | the `==`, `hash(into:)` and `hashValue` Apple's interface declares in the open, and `Publishers.MapError`'s labelled initializer |
| `MapErrorLabeledInit.swift` | (the same initializer, kept in its own file so its name says which one it is) |

`files/DispatchTimeDistance.swift` was already there: the runtime's Dispatch overlay
(Swift 5.4.3) has no `DispatchTime.distance(to:)`, and the scheduler needs it.

## What is measured

| Measurement | Result |
| --- | --- |
| Corpus rows for `Combine` | 1224 |
| Covered by the built armv7 module | 1131 |
| The 93 that are not, and why | `facts/Combine/CombineKit.md` |
| `swift-api-digester -dump-sdk`, Apple's 26.2 `Combine.swiftinterface` against ours | 963 declarations in both, 72 in Apple's that are not in ours, 272 in ours that Apple does not declare |
| Host differential, 40 cases, the same source against the host's own Combine and against ours | `DIFFERENTIAL: identical`; the mutation turns it to 4 differing lines; `facts/Combine/CombineKit.md` |
| The armv7 probe on the emulated iPhone 4S at 6.1.3 | 50 of 50, `combinekit: every check held`, exit 0 |

## What is not here, and is absent rather than stubbed

- **`URLSession` publishers** (`dataTaskPublisher` and the rest): `URLSession` is iOS 7,
  and the publishers need a TLS stack this build does not carry. Not shipped.
- **The Foundation integration's own rows** are carried by the fork, not by the layer:
  `NotificationCenter.Publisher`, `Timer.publish`, the run loop and operation queue
  schedulers, `KeyValueObservingPublisher`.
- The four `__AsyncSequence_Failure` / `__AsyncIteratorProtocol_Failure` typealiases the
  corpus lists: these are the names the compiler synthesises when a type conforms to
  `AsyncSequence`, and it prints them in a framework's interface but not in the interface
  synthesised out of a module built for a target. The conformances themselves are there.
