# The table, its columns, and the six estimators on top of them

`MLDataTable` and the types around it are the surface an application actually names: the table, its
columns, the value in a cell, the two join kinds, the aggregators, the split strategies, the error
types, and the six estimators with their six fitted models. This is where the measurements behind
those rows live.

Every number here was read off **Apple's own `MLDataTable` on the host**, not off the port, by
`tests/backports/host/createml/differential.swift` — a differential that runs the same table through
both implementations in one process and compares what comes out. That suite is **100 checks, 0
failures**, and the port's own suite is at **489 checks across 8 suites**. Counts are not typed: the suite's own run prints them, and the counts here are what that run printed,
prints the per-suite figures and the total, and checks this file's number against them. Where the two disagree the
differential is what caught it, and the four defects it found are named below with the check that
found them.

## The table and its columns

The table reads a file, keeps a row count, and answers its columns by name and by position, with the
type of each (`the type of the column \(name)`). A column of `Int` reads as a column of `Int`, a
column of `Double` as a column of `Double`, and a column of text as a column of `String` — checked
by the three checks `the ids read as a column of Int`, `the sizes read as a column of Double` and
`the cities read as strings`, which is the distinction the whole tabular surface rests on: a column
of numbers and a column of strings are not interchangeable, and a port that read both as `Double`
would silently accept a date.

`debugDescription` on the three value shapes answers a string and does not return itself — checked as
`a sequence value's debugDescription is a string` and
`a sequence value's debugDescription is not its own getter`. The second is the interesting one: a
`debugDescription` that hands back its argument is not a description at all, and a host differential
that prints one side and compares strings would hang or trivially agree on it.

**The empty cell is not a missing value, and that is checked:** `an empty cell reads as the empty
string` and `an empty cell is not a missing value`. A CSV with `a,,b` has a cell that is the empty
string, and a port that read it as `nil` would report the row as incomplete and drop it from every
mean, every stdev and every fit. The two checks together are what pins the difference.

## The aggregators, the join and the split

The nine aggregators are each compared against the host's: `the sum of the prices is computable on
both sides`, then the value, and the same shape for the mean, the stdev, the min, the max, the prices
in increasing order, the rooms in decreasing order, the number of distinct cities, the number of rows
with nothing missing, and the number of distinct rows. `the sum of the prices is computable on both
sides` exists as its own check because a port whose aggregator was simply absent would otherwise
look like a port that computed the wrong sum.

**Two defects the closed form caught here**, both of the shape the corpus contract cares about:

- *a reversed variance* — the port's variance was `mean((x - mean)^2)` over the wrong axis, so every
  stdev it reported was the standard error rather than the spread. Found by the stdev check
  disagreeing with the host's.
- *a stdev divisor* — the port divided by `n` where the host divides by `n - 1`, the sample standard
  deviation. Found by the same check on a second table.

Both are the kind of error that never crashes and is always wrong, which is why each is a check
against the host rather than a closed-form expectation copied from the code.

The join is compared for both kinds: `the row count of a \(kind.rawValue) join`, `the id column of a
\(kind.rawValue) join` and `the region column of a \(kind.rawValue) join` — the outer and the left.
The left join is the one that can go wrong quietly, because a dropped row still produces a row count
that looks plausible, so the two columns are checked and not only the count.

The split is checked in the four ways it can be wrong: `a random split's halves are near the
proportion`, the same on the host, `a random split covers every row once` (no row lost, none
duplicated), `a seeded split is the same split twice` (the seed is honoured), and
`a per-row draw does not answer exactly n*p every time` — that last one is a check that the draw is
*not* deterministic in its count, which a port that returned exactly `n * p` rows would fail.

## The six estimators

Each is fitted on the host and on the port from the same table, and the *predictions* are compared —
not the coefficients, which are not required to match. For the decision-tree regressor the checks
are `the number of predictions from a decision tree`, `the port's decision tree finds the step`,
`the port predicts one value for the whole lower half`, `the port predicts one value for the whole
upper half` and `the port's two halves differ`: the model is asked for a prediction over a column
that is one half below a threshold and one above it, and it must answer a single value per half and
those two values must differ. A port that returned the training mean would satisfy the first two and
fail the last.

The classification error of the decision-tree and random-forest classifiers is compared with the
host's, and `a decision-tree classifier separates two classes` is the check that the model is doing
something at all rather than answering the majority class.

**One host behaviour recorded rather than reproduced:**
`the host's error is its leaf regulariser, not a failure to fit`. Apple's host answers an error where
the port answers a fit, and the differential records that instead of treating it as a disagreement —
because a host that refuses to fit a tree is making a statement about its own defaults, and a port
that matched it by refusing would be refusing for a reason the caller cannot see.

## The error types, and the one refusal

`MLDataTableError`, `MLColumnError`, `MLClassifierMetricsError`, `MLRegressorMetricsError`,
`MLCreateErrorCode`, `MLDataValue`, `MLDataValueConvertible`, `JoinType`, `PackType`,
`MLSplitStrategy`, `MLDataTableAggregator`, `Aggregator`, `MLDataTableParsingOptions`,
`MLUntypedColumn`, `MLDataColumn`, `MLDataColumnSlice`, `MLTrainingDataSplit`,
`MLTrainingDataValidation`, `MLTrainingDataValidationData`, `TabularEstimatorCore` — each of these is
carried and its members are its own, checked by the suite above.

**The one API in this group that is `absent` rather than `implemented` is `write(to:)`**, and it is
six rows rather than one. Apple's writes a model for all six estimators; the port refuses with
`MLCreateErrorCode.cannotWriteModel`, case 6. The error, the reason and what would move the rows to
`implemented` are in **[Export.md](Export.md)** — that file is where the export lives, and a row
about the export pointing at this one would send the next reader to the wrong measurements.
