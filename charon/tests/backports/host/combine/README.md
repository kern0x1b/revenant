# The Combine differential

Does this port's `Combine` behave as the host's own `Combine` does? One source is compiled
twice and the two runs are compared line for line.

```sh
./run.sh
cases: cases 40
DIFFERENTIAL: identical
```

A differing line is a place where a caller of the two would see something different, and the
run exits non-zero with the difference in `$TMPDIR/charon-combine-differential/diff.txt`.

## What it is

`Harness.swift`, `Table.swift` and `main.swift` are the source. The only difference between
the two builds is the module each imports, a conditional at the top of each: the host's
`Combine`, or the module this port builds. Forty cases over four groups — the merge and
combineLatest families, `collect(byTime:)`, the schedulers, and demand, backpressure and
cancellation. The time-based cases use `TestScheduler` in `Harness.swift`, a type conforming
to the public `Scheduler` protocol whose time the case drives, so a time-based operator is
the same on both sides whatever the host's clock is doing.

Every rule `packages/s/styx/files/CombineKit` implements was taken from this table, and
`packages/s/styx/facts/Combine/CombineKit.md` has each rule with what the host does.

## What it builds, and what it cannot

The module is built here, from the fork's own sources and this repository's layer, before
either probe is built against it. **That is the point.** A run that linked a prebuilt object
would measure the object, so a change to the module's Swift could sit in the sources and the
run would answer `identical`: a mutation of the source read as a pass, which is the one
thing this test must never do.

The host copy is called `CombineKit`. On macOS the SDK's own Foundation imports Apple's
Combine, and a module called `Combine` links Apple's Combine beside it through the autolink
its interface carries, and the two sets of classes then collide; `run.sh` refuses to start if
`otool` finds Apple's Combine in the binary. Twelve files of the sources name the module's
own types with the module's own prefix, which only resolves when the module carries that
name, so the staged copy has that prefix rewritten.

The Foundation integration is not in the host copy — `Sources/Combine/Foundation` and
`Sources/Combine/Schedulers` are removed — for the same reason: it is where
`NotificationCenter.Publisher`, `Timer.publish`, the run loop and operation queue schedulers
and KVO live. Those are measured on the device instead, by the probe in
`packages/s/styx/facts/Combine/CombineKit.md`.

## One source of each file

The layer is ours (`packages/s/styx/files/CombineKit`); the rest is the fork's. If the fork's
tree also carried a file of one of the layer's names, the copy would put two different files
at one name and the build would compile whichever the compiler picked — so a change to the
fork's copy would be measured as if nothing had changed. `run.sh` refuses that, by name,
before it builds anything:

```
the fork's sources carry a file of the layer's name, so one of them would be compiled
in place of the other and the run would measure whichever the compiler picked:
MergeKit.swift: .../Sources/Combine/Publishers/MergeKit.swift
```

and a module that does not build is `exit 1` with `the module did not build; there is nothing
to compare`, checked where the build is made rather than left to the shell. A clean run
prints how much it compiled, so the two sources are visible in the verdict:

```
module: 109 Swift files, 6 of them ours
cases: cases 40
DIFFERENTIAL: identical
```

## The coverage, against the facts

`coverage.sh` builds the armv7 module the way the package builds it, synthesises the
interface out of it, and counts the corpus rows it carries with the corpus's own tool on both
sides. It then compares the count — and each family of the rows it does not carry — with the
table in `packages/s/styx/facts/Combine/CombineKit.md`, and fails when they disagree. The
numbers in the facts are a check, not a claim. With one family miscounted by one:

```
the facts file is stale:
  the facts say 7 rows for 'witnesses the compiler derives', there are 8
```

`CHARON_SDK` and `CHARON_SWIFTC` are named rather than guessed: the store holds several
builds of the toolchain and several of the 16.4 SDK, and only the pair the package used will
accept `-target armv7-apple-ios6.1.3`.

## The mutation

`MergeInner.request(_:)` with its demand pass-through loop emptied — nothing in it but a
comment — and `./run.sh` alone, with no separate build step:

```
cases: cases 40
DIFFERENTIAL: 21 differing lines, in .../charon-combine-differential/diff.txt
-merge/two/interleaved	value 1
-merge/two/interleaved	value 2
-merge/two/interleaved	value 3
-merge/two/holds-until-demanded	value 1
-merge/two/holds-until-demanded	value 2
-merge/two/holds-until-demanded	finished
-merge/three/chains	value 9
-merge/many/sequence	value 1
-merge/demand/limited	upstream asked for max(1)
-merge/demand/limited	upstream asked for max(1)
+merge/demand/limited	upstream asked for none
+merge/demand/limited	upstream asked for none
```

`exit 1`. Line restored, `./run.sh` alone again: `DIFFERENTIAL: identical`.

Line restored, `./run.sh` alone again: `DIFFERENTIAL: identical`.

## Where the module's own sources come from

They are not in this repository; `packages/s/styx/xmake.lua` fetches them. `run.sh` takes
them from the xmake source cache when `charon@styx` has been built, or from
`$COMBINE_SOURCES` pointed at the `Sources/Combine` directory of `kern0x1b/styx` at the
commit that recipe pins. It says so and stops if it has neither.
