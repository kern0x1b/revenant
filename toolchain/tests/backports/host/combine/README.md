# The Combine differential

Does this port's `Combine` behave as the host's own `Combine` does? One source is compiled
twice and the two runs are compared line for line.

```sh
./run.sh
cases: cases 40
DIFFERENTIAL: identical
```

A differing line is a place where a caller of the two would see something different, and the
run exits non-zero with the difference in `$TMPDIR/revenant-combine-differential/diff.txt`.

## What it is

`Harness.swift`, `Table.swift` and `main.swift` are the source. The only difference between
the two builds is the module each imports, a conditional at the top of each: the host's
`Combine`, or the module this port builds. Forty cases over four groups — the merge and
combineLatest families, `collect(byTime:)`, the schedulers, and demand, backpressure and
cancellation. The time-based cases use `TestScheduler` in `Harness.swift`, a type conforming
to the public `Scheduler` protocol whose time the case drives, so a time-based operator is
the same on both sides whatever the host's clock is doing.

Every rule patches `0005` to `0008` of `packages/c/combine/patches` implement was taken from this
table, and `packages/c/combine/facts/Combine/CombineKit.md` has each rule with what the host does.

## What it builds, and what it cannot

The module is built here, from the patched sources an installed `revenant@combine` holds, before
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

The Foundation integration is not in the host copy — `src/Combine/Foundation` and
`src/Combine/Schedulers` are removed — for the same reason: it is where
`NotificationCenter.Publisher`, `Timer.publish`, the run loop and operation queue schedulers
and KVO live. Those are measured on the device instead, by the probe in
`packages/c/combine/facts/Combine/CombineKit.md`.

## A module that does not build

is `exit 1` with `the module did not build; there is nothing to compare`, checked where the
build is made rather than left to the shell. A clean run prints how much it compiled:

```
module: 108 Swift files
cases: cases 40
DIFFERENTIAL: identical
```

## The coverage, against the facts

`coverage.sh` builds the armv7 module the way the package builds it, synthesises the
interface out of it, and counts the corpus rows it carries with the corpus's own tool on both
sides. It then compares the count — and each family of the rows it does not carry — with the
table in `packages/c/combine/facts/Combine/CombineKit.md`, and fails when they disagree. The
numbers in the facts are a check, not a claim. With one family miscounted by one:

```
the facts file is stale:
  the facts say 7 rows for 'witnesses the compiler derives', there are 8
```

`REVENANT_SDK` and `REVENANT_SWIFTC` are named rather than guessed: the store holds several
builds of the toolchain and several of the 16.4 SDK, and only the pair the package used will
accept `-target armv7-apple-ios6.1.3`.

## The mutation

`MergeInner.request(_:)` with its demand pass-through loop emptied — nothing in it but a
comment — and `./run.sh` alone, with no separate build step:

```
cases: cases 40
DIFFERENTIAL: 21 differing lines, in .../revenant-combine-differential/diff.txt
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

They are not in this repository; `packages/c/combine/xmake.lua` fetches OpenCombine and applies
the patches, and an installed `revenant@combine` keeps the patched tree under `src/`. `run.sh` and
`coverage.sh` take the newest one under `~/.xmake/packages/c/combine`, or `$COMBINE_SOURCES`
pointed at such a `src/`. They say so and stop if there is neither.
