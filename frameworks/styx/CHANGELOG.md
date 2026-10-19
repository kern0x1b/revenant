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

### Changed
- Folded the separate Dispatch and Foundation modules into the core and renamed
  the whole to `Combine`; dropped the `.ocombine` disambiguation machinery.

### Removed
- The `URLSession` publishers (iOS 7, and they need a TLS stack this build does
  not carry).
