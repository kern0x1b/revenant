# The linear regressor and the logistic classifier

## What they are

`LinearRegressor<Scalar>`, `LogisticRegressionClassifier<Scalar, Label>`, and the two models they
produce. Both take a `MLShapedArray<Scalar>` — a shape, strides in elements, and the scalars — and
both are the **ridge** fit of `LinearAlgebra.swift`: a Gram matrix by the release's own
`cblas_dsyrk`, a Cholesky factor by the release's own `dpotrf_`, and the two triangular
substitutions in between. The feature matrix is row-major with strides `[columns, 1]`, which is the
order a fitted model's weights are already in, so a prediction is a dot product over the buffer the
fit produced and nothing is copied on the way out.

## What is not carried, and why it is not carried quietly

**The L1 penalty is proximal, and it does not match the framework (corrected 2026-10-16).** When
`l1Penalty` is non-zero, the components' fit runs `ProximalSolver.ridgeL1` for `maximumIterations`
and **throws** `LinearModelError.l1PenaltyDidNotConverge` when the KKT residual is still above the
tolerance at the last iteration; it does not return the point it stopped at. An earlier version of
this paragraph said the L1 penalty throws `l1PenaltyNotImplemented`; that was true before the
proximal solver and is not true now. What is true is in "The penalties" below.

**The iteration schedule is read and not used.** `maximumIterations`, `stepSize` and
`convergenceThreshold` are carried as configuration, because the surface names them and a caller sets
them. This port solves the normal equations directly rather than descending, so for a design that is
not rank-deficient and a penalty that makes it definite, the direct solve returns the minimum the
iterative scheme converges *to* — the same answer, without the loop. The parameters are kept so a
caller's code compiles and its configuration round-trips; they do not change the fit. That is a real
difference from the host and is named here rather than left to be found by a caller who expects ten
iterations of a gradient descent.

**`optimizationStrategy`** (`.normal`, `.conjugateGradient`, `.batchGradientDescent`, `.lbfgs`) is
carried as a value and the four do not behave differently, because they are four *routes* to the same
minimum and this port takes one of them. A caller selecting `.lbfgs` gets the direct solve, which is
the minimum `.lbfgs` would reach. A caller selecting a strategy for its *iteration count* rather than
its answer gets the same answer with fewer iterations.

**The intercept is penalised.** The penalty goes on the whole diagonal, intercept included. That is
the simpler reading of "an L2 penalty on the fit" and the normal matrix is one matrix, so exempting
the intercept would be a special case nothing asked for. The consequence is that the closed form for
a single feature is the two-parameter ridge, not `x'x/(x'x+p)`; the test checks the property a caller
relies on — a penalty shrinks the slope, and a bigger one shrinks it further — rather than a formula
that assumes a free intercept.

## The classifier's layout, and the one bug the test found

`coefficients` is **class-major over features**: one intercept per class first, then class 0's weight
for every feature, then class 1's, and so on. A two-class model over one feature has three numbers
in it, and `featureCount` is therefore `(coefficients.count - 1) / classes`, not `count - 1` — which
was the first version and which called a one-feature model a two-feature one and refused every
prediction of it.

The design matrix carries an intercept column of ones in front, exactly as the regressor's does. It
did not at first, and the solution came back one entry shorter than the reads of it, so a prediction
read past the end of the vector: an out-of-bounds trap in a fit, found by a test that builds a
two-class model and predicts with it.

## `MLShapedArray`'s strides, and the bug the test found

The strides are in **elements**, and the outermost dimension's stride is the product of the ones
inside it. The first implementation walked the dimensions with
`stride(from: shape.count - 1, to: 0, by: -1)`, and that range **stops before it reaches zero**, so
the outermost dimension's stride was never written: every two-dimensional array came out with
strides `[1, 1]`, and a row read was the wrong element. The test builds a 2x3 array and reads
`[1, 2]`, and the number it got back was `4.0` where `6.0` is the element. A one-dimensional array
was unaffected, which is why it took an array with two dimensions to find.

