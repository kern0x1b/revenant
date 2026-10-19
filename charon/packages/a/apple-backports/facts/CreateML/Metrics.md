# The metrics: what the port computes and what the host computes

`MLRegressorMetrics` and `MLClassifierMetrics` are the two types a caller reads to ask "how did it
do". Both are compared against **Apple's own metrics computed on the host**, by
`tests/backports/host/createml/metrics/` — **86 checks, 0 failures**. The predictions come from the
host's fitted model, so what is compared is the metric over one set of answers, not two different
fits; a port whose tree differed slightly would otherwise be blamed for a metric difference.

## The regression metrics

The host's predictions are read, and the port computes the metrics over them: `the RMSE of the host's
predictions, computed by the port` and `the maximum error of the host's predictions, computed by the
port`. The second is the one that catches the first's blind spot — an RMSE is an average and an
average is blind to a single catastrophically wrong row, so the maximum error is checked separately
and against the same predictions. The port's own metrics are then checked to be *valid* on a table
it can answer for, which is the check that the metric is defined where it is handed something it can
read rather than dividing by zero on an empty table.

## The classification metrics, counted from the rows

Every classification figure is counted from the two sequences of labels rather than accumulated, and
each count is checked twice — once against the closed form and once by counting the rows directly.
`a row-at-a-time count equals the two-sequence one` is the check that the two agree, because a count
accumulated over rows and a count computed from a confusion matrix are the same number reached two
ways, and a port that had them disagree would be one of them wrong.

The counts per label are the true count, the port's predicted count, the true positives, the false
positives, the false negatives and the true negatives; the figures built from them are the precision,
the recall and the F1, plus the example count, the labels seen and the accuracy.

**One host behaviour recorded rather than matched, and it is the check worth reading:**
`the host's count(predicted:) is not that, and is recorded`. The port's predicted count for a label,
counted from the rows, is compared against the host's `count(predicted:)`, and **they differ**. The
host's is recorded as it is, and the difference is not closed, because the port's is derived from
the predictions themselves and the host's is the host's own count — the two answer slightly different
questions, and a port that adjusted its count to match would be fitting a number rather than
computing one. This is the same shape as the leaf-regulariser difference in
[TabularData.md](TabularData.md): where the host does something the port does not, the record says so.

## The confusion matrix is a real shaped array

`makeConfusionMatrix()` returns an `MLShapedArray<Float>`, and that is checked as such rather than as
a flat list: `the port's matrix is a shaped array of the row by the column`, `with the strides a
row-major two-dimensional block has`, `the plain-array matrix is the shaped array's, cell for cell`,
`and the label order is published`, `the confusion matrix's shape`, and `the cell (\(answer),
\(guess))` for each cell. The strides check is the one that matters: a matrix with the right values
in the right cells and the wrong strides is a matrix that reads correctly when printed and wrong when
indexed, which is the failure a caller meets in `matrix[answer, guess]`.

`the label order is published` is checked because a confusion matrix whose rows and columns are
labelled in a different order from the one the caller expects is the same number in every cell and
the wrong number in every cell that matters.

## The four defects the closed form caught

The metrics are a closed form, and comparing the closed form against the host's own counted
implementation is what found these — each is a check against a measured oracle, never an expectation
copied out of the code under test:

- a **variance taken over the wrong axis**, so every stdev was the standard error;
- a **stdev divided by `n`** where the host divides by `n - 1`;
- an **accuracy counting only the rows where the host also predicted the majority**, so it agreed on a
  balanced table and disagreed on a lopsided one;
- a **confusion matrix returned as a flat array** with no row/column shape, so `[answer, guess]`
  could not be indexed and a caller summing a row got the sum of a run of unrelated cells.

The first two are in [TabularData.md](TabularData.md) where the aggregators are measured; they are
listed here too because the same two defects are what a metrics implementation gets wrong first, and
a reader arriving from either direction should find them.
