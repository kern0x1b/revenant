# The layer of our own, and what was measured

`packages/s/styx/files/CombineKit` closes the measured gap between the module
`charon@styx` builds and the Combine Apple's SDK 26.2 declares. It is compiled into the
same module, so it sees the fork's internal helpers, and no vendored file is edited.

## The measurements, and how they were taken

**The gap, before.** `swift-api-digester -dump-sdk` was run on Apple's 26.2
`Combine.swiftinterface` and on the armv7 module, and the two dumps were compared by
declared name:

```
apple declarations: 1035   ours: 1099
in both:    806
in apple, not ours: 229
in ours, not apple: 293
```

Row coverage was then measured with the corpus's own tool: `swiftinterface-surface.py`
reads Apple's declarations from its `.swiftinterface`, and reads ours from the
`.swiftinterface` the toolchain synthesises out of the built `.swiftmodule`, so both sides
are spelled the way the corpus spells them.

```
corpus rows for Combine: 1224
covered by the built module: 946        # as it stood
```

**After the layer**, the same two measurements:

```
corpus rows for Combine: 1224
covered by the built module: 1131
not covered: 93
  class         10 /    10
  constant       9 /     9
  enum           7 /     7
  method       561 /   636
  property     256 /   265
  protocol      13 /    13
  struct       100 /   102
  typealias    175 /   182
```

```
apple declarations: 1035   ours: 1235
in both:    963
in apple, not ours: 72
in ours, not apple: 272
```

## The 93 rows that are not covered, each with the reason

The parts, which `tests/backports/host/combine/coverage.sh` recomputes from the built armv7
module and fails on when they do not match — so this table is a check, not a claim:

| family | rows not covered |
| --- | --- |
| optional and result publisher members | 73 |
| witnesses the compiler derives | 8 |
| async typealiases the compiler synthesises | 4 |
| coding witnesses the compiler synthesises | 4 |
| private(set) accessors where Apple declares a getter | 3 |
| Published.wrappedValue | 1 |
| total | 93 |

Each part is listed row by row below.

**73 rows — `Optional.Publisher.*` and `Result.Publisher.*` members.** The module
declares Apple's names: `Optional.Publisher`, `Optional.publisher`, `Result.Publisher` and
`Result.publisher` are all there, with every operator on them, and a client that writes
`someOptional.publisher.map { }` compiles against the module (the armv7 probe does exactly
that and it runs). What differs is where the members are *printed*: the fork nests the
type under an intermediate `OCombine` namespace (`Optional.OCombine.Publisher`) and
`Optional.Publisher` is a typealias for it, which upstream added for
[SR-11183](https://bugs.swift.org/browse/SR-11183) — the ambiguity when a client has both
OpenCombine and Combine imported. A module named `Combine` cannot be that pair, so the
namespace is dead weight here, but removing it means editing the fork's own files, which
this layer does not do. The printed path is the divergence; the API a caller writes is
Apple's.

**8 rows — witnesses the compiler derives.** `CombineIdentifier.==(a:b:)`, `.hash(into:)` and
`.hashValue`, `Subscribers.Demand.==(a:b:)`, `.hash(into:)` and `.hashValue`,
`AnyCancellable.hashValue`, and `ImmediateScheduler.SchedulerTimeType.Stride.==(a:b:)`.
Each of these types declares `Equatable` or `Hashable`, so every one of them answers `==`
and hashes; Apple's framework interface prints the operators under their public names
because Apple writes them out, and the interface synthesised out of a module built for a
target prints the derived ones under the compiler's own name (`__derived_struct_equals`,
`__derived_struct_hash`). The `PrefetchStrategy` operator *was* written out, because that
one the compiler derives for an enum and the fork's file could be left alone; the others
are witnesses the compiler owns, and re-declaring them from another file is an
`invalid redeclaration`.

**4 rows — `Record.encode(to:)`, `Record.init(from:)`,
`ImmediateScheduler.SchedulerTimeType.Stride.encode(to:)` and `.init(from:)`.** `Record`
and `Stride` are already `Codable`; the fork declares the conformance in its own file and
the compiler synthesises the two methods, so the same printed-name difference applies.
Writing them from this layer is a redeclaration.

**3 rows — `Record.Recording.output`, `Record.Recording.completion`,
`Subscribers.Assign.object`.** The fork declares them `public private(set) var`; Apple
declares `public var … { get }`. A client sees the same access (a public getter, no public
setter); only the printed form differs, and changing it means editing the fork's files.

**1 row — `Published.wrappedValue`.** Marked `@available(*, unavailable, message:
"@Published is only available on properties of classes")` in Apple's interface too, with
the same reason. A `@Published` property is read and written through the enclosing-instance
subscript the wrapper declares, which the corpus lists separately and the module carries.

**4 rows — the `__AsyncSequence_Failure` and `__AsyncIteratorProtocol_Failure`
typealiases.** These are the names the compiler synthesises for an `AsyncSequence` and
`AsyncIteratorProtocol` conformance, and it prints them in a framework's interface but not
in the interface synthesised out of a module built for a target. The conformances are
there: `AsyncPublisher`, `AsyncPublisher.Iterator`, `AsyncThrowingPublisher` and their
`AsyncIterator`s all conform, and the corpus's own rows for them are covered.

## The host differential

