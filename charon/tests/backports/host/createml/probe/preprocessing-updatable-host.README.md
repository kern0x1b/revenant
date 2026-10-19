# The host's `PreprocessingUpdatableSupervisedEstimator` — not yet measured

**This probe does not compile.** It is committed as a record of what was tried and what the host's API
turned out to require, so the next attempt starts from there rather than from scratch.

## The question

Does the host's `PreprocessingUpdatableSupervisedEstimator` fit its preprocessor, and if so when —
at `makeTransformer()` or at the first `update(_:with:)`? `makeTransformer()` takes no data, so a fit
can only happen at the first update, or never.

The port's answer, from `Preprocessing.swift:168` and `:174`, is **never**: `makeTransformer()` hands
the preprocessor to `ComposedTransformer.init` (line 33) which stores it as given, and `update(_:with:)`
transforms through it after removing the target. The port therefore feeds the inner estimator the raw
column.

**There is no red case here, and there is not one to look for.** A case named `a supervised updatable
pipeline's estimator is fed the preprocessed feature` was written from the reasoning above and it
*was* red - it expected a preprocessed -7 for x = 1...8, which is what a fitting pipeline gives. That
expectation was **wrong**: the host's answer is 1.0, the raw column, so the port was right and the -7 was
this file's error in reasoning. The case in `preprocessing/main.swift` is now

    a supervised updatable pipeline's estimator is fed the raw column, as the host feeds it

which passes with this probe cited. The -7 was never committed as a failure, and a reader going looking
for a red preprocessed-feature case will not find one.

## What the host's API requires, learned

From the macOS SDK's `CreateMLComponents.swiftinterface`:

- `PreprocessingUpdatableSupervisedEstimator` (line 5604) stores `preprocessor` and `estimator` as
  **public `var`s**, so a probe can read the transformer's own preprocessor and see whether it is
  fitted — that is the instrument, and it needs no private access.
- its `makeTransformer()`, `preprocessed(from:)` and `fitted(toPreprocessed:)` are `@inlinable`, so their
  bodies are Apple's and are **not** transcribed anywhere. The probe measures instead.
- the pipeline's `Preprocessor` must conform to `Transformer`, and **`RobustScaler` does not** — it is an
  `Estimator`. A preprocessor has to be a `Transformer`, so the scaler is not usable here directly.
- `UpdatableSupervisedEstimator` (line 5433) refines `SupervisedEstimator`, so a conformer needs
  `fitted(on:)` as well as `makeTransformer()` and `update(_:with:)`, plus
  `encodeWithOptimizer`/`decodeWithOptimizer`.

## What failed

Two attempts, both in this file's history:

1. `RobustScaler<Double>` as the preprocessor — rejected at the generic constraint: it conforms to
   `Estimator`, not `Transformer`.
2. a custom `FittablePreprocessor: Transformer, Hashable` and a `Recorder: UpdatableSupervisedEstimator`
   — rejected with `does not conform to protocol 'Transformer'` and `does not conform to protocol
   'SupervisedEstimator'`, and the compiler did not name the missing members.

**The next step** is to read what `Transformer` and `SupervisedEstimator` require in that interface
(their associated types and the members each demands) and give the two conformers exactly those. The
rest of the probe is written and its output lines are what the port's behaviour must match:

    after makeTransformer(): preprocessor centre = nil        -> unfitted
    after the first update(): the estimator saw 1.0           -> the port's answer, if the host agrees
    and the transformer's preprocessor centre is nil
