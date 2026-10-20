# Changelog

All notable changes to this project are recorded here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- A single `Combine` module matching Apple's framework shape, so `import Combine`
  builds and runs on platforms with no system Combine (legacy iOS armv7, Linux,
  WASI). It bundles the core, the Dispatch scheduler and the Foundation
  integration (`Timer.publish`, `NotificationCenter.publisher`, `RunLoop` /
  `DispatchQueue` / `OperationQueue` schedulers) with their natural spellings.
- iOS-6 support: the iOS-7-only `CFRunLoopTimer` tolerance calls are guarded
  behind `#available`, so the module builds and runs at a 6.0 deployment target
  with availability checking on.

- `URLSession.dataTaskPublisher(for:)` at Apple's level, marked iOS 7.
- `Publishers.Merge` through `Merge8` and `MergeMany`, `Publishers.CombineLatest`
  through `CombineLatest4`, `Publishers.CollectByTime` with
  `collect(_:options:)`, and the equality and hashing Apple's interface declares.

### Changed
- The folder follows revenant's one layout: `Tests/` is `tests/` (the skip list under `tests/data/`), the patch series
  is `frameworks/Combine/patches/`, the contributor guide, the test results and the licence notice are under the top
  `docs/` (`docs/guides/combine/`, `docs/reference/combine/`), and the README is one screen. The entries above name
  the old paths as they were.
- Folded the separate Dispatch and Foundation modules into the core and renamed
  the whole to `Combine`; dropped the `.ocombine` disambiguation machinery.
- Combine is no longer a copy of OpenCombine's sources. The `revenant@combine` recipe
  fetches OpenCombine at its pinned commit and applies a patch series that
  carries only content edits; it installs the patched tree laid out as the one
  module, and the revenant targets compile that tree. Upstream's tests run as the
  `CombineTests` target, found by a Lua discovery; the SwiftPM manifest, the
  Makefile, the gyb script and the LLDB script are gone.
- `harness/` is split by role: the XCTest shim, the skip list and the test
  daemon's control are `Tests/`, the discovery is `tools/discover.lua`.

### Removed
- The `OCombine` namespaces of `Optional.Publisher` and `Result.Publisher`.
- The `DispatchTime.distance(to:)` supplement: the polyfill's own arithmetic is
  what every platform runs.
