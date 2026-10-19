# The feature transformers

Seven of them, and every one is the same shape fitted to a column and then applied: `StandardScaler`,
`MinMaxScaler`, `MaxAbsScaler`, `RobustScaler`, `OneHotEncoder`, `OrdinalEncoder`, `NumericImputer`,
and `LinearTransformer`.

## The one rule all of them follow

**The statistics come from the fit and are never recomputed as they go.** A scaler that recomputed its
mean while transforming would be a different function of the same input depending on what it had
already seen, and a pipeline of two of them would not be a pipeline at all. So each transformer is a
value holding its statistics, and a fitted transformer is *carried with* the model — which is the
reason a transformer exists rather than being a step inside the fit: once the data is standardised,
the mean and the spread are gone, and a caller who wants to report a prediction in the column's own
units has nothing to divide back by.

## Each one, and what makes it that one

- **`StandardScaler`** divides by the **unbiased** standard deviation, over `n - 1`. A column
  standardised by the population deviation is a different function of the data, and the two differ most
  on a short column — which is where a caller notices, because the model's coefficients come out
  scaled.
- **`MinMaxScaler`** scales over the column's **observed** extremes, so a value outside them lands
  outside the range. Clamping them to the ends would be a different function, and it is the one a
  caller reading a "min-max scaled" column usually does not expect. Its `range` is a parameter and is
  kept: the first version hard-coded `0...1` in the fit's initialiser, and a
  `MinMaxScaler(range: -1...1)` came back scaling into `0...1` anyway. A configured parameter
  silently discarded, and the transformer's own test found it.
- **`MaxAbsScaler`** divides by the largest magnitude, so every value lands in `-1...1`. A column of
  all zeros has no magnitude and is passed through.
- **`RobustScaler`** centres on the **median** and scales by the **median absolute deviation**,
  times the usual 1.4826 that makes a MAD comparable with a standard deviation. This is the whole
  difference from `StandardScaler`: on `1, 2, 3, 4, 100` the robust scale leaves the four ordinary
  values far apart, and the mean-and-deviation of 22 and 43.9 compresses the whole column together.
  A caller who wants no magnitude between the categories wants a one-hot encoder; the magnitude is the
  difference between the two encoders and is the reason an ordinal code is not interchangeable.
- **`OneHotEncoder`** makes one binary column per category, in the order the fit found them, and
  encodes **only string columns**. Reading a double column as categories would give the numbers
  "1.0", "2.0" as categories and a column for each — a table nobody wrote — so the fit looks at the
  column's own kind. A category the fit never saw is an all-zero row and not a new column: a fitted
  transformer's output has a fixed width.
- **`OrdinalEncoder`** writes the category's rank, in the order the fit found it. A category the fit
  never saw is **missing** and not the first rank: a rank of zero would put an unseen value in the
  first class, which is a claim about data the fit never saw.
- **`NumericImputer`** fills with the mean of the values that are **there**. A column of `1, gap, 3, 4`
  is filled with 8/3 and not with 2 — counting the gap as a zero would pull every imputed value toward
  zero by a quarter. A column with nothing in it is filled with zero *and named* on
  `imputedEverything`, because there is no mean of no values and a caller who has such a column
  should hear about it.
- **`LinearTransformer`** is `y = scale*x + offset`, fitted from the data and kept, which is the point:
  a model fitted over an unscaled column cannot tell the caller what the column's spread was.

## A constant column

Every scaler meets one, and the answer is the same: **the spread is set to one**, so nothing divides by
zero. A NaN in the design matrix poisons every coefficient fitted after it, and a constant feature
contributes nothing to a fit anyway. The values are then centred (the standard scaler gives a
constant column all zeros, which is correct — the column carried no information) or scaled to unit
magnitude (the max-abs one gives all ones), and the test checks each of those rather than a single
"passes through" that would be true of none of them.

## What the test is

`tests/backports/host/createml/transformers/` holds each transformer to **the arithmetic its name
says**, on data whose answer is known by hand: `1, 2, 3, 4` has mean 2.5 and unbiased standard
deviation `sqrt(5/3)`, and the three refusals — an unseen category, a constant column, a column with
nothing in it — are each checked rather than assumed.

It is not a host differential, and says so at the top: the port's `CreateMLComponents` is its own
module and the host's transformers are declared against a `DataFrame` spelled differently, and bridging
that is its own work. This test found the two bugs above, both of which would have passed a
differential against a second implementation of the same thing, because a wrong range and a wrong
column selection are self-consistent within one process.
