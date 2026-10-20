# Features

- **One module, Apple's shape.** `import Combine` alone brings the core
  (`Publisher`, `Subscriber`, `Subject`, `AnyCancellable`, operators),
  `ObservableObject`/`@Published`/`ObservableObjectPublisher`, the
  `Timer.publish` / `NotificationCenter.publisher` Foundation integration, and
  `DispatchQueue` / `RunLoop` / `OperationQueue` as `Scheduler`s — with the
  natural spellings (`Timer.TimerPublisher`, `Optional.Publisher`,
  `Result.Publisher`), no disambiguation namespace.
- **What OpenCombine lacks, Apple declares.** `Publishers.Merge` through
  `Merge8` and `MergeMany`, `Publishers.CombineLatest` through `CombineLatest4`,
  `Publishers.CollectByTime` with `collect(_:options:)`, and the equality and
  hashing Apple's interface declares in the open.
- **Runs where Combine does not exist.** No dependency on any system Combine;
  verified on an iPhone 4S and an iPad 2 (iOS 6.1.3) and in emulation.
- **Availability-honest on old iOS.** iOS 7-only API (the `CFRunLoopTimer`
  tolerance, `URLSession.dataTaskPublisher`) sits behind `#available` or is
  marked iOS 7, so the module compiles at a 6.0 deployment target with
  availability checking on.

What the upstream suite does and does not run, and what the run on iOS 6.1.3 showed, is in
[test results](test-results.md).

## Trademarks

Combine, Swift, iOS and iPhone are trademarks of Apple Inc. They are used here nominatively, to say what this software is
and where it runs; there is no affiliation with or endorsement by Apple, and none of Apple's code or assets is included.
