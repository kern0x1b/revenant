# Combine for the port's armv7 releases

One Swift module, built for armv7 by `packages/c/combine/xmake.lua` against the
`revenant@swift-runtime` a port carries. A port takes it with
`add_requires("revenant@combine", {alias = "combine"})` and `add_packages("combine")`
beside the runtime and libcxx, and writes `import Combine`.

## Where the module comes from

| | |
| --- | --- |
| Upstream | [OpenCombine](https://github.com/OpenCombine/OpenCombine), MIT — the reimplementation of Apple's Combine |
| Pinned commit | `1c6f02c7ed8140c0ba7a783aaddb6e0685a0037b` (OpenCombine's `HEAD`; its `0.14.0` tag is `8576f0d579b27020beccbccc3ea6844f3ddfc2c2`), version `2026.10.19` |
| Our patches | `frameworks/Combine/patches/`, applied in order: the three modules made one named `Combine`, the iOS 6 adaptations, and what OpenCombine lacks and Apple declares (below) |
| The licence | the upstream's `LICENSE`, installed with the package under `licenses/LICENSE`: MIT License, Copyright (c) 2019 Sergej Jaskiewicz |
| Our terms | the patches claim no new licence over Sergej Jaskiewicz's work, and the upstream's copyright and permission notice travel with the code unchanged |

The recipe pins that commit, applies the patches, keeps the licence beside the install, and
hashes itself and each patch into a readonly digest config, so a changed recipe or a changed
patch is a different package with its own install path.

## How the tree is laid out

The patches carry only content edits; they rename no file. The recipe lays the patched tree
out as the one module under `src/` of the install: `Sources/OpenCombine` as `src/Combine`,
`OpenCombineDispatch` as `src/Combine/Schedulers`, `OpenCombineFoundation` as
`src/Combine/Foundation` less the helper files the core's `Helpers` has under the same name,
`COpenCombineHelpers` as `src/CombineHelpers`, upstream's `Tests` as `src/Tests`, and the
header of its gyb templates as `src/utils`. It then compiles `src/Combine` into `libCombine.a`
and its module, and the C++ helper into `libCombineHelpers.a`. With `sources = true` it
installs the tree alone and compiles nothing, for a project that builds the module itself:
revenant does, in `frameworks/Combine`.

## The patches

| Patch | Carries |
| --- | --- |
| `0001` | the imports between the three folders gone, the module named `Combine`, and the `OCombine` namespaces' declarations at Apple's level |
| `0002` | `DispatchTime` distances from the scheduler's own arithmetic: the runtime's Dispatch overlay (Swift 5.4.3) has no `DispatchTime.distance(to:)` |
| `0003` | the run loop timer's tolerance read and set only behind `#available` (iOS 7) |
| `0004` | `URLSession.dataTaskPublisher(for:)` on `URLSession` itself, marked iOS 7 |
| `0005` | `Publishers.Merge` through `Merge8`, `MergeMany`, the `merge(with:)` operators, their equality, and `MergeKit.swift`, the behaviour the merge and combineLatest families share |
| `0006` | `Publishers.CombineLatest`, `CombineLatest3`, `CombineLatest4`, the `combineLatest` operators, their equality |
| `0007` | `Publishers.TimeGroupingStrategy`, `Publishers.CollectByTime`, `collect(_:options:)` |
| `0008` | the `==`, `hash(into:)` and `hashValue` Apple's interface declares in the open, and `Publishers.MapError`'s labelled initializer |
| `0009` | `MapKeyPath`'s gyb helpers defined in its template, so Revenant's gyb expands it |

## What is measured

| Measurement | Result |
| --- | --- |
| Corpus rows for `Combine` | 1224 |
| Covered by the built armv7 module | 1131 |
| The 93 that are not, and why | `docs/reference/combine/combine-kit.md` |
| `swift-api-digester -dump-sdk`, Apple's 26.2 `Combine.swiftinterface` against ours | 963 declarations in both, 72 in Apple's that are not in ours, 272 in ours that Apple does not declare |
| Host differential, 40 cases, the same source against the host's own Combine and against ours | `DIFFERENTIAL: identical`; the mutation turns it to 4 differing lines; `docs/reference/combine/combine-kit.md` |
| The armv7 probe on the emulated iPhone 4S at 6.1.3 | 50 of 50, `combinekit: every check held`, exit 0 |

The counts were taken on `2026.09.20`, the fork with a layer of its own; `2026.10.19` carries
that layer in its patches. The host differential was run again on `2026.10.19`: identical.

## What is not here, and is absent rather than stubbed

- **The Foundation integration's own rows** are measured on the device, not on the host:
  `NotificationCenter.Publisher`, `Timer.publish`, the run loop and operation queue
  schedulers, `KeyValueObservingPublisher`.
- The four `__AsyncSequence_Failure` / `__AsyncIteratorProtocol_Failure` typealiases the
  corpus lists: these are the names the compiler synthesises when a type conforms to
  `AsyncSequence`, and it prints them in a framework's interface but not in the interface
  synthesised out of a module built for a target. The conformances themselves are there.