`.agent-work/runs/combine/differential` in this branch is the same `Harness.swift`,
`Table.swift` and `main.swift` compiled twice, once against the host's own `Combine` and
once against the module this port builds for the host, and the two runs compared line for
line. 40 cases over the four groups the work is grouped by: the merge and combineLatest
families, `collect(byTime:)`, the schedulers (with a scheduler whose time the test drives,
so the time-based operators are the same on both sides), demand and backpressure, and
cancellation.

```
cases: cases 40
DIFFERENTIAL: identical
```

Every rule the layer implements came out of that table, and the table is what says so:

| Rule | What the host does |
| --- | --- |
| A merged publisher passes the downstream's demand through to every upstream | with a downstream that asked for one value, each upstream is asked for exactly one; with a downstream that asked for everything, each is asked for everything |
| A merged publisher finishes when its last upstream finishes, and not before | an upstream that sends and finishes at subscription time does not end the stream |
| A combined publisher keeps each upstream's most recent value | a value from one upstream combines again with what the others sent last |
| A combined publisher asks its upstreams again only while the downstream wants values | a downstream that asked for one value leaves each upstream having been asked for one |
| `collect` sends on the tick, and on the count for `byTimeOrCount` | a count of two with three values sent before the first tick gives two collections |
| `Drop`, `CollectByCount`, `Retry` and `Output` compare more than their upstream | two `Drop`s that differ only in their count are not equal |
| The host delivers a collect operator's completion through its scheduler | a collect case has to let the clock run past the completion to see it |

Six faults were found by the table and fixed at the root, and one of them was in the table
itself: a case whose only reference to a subscription was the result of `sink` released it
the moment the expression ended, so both implementations were being measured delivering
nothing. The trace now holds the subscription for as long as the case lives, and that is
what the collect cases above depend on.

**The mutation.** `Publishers.CollectByTime.Inner.request(_:)` had its one line
`subscription.request(demand)` changed to a comment and the table run again:

```
cases: cases 40
DIFFERENTIAL: 4 differing lines
-collect/byTime/on-the-tick	value [1,2]
-collect/byTime/on-the-tick	value [3]
-collect/byTimeOrCount/on-the-count	value [1,2]
-collect/byTimeOrCount/on-the-count	value [3]
```

**The run builds the module itself.** It used to link whatever `Combine.o` was already in
the tree, so a change to the module's Swift could sit in the sources while the run measured
the old object and answered `identical` - a mutation of the source read as a pass, which is
the one thing this table must never do. `run.sh` now builds the host module from the sources
beside it before it builds either probe, and a failure to build stops the run. With that,
`MergeInner.request(_:)` had its demand pass-through loop emptied - nothing but a comment -
and `run.sh` alone, with no separate build step, reported

```
cases: cases 40
DIFFERENTIAL: 21 differing lines
-merge/two/interleaved	value 1
-merge/two/interleaved	value 2
-merge/two/interleaved	value 3
-merge/two/holds-until-demanded	value 1
-merge/two/holds-until-demanded	value 2
-merge/two/holds-until-demanded	finished
-merge/three/chains	value 9
...
```

and with the line back it is `identical` again.

The host copy of the module is called `CombineKit`, and the staged sources have the module's
own `Combine.` prefix rewritten to that name. The reason is the host, not the module: on
macOS the SDK's own Foundation imports Apple's Combine, and a module called `Combine` links
Apple's Combine beside it through the autolink its interface carries, and the two sets of
classes then collide. `run.sh` refuses to start if `otool` finds Apple's Combine in the
binary, and that refusal has already caught it once. The Foundation-integrated part of the
module (`NotificationCenter.Publisher`, `Timer.publish`, the run loop and operation queue
schedulers, KVO) is measured on the device instead, because the host copy cannot carry it.

## The armv7 probe

`.agent-work/runs/combine/port` is a port that writes `import Combine` and calls the layer's
surface: the merge family, the combineLatest family, `collect(byTime:)` and
`collect(_:options:)`, the equality and hashing, `Publishers.MapError`'s labelled
initializer, and the `Optional` and `Result` publishers under Apple's own names. It is
built for `armv7-apple-ios6.1.3` with the addon toolchain, and the driver's own check of it:

```
imports: every non-weak import of the armv7 slices of 20 binaries resolves against 158520 exports; 81 weak imports it does not export, each named in a warning above
[100%]: build ok
build/iphoneos/armv7/release/combinekit: Mach-O executable arm_v7
```

It runs on the emulated iPhone 4S at 6.1.3 (`xmake emulate -s 120 run /usr/libexec/combinekit`):

```
combinekit: every check held
error: fail(exit 1) ...          # this line is from an earlier run
```

50 of 50, process exit 0. Three of the probe's expectations were corrected along the way
rather than the code: a merge case that expected one value where two are correct, and three
equality cases written before the host had said that a `Drop`, a `Retry` and an `Output that
differ only in their count, retries or range are not equal.

## What the equality operators compare, and where the host is the oracle

The rule is Apple's own declarations, and the host is what settled each question. Apple's
interface constrains `Publishers.Collect.==` by the upstream alone, which reads as "the
upstream is all that is compared" — and the host disagreed for `Drop`, `CollectByCount`,
`Retry` and `Output`, where two publishers that differ only in their count, retries or range
are *not* equal. Those four compare every stored property here. Where Apple's declaration
constrains another property as well — `ReplaceEmpty`'s and `ReplaceError`'s output,
`DropUntilOutput`'s other, `Concatenate`'s both — this follows the declaration.
`Publishers.Output.range` is a `CountableRange<Int>`, compared by its two bounds rather
than by a conformance, so that no new one is needed.