## What the test is, and what it is not

`tests/backports/host/createml/linearmodels/` holds these models against the **closed form**: a table
made from the line `y = 3 + 2*x1 - 1.5*x2` has to fit back to `[3, 2, -1.5]`, and a model built from
those coefficients has to reproduce the table. That is a stronger claim than "agrees with another
implementation of the same thing", because it cannot be satisfied by two wrong implementations
agreeing — and the two bugs above would both have passed such a comparison, since a wrong stride and
a wrong feature count are self-consistent within one process.

**It is not a host differential.** The host's own `LinearRegressor.fitted(to:validateOn:)` is
`async throws` over a `DataFrame`, and the two `fitted(to:)` overloads — one over feature vectors and
one over `AnnotatedFeature` — are distinguished by an argument type the two overlays spell
differently, so bridging it is its own work. `differential.swift` carries the twelve defects this
surface's differential found; this file is a different claim, from the same tree, and says so at the
top.

`AnnotatedFeature` and `AnnotatedPrediction` are here because the two `fitted` overloads are told
apart by their argument type and a tuple is not one: with a tuple the compiler resolves the closure
before it knows which overload is meant, and picks the wrong one.

## The L1 penalty, and the bug that was hiding in it

**Both penalties are now fitted.** `l2Penalty` by the closed form of `LinearAlgebra.swift`, `l1Penalty`
by the proximal iteration in `Proximal.swift`, and both at once by the L1 route with its quadratic term.
`l1Penalty > 0` selects the route and nothing else.

The first version **refused** an L1 penalty, on the reasoning that a fit which quietly dropped it
would hand back a confident number about a model nobody asked for. That reasoning was right and the
refusal was the wrong answer to it: the penalty is solvable, and refusing a thing that can be computed
is the same failure wearing a hat. Writing the solver is what showed that.

FISTA — accelerated ISTA — with the exact prox of the penalty on the smooth part's gradient step, the
step from the largest eigenvalue of `X'X/n` by **power iteration on the device's own BLAS** (the
matrix is already built and one symmetric matrix-vector product is cheap, where backtracking would take
twenty to reach a step the power iteration reaches in ten), the ISTA fallback at the accepted point
when the extrapolated one overshoots, and the **KKT residual** as the convergence test.

### Four defects, and the last one is the one that mattered

1. **A rejected step's objective was recorded as the reference.** The next comparison was then against a
   value the sequence never took, the convergence test never fired, and the run walked off: an
   objective of `1e140` with `converged = false`.
2. **The monotone fallback shortened the step from the *extrapolated* point `y`.** As `t` goes to zero
   that candidate tends to `y`, never to the accepted point `w`, so the sequence could not recover.
   The correct fallback, and what monotone FISTA specifies, is to take the step **at `w`** — one plain
   ISTA iteration — and halve only if *that* fails as well.
3. **The convergence test was the objective's movement.** It reported a point **0.07 of objective** above
   the minimum as converged, on a plateau. On a convex objective a stationary point is global, so the
   test has to be stationary-ness: the subgradient of `f + l1·|.|` at the point must be zero — for a
   coordinate at zero, `|g| <= threshold`; for one away from it, `g + l1·sign(w) = 0`.
4. **`softThreshold` had its two branches the wrong way round.** `sign(x) * max(|x| - l, 0)` was written
   as `value < 0 ? magnitude - l : -(magnitude - l)`, so **every positive coordinate came out
   negative.** This is the one that mattered, and it was hiding behind all three others: the sequence
   could not converge, and the wrong convergence test would not say so. With the sign fixed and the KKT
   residual as the test, the residual at a penalty of 0.5 is **5.9e-9** and the single-weight nudge
   check finds nothing that lowers the objective.

