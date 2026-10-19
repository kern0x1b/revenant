# Test results and known limitations

Styx is validated on armv7, iOS 6.1.3, built against the Charon Swift runtime
(Swift 6.4) with **availability checking on** for the module. Two suites run:
the project's own `import Combine` probe, and the full upstream Combine test
suite this fork descends from.

## The upstream suite

The full suite (1453 tests) runs in emulation (iLEmu, iPhone 4S profile,
iOS 6.1.3). Result:

| passed | failed | crashed | skipped |
| --- | --- | --- | --- |
| 1448 | 1 | 3 | 1 |

Folding the three upstream modules into a single `Combine` module changed none of
these numbers: the merge preserves the whole public surface and the runtime
behavior. The five that do not pass are all pre-existing and are **documented
limits, not silent failures** — each is a property of armv7/iOS 6 or of a newer
Swift, not of this fork:

- **`DispatchQueueSchedulerTests.testStrideFromDispatchTimeInterval`** and
  **`testStrideFromNumericValue`** — crash. `DispatchQueue.SchedulerTimeType.Stride.magnitude`
  is typed `Int` by Apple's public API; on armv7 `Int` is 32-bit, and the value
  is computed from an `Int64` nanosecond count. This is a 64-bit assumption in
  the public API's shape, reproduced faithfully; it traps on 32-bit.
- **`RecordTests.testRecordDecode`** — crash inside the runtime's Foundation
  overlay when bridging a dictionary during JSON decode; not in Combine code.
- **`MapKeyPathTests.testMapKeyPathReflection`** — failure. Asserts the exact
  reflection text of a key-path; a newer Swift prints it differently. This test
  also fails on a current macOS host with Apple's own Combine.
- **`DispatchQueueSchedulerTests.testScheduleActionOnceNow`** — skipped up front.
  It uses `DispatchQueue.async(qos:)`, a QoS API from iOS 8.

## The `import Combine` probe

A standalone probe exercises the surface real apps depend on; all checks pass in
emulation:

- `ObservableObject` + `@Published` + `objectWillChange` — `objectWillChange`
  fires **synchronously in `willSet`, before the stored value changes**, and
  `@Published` does not alter a property's storage.
- `.sink(receiveValue:)`, `.sink(receiveCompletion:receiveValue:)`,
  `AnyCancellable`, `.store(in:)`.
- `Timer.publish(every:on:in:).autoconnect()` with `RunLoop.main` / `.common`.
- `NotificationCenter.default.publisher(for:)`.
- `DispatchQueue` / `RunLoop` as `Scheduler`; `receive(on:)`,
  `debounce(for:scheduler:)`.
- `PassthroughSubject`, `CurrentValueSubject`, `map`, `removeDuplicates`,
  `eraseToAnyPublisher`, `assign(to:on:)`, `scan`, `Zip`, `Future` + `flatMap`.

## Intentional omissions

- **`URLSession` publishers** (`dataTaskPublisher`): `URLSession` is iOS 7+, and
  the publishers need a TLS stack this build does not carry. Not shipped.
- **`CombineLatest`, `Merge`, `collect(byTime:)`**: absent from the base this
  fork started at; added as consuming code needs them.

## Device status

Verified on live hardware — an iPhone 4S (armv7) and an iPad 2, both iOS 6.1.3.
The `import Combine` probe passes all checks on each device (process exit 0),
including the paths emulation and type-checking cannot fully exercise:
`Timer.publish(every:on:in:).autoconnect()` delivering ticks on a real run loop,
and `NotificationCenter.default.publisher(for:)` firing. The full upstream suite
numbers above are from emulation.
