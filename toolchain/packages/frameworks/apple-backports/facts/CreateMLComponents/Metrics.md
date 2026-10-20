# Classification and regression metrics, and one place the host is wrong

## The counting, and why it is incremental

A metrics object is something a caller fills **row by row** as a model predicts — a live model's
confusion matrix, a cross-validation fold — so the counts are the state and every score is read from
them. A type that could only be built from two whole sequences would answer the question a caller has
at the end and not the one they have at the thousandth row.

Per label, the state is three numbers: how many rows carry that label as their **answer**, how many
were **predicted** as it, and how many were predicted as it *and* are it — the true positives. The
other three follow:

| count | definition | read as |
| --- | --- | --- |
| `truePositiveCount(of:)` | predicted as it, and it | a hit |
| `falsePositiveCount(of:)` | `predicted - hits` | the model said it and it was not |
| `falseNegativeCount(of:)` | `truth - hits` | it was and the model did not say it |
| `trueNegativeCount(of:)` | `n - tp - fp - fn` | everything else |

The true-negative row is the one with an order in it, and the first version got it wrong: it read
`n - count(label:) - fn` and then subtracted the false positives, which double-counts the false
negatives. The host's own numbers caught it — on eight rows the host's `trueNegativeCount` is 6, 3, 4
and 7 for the four labels, and the formula above is the only one that gives those.

## The scores, and why F1 is the harmonic mean

`precision` is the true positives over the predictions; `recall` is the true positives over the true
count; **F1 is their harmonic mean and not their arithmetic one.** A model with a precision of 1 and a
recall of 0.01 has an arithmetic mean of 0.505 and a harmonic mean of 0.02, and the first number is a
lie about a model that finds almost nothing. The test separates the two on purpose: the same table
where the *signed* mean error cancels to −0.25 has a mean absolute error of 2.25, and a check that did not
distinguish them would pass if either were wrong.

## Multi-label, where the difference is the row

`MultiLabelClassificationMetrics` takes a **set** of labels on each side, because a row can carry
three and be right about all three. There is no single "the answer", so every count is per label and
per row, and the score that means anything is the **exact-match** one: a model that finds two of three
labels has found none of the row, and a score that counted it would be scoring a different model.
A row is exactly right when every label it carries was found **and** the model invented none.

## One measured divergence from the host, kept rather than copied

**`ClassificationMetrics.count(predicted:)` answers 0 for every label on the host.** Measured on eight
rows whose predictions are three `cat`, three `dog`, one `bird` and one `fox`: the host answers 0 for
all four, and answers 1 for `count(predicted:label:)` — which is its *true positive* count, the same
number, so the counter it would need is the one a false positive is already derived from.

The host's `precisionScore` and `recallScore` are **right**, and they are not built on that counter, so
the defect is confined to the one member. The port answers the real number. A port that answered 0
would agree with the host and be wrong about a caller's model, and "agree with the framework" is not a
reason to reproduce a number no framework's own scores use.

## What the host's own numbers are, for the reader who wants to check the definitions

The eight rows the differential uses — predicted and answer:

| label | `count(label:)` | `count(pred:label:)` | tp | fp | fn | **tn** | P | R |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bird | 2 | 1 | 1 | 0 | 1 | **6** | 1.0 | 0.5 |
| cat | 3 | 1 | 1 | 2 | 2 | **3** | 0.333 | 0.333 |
| dog | 2 | 1 | 1 | 2 | 1 | **4** | 0.333 | 0.5 |
| fox | 1 | 1 | 1 | 0 | 0 | **7** | 1.0 | 1.0 |

Accuracy 0.5 over the eight rows. The port's numbers are these, which is what the differential checks.

## The regression measures, and the length they insist on

`RegressionMetrics` has six free functions over two columns — `rootMeanSquaredError`,
`meanAbsoluteError`, `meanAbsolutePercentageError`, `maximumAbsoluteError`, `meanError`, and
`meanAbsolutePercentageError`'s denominator — and every one of them **preconditions that the two columns
are the same length**. A `zip` of two columns of different lengths silently reports the metrics of the
shorter one, and a root mean squared error over the wrong rows is a number that looks entirely
reasonable. The same precondition is on both metrics types' row-wise `add`, for the same reason.

`meanAbsolutePercentageError` divides each error by the magnitude of its own target, and a target of
zero makes that row's share infinite. It is computed as the mean of those shares and returns `NaN` when
every target is zero, which is the only answer that is not a division by nothing.

## Not carried, and why

- **`makeConfusionMatrix()` returns `[[Int]`, not CoreML's `MLShapedArray<Float>`.** The framework's
  type is a shaped array and the port's overlay is what this series is building, so the matrix is
  computed here and a caller who wants the framework's type casts it. The counts are the same either
  way and the differential checks every cell against the host's own matrix, read through
  `withUnsafeShapedBufferPointer` because the host's `subscript(indices:)` answers a one-element slice
  and not the number a cell is. **A port of `MLShapedArray` is a real gap here** and is the next thing
  on this surface.
- **`MultiLabelClassificationMetrics.mapLabels` is absent** while the single-label one is carried. A
  metrics over `T` built from one over `Label` is one line of storage copying, and this compiler
  resolves the `init()` of a *different* generic instantiation through a parent conversion that does
  not exist — the same construction is accepted at one element type and rejected at another. The counts
  and the scores do not need it: a caller renames the labels before they reach a multi-label metrics,
  which is where a rename belongs.
