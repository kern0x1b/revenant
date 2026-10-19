# `DataFrame` and its columns, and a claim I got wrong

## The retraction, first

An earlier commit in this series — and a report to the coordinator — said:

> a user-defined collection conformance does not compile with the port's Swift 6.4 at all

**That is false, and I retract it.** The coordinator typechecked a `RandomAccessCollection,
MutableCollection` struct over `[Double]` on the port's own compiler at `-target
armv7-apple-ios6.1.3` and it passed, and pointed me at the file
(`charon/.agent-work/scratch/coll/fixed.swift`). Diffing against it, the cause is mine and it is
narrow. Measured on **both** compilers, over a generic and a non-generic type, with everything else
held identical:

| declaration | errors |
| --- | --- |
| `public subscript(position: Int) -> Double` | **0** |
| `public subscript(position i: Int) -> Double` | **8** |

**The trigger is writing the label *and* a separate internal parameter name on a subscript.** The two
are the same declaration to a reader and not the same to this compiler, and the second is rejected
with `type 'Col<E>' does not conform to protocol 'BidirectionalCollection'` and `unavailable
subscript 'subscript(_:)' was used to satisfy a requirement of protocol`. Nothing else is involved:
not the generic parameter, not the protocol's primary associated type, not which collection protocol
is refined. I had generalised a single compiler's complaint into a property of the port's toolchain,
and generalised it further than the evidence went: the same file passes on the host's `swiftc` once
the second name is dropped, and it passed there all along.

Two more spellings that are load-bearing, both from the compiler's own notes:

- **`BidirectionalCollection` makes `subscript(bounds:)` a requirement**, not a default.
  `RandomAccessCollection` overrides the standard library's `@available(*, unavailable)` one with a
  requirement of its own. A conforming type supplies it, and the `unavailable subscript` above is what
  that looks like when it is missing.
- **`RandomAccessCollection` refines `BidirectionalCollection`**, so `index(before:)` is required too.
  A type declaring only `index(after:)` is rejected the same way.

## What the columns are, then

`Column<Element>`, `ColumnSlice<Element>` and `DiscontiguousColumnSlice<Element>` are all
`BidirectionalCollection`s, with `typealias SubSequence` naming their own slice type, a `subscript(bounds:)`
of their own, and a **get-and-set** `subscript(position:)` spelled with one name. A caller writes
`for value in column`, `column.max()`, `column.reversed()` — the standard library's algorithms, over
the port's type.

`ColumnProtocol<Element>` keeps its primary associated type and its `name` and does **not** refine a
collection. That is a real divergence from the framework's own declaration, and the reason is measured:
a protocol whose primary associated type is named `Element` and which also inherits
`BidirectionalCollection` has two `Element`s, and a conforming type cannot satisfy both. The columns
conform to `BidirectionalCollection` directly, beside the protocol. The cost is that a caller holding
a `ColumnProtocol<Element>` existential cannot iterate it without a cast; the rows are placed either
way, because the ledger matches on names.

## A slice is a view, and that needed a box

A `Column` is a struct, so a `ColumnSlice` holding one **by value holds a copy**, and a write through
the slice would land in that copy while the frame kept the old value. My first version worked around
that by making the slice's subscript read-only, with a comment explaining that a writable subscript
which does nothing is worse than a read-only one.

**The workaround was unnecessary and the comment was wrong**, because the read-only subscript was
never the reason the conformance failed — the second parameter name was. The right repair is to make
the column's storage reference-backed:

```swift
internal final class ColumnStorage<Element> { var values: [Element] }
```

`Column` holds the box; a slice holds the same box; a write through either reaches both. The slice's
subscript is get-and-set and genuinely writes through, which is what a view is.

**The aliasing that follows has to be stated, because a caller can now be surprised by it:**
`Column(_:)` — and so `frame["x"]` — is a **view**, and two of them are one column. A write through
either is a write through both. `init(copying:)` is the one that starts a column of its own, and
`.column` on a slice is a copy. A caller who wants independence asks for the copy; a caller who wants
a view of the frame's column gets one. The test checks both directions.

## The two rules a frame keeps

- It is keyed by **name**: adding a column of a name that is there *replaces* it, because two columns
  of one name is a frame with a column no caller can choose.
- A frame whose columns disagree on a height is **invalid** and says which heights, rather than
  padding the short column — a padded column is a table of invented data and every summary over it
  would be a summary of the invention.

An erased column read as a type it is not answers `nil` and not a column of zeroes: a category column
given away as numbers is the failure that avoids.

## What is not carried

The CSV and JSON readers and writers, the summaries (`NumericSummary`, `CategoricalSummary`,
`GroupSummaries`, `SummaryColumnIDs`), the grouping and aggregation, `RowGrouping`,
`SFrameReadingOptions`, `ShapedData` and `DataFrameProtocol`. `CreateML.MLDataTable`'s reader and
writer *are* carried and are the way in on this port today.

`tests/backports/host/createml/tabularframe.swift` holds the frame to the framework's documented
rules and to the conformances themselves — **132 checks, 0 failures**, beside CreateML's 96, the linear
models' 34 and the transformers' 35.