A sign error in a proximal operator is the most ordinary mistake in this method, and it took a test
with teeth to see, because a soft threshold that pushes the wrong way still *runs*.

### The test, and the mutation that survives it

`tests/backports/host/createml/l1/` — 14 checks, and deliberately the other way round from a
differential:

- the soft threshold on **both** sides of the kink, and a negative one keeping its sign — which is
  where a magnitude-only implementation loses, and where mutation 1 dies;
- the solver **converges**, and the point it returns is a minimum **by the KKT condition**;
- **no single-weight nudge lowers the objective** — 12 nudges of `0.01`, `0.05` and `0.2` in both
  directions. This is the check with teeth, and it is what caught defect 3: a point 0.07 of objective
  above the minimum moves downhill.

**What the suite still cannot catch:** removing the ISTA fallback at the accepted point (defect 2's
repair) leaves the suite green, because on this table the extrapolated step never overshoots and the
fallback never fires. The line is `Proximal.swift`'s `if objectiveAtW <= previousObjective` in both
solvers, and a test that makes the extrapolated point overshoot — a table where the condition
holds — is the next strengthening. It is recorded here rather than left for someone to rediscover by
running a mutation and seeing it pass.

### The scale mutation cannot be made red against this host, and the reason is measured

The mutation `l1Penalty / 2n` -> `l1Penalty / n` **passes every check in the suite**, on the
fifteen-row table and on the wide one, and I have stopped trying to make it fail. The reason is a
property of the host's optimiser, not of the port:

- On the **fifteen-row** table the host's own fit plateaus **5.4e-4** above the minimum, and the
  difference between the two scale factors is about **1e-3** there. They are the same size, so no
  comparison against this host can separate them.
- On the **wide** table (twelve features, three informative, one correlated, 160 rows) the host
  plateaus **2e-2** above the minimum and its coefficients are up to **4.25** away from the port's —
  and **every** factor, wrong ones included, beats the host's point at the port's objective. The host
  is far enough off the minimum that any different point wins, so the objective comparison is
  *satisfied by a wrong scale*.

So the check that can verify a convention against this host does not exist, and asserting one would
be asserting a falsehood. What is done instead, and is checkable:

- **The factor grid is pinned.** Over a grid of `l1Penalty` factors on the same rows, **0.5 per
  sample is the best at every one of eight penalties**, by a factor of five over its nearest rival. A
  change to the port's own scaling in the solver moves the winner and this goes red.
- **The support is pinned discretely.** On the wide fixture at a penalty of 1.0 the correct factor
  zeroes strictly fewer weights than a doubled one, and a wrong factor gives a *different set* — a
  difference of a set, not a fraction of a digit.
- **And the estimator's scale is verified by construction**: it is `l1Penalty / (2n)` in one place, in
  `LinearModels.swift`, with the factor's provenance in the comment above it.

### The convention, and the measurement that found it

**The port minimises `1/(2n)|X(Xw - y)|² + l2/2 |w|² + l1 |w|₁`**, with the **intercept
unpenalised** — it is column zero of the design and the penalty skips it, which is what makes a
penalty comparable across a target's own units.

**The host's `l1Penalty` is on a different scale.** Measured on the same twelve rows, both fitted, both
evaluated at the port's own objective:

| `l1Penalty` | the host's point | the port's point | lower |
| --- | --- | --- | --- |
| 0.0 | 0.070270271 | 0.070270270 | the port, by 1e-9 |
| 0.1 | **0.393352910** | 1.564355710 | **the host** |
| 0.5 | 1.650085721 | **1.543222290** | **the port** |
| 2.0 | 5.855339163 | **1.541666667** | **the port** |

At no penalty the two agree to nine places — the closed form is the convention-free claim, and it
holds. Away from zero they solve **different problems**, so the suite asserts what does not depend on
the convention and *reports* which side is lower at each penalty rather than asserting a claim the two
do not share. That is not the host being wrong: a penalty is a convention before it is an algorithm,
and the port's is the one its own `ridgeL1Objective` is written against, which is what makes the KKT
check and the objective comparison mean anything.

`LinearModelError.l1PenaltyDidNotConverge` is what a run that cannot reach the tolerance says, rather
than answering the point it stopped at. The tolerance is the caller's, and a caller who asks for more
digits than a few hundred thousand prox steps deliver is told so.

## Not carried, and why

- **`MultiLabelClassificationMetrics.mapLabels` is absent** while the single-label one is carried. A
  metrics over `T` built from one over `Label` is one line of storage copying, and this compiler
  resolves the `init()` of a *different* generic instantiation through a parent conversion that does not
  exist — accepted at one element type, rejected at another. The counts and the scores do not need it: a
  caller renames the labels before they reach a multi-label metrics, which is where a rename belongs.
- **`LinearModelError` is the port's own type.** The SDK 26.2 `CreateMLComponents` declares no such
  enumeration; its public errors are `OptimizationError`, `EstimatorEncodingError`, `DatasetError` and
  `ModelUpdateError`, and the surface has 0 rows for it. It is recorded in the package's own registry
  beside the code, and nothing reads it as a row of Apple's.

## The penalties: what MLLinearRegressor answers, and what it refuses (2026-10-16)

Measured on the host's own `MLLinearRegressor` and on the port, over the same 400-row table
(`x1` about 1000 in scale, `x2` about 1, `x3` about 100, `y = 3 + 0.002 x1 - 1.5 x2 + 0.5 x3 + noise`,
noise at most 0.1 either way). Training RMSE of each fit; `maximumIterations` at the framework's
default of 10 unless the row says otherwise.

| penalty | rescaling | host RMSE | port RMSE |
| --- | --- | --- | --- |
| L2 0 | on and off | 0.05755885 | 0.05755885 (difference 1e-14) |
| L2 0.01 (the default) | on | 0.05756005 | 0.05755885 |
| L2 0.1 | on | 0.05767871 | 0.05755885 |
| L2 1 | on | 0.06846152 | 0.05755887 |
| L2 10 | on | 0.36578034 | 0.05756071 |
| L2 100 | on | 2.91905023 | 0.05774509 |
| L2 1000 | on | 10.32341847 | 0.07381247 |
| L1 0.01, 0.1, 1 | on | 0.28142, 0.28133, 0.28050 (10 iterations); 0.08430, 0.08435, 0.08492 (100 and 1000) | 0.05760, 0.05760, 0.05770, the same at 10, 100 and 1000 iterations |

What this says:

- **The unpenalised fit is the framework's.** The closed-form path agrees with the host to 1e-14 on
  both rescaling settings. The feature rescaling is a centring and scaling of each column, carried back
  into the caller's units, and it changes nothing when there is no penalty.
- **The penalised fit is a different model.** The host's error rises steeply with L2, to a near-null
  model at L2 1000, which a ridge closed form on these features does not do at any scale this port's
  penalty reaches. A constant rescaling of the penalty does not reconcile the two: L2 0.01 on the host
  is near L2 10 on the port at small penalties and then diverges (1 against 1000 is off by 1%).
- **The host's answer depends on `maximumIterations`** for L1 (10 against 100 changes the RMSE from
  0.28 to 0.084), and the port's does not. Matching the host means reproducing its optimiser, which is
  measured and not read here. Until that is done the port does not answer a penalised fit.

Decision: `MLLinearRegressor(trainingData:...)` **refuses** any non-zero `l1Penalty` or `l2Penalty` with
`MLCreateError.penaltyNotMatched`, and the default parameters carry the framework's L2 of 0.01, so the
default constructor is refused too. The refusal is named, the host's answer is printed beside it by the
host differential, and nothing returns a number the framework would not. This is an open item in the
registry, not a resting place.
