# The preprocessing wrappers

## What a pipeline is, and the one thing it adds

A pipeline is not a new algorithm. `PreprocessingEstimator(scaler, forest)` **is** a scaler and a
forest. What it adds is one thing: the fitted preprocessor travels **with** the fitted model, so a
prediction goes through the very scaler the fit used. Without that, a caller who standardises by the
training mean and predicts on new data has to remember to standardise again, and the first time
someone forgets it the model's numbers are wrong and nothing reports it.

So the type is a pair plus a composition, the fit is two fits, and `fitted(on:)` is the convenience
that runs both — because a caller who wants to look at the intermediate has `preprocessed(from:)`.

## The one semantic that is genuinely different: a supervised pipeline's target

**The preprocessor is fitted over the features only, and the target column is put back untouched.**

Scaling a target is a different model and not this one. A tree's thresholds and a logistic
regression's coefficients are both in the *target's own units*; a target that was standardised and not
put back is a column the caller never wrote, and every coefficient then reads in units of the
target's standard deviation rather than of the target. The first version transformed the whole table,
and the test caught it: the estimator's mean came back `0.0` where the table's mean is 17. **The
arithmetic was right and the column was the wrong one.** The test now checks both halves — the features
standardised, and the mean 17 in the target's own units.

## And the one that is the whole of `Updatable`

An update preprocessed the input **by the preprocessor the fit produced** and moved the inner
estimator, and did **not** refit the preprocessor. Refitting it would change the features the
estimator was fitted on, which is a different model rather than an update.

The test compares the preprocessor's statistics **before and after** an update, byte for byte,
because "did not throw" would not catch a refit. `makeTransformer()` is the **unfitted** pipeline and
its preprocessor has no statistics yet — pinned too, because a wrapper that fitted the preprocessor
there would be a pipeline whose features move under the very first update.

## The four names, and what `Updatable` changes

`Preprocessing{Estimator, SupervisedEstimator, UpdatableEstimator, UpdatableSupervisedEstimator}` is
the same shape over four axes, differing only in which estimator protocol the inner one answers to and
whether it can be updated.

The framework also has `PreprocessingTabularEstimator` and
`PreprocessingUpdatableTabularEstimator`; **those are absent here** and are next, because the tabular
protocols are written over `DataFrame` and the `DataFrame` work is not done. Declaring them over
`ColumnarTable` under the framework's names would be a row saying something the type does not do.

## The estimator protocols, and what is deliberately not in them

`TabularEstimator`, `Estimator`, `SupervisedEstimator`, `UpdatableEstimator` and
`UpdatableSupervisedEstimator`, over `ColumnarTable` and `RowMatrix` — the table and the design
matrix this package has. The framework writes them over `DataFrame`; the shape is the same.

`TemporalSequence`, `TabularSequence` and the shaped-array `Input`/`Output` associated types are
**not** here: they need the `DataFrame` and `MLShapedArray` work that is next, and a protocol naming a
type this package does not have would be a declaration nothing can conform to — which is the thing a
row is not allowed to be.

`SupervisedEstimator` here does **not** refine `Estimator`. The framework's does, and refining here
would force every supervised type to answer an unsupervised fit as well, which no type in this package
does.

## The two shapes this compiler made me change, and why each is recorded

- **`preprocessed(from:)` answers the table, not a pair of `(preprocessor, table)`.** An unlabelled
  two-tuple return is a shape this compiler handles badly, and a named method says more anyway: the
  fitted preprocessor is `Transformer.preprocessor`.
- **The pipeline's generic parameter is `Base`, not `Estimator`.** The parameter and the protocol have
  the same name, so `Estimator: Estimator` resolves the constraint to the parameter and the type is
  rejected as *"constrained to non-protocol, non-class type"*. The framework's own declarations have
  the same pair; a caller cannot see the difference and a reader diffing this against the header can.

## What the test is

`tests/backports/host/createml/preprocessing/` — **19 checks, 0 failures.** A pipeline adds no
arithmetic, so the checks are about the two things it does change: the preprocessor's statistics
travel with the model and its arithmetic is the port's own scaler's, which the transformers suite
already holds to the closed form; and an update moves the inner estimator and leaves the
preprocessor's statistics as the fit left them.

Two estimators the test supplies, because a pipeline needs something to wrap: a mean-of-the-target one,
and a counter that records whether the column it read was the preprocessed one — which is how a caller
can see that the pipeline fed the estimator what it meant to.

## OPEN: does a pipeline *use* the preprocessor it was given?

**The claim the probes support is "does not fit". Whether it *uses* the preprocessor is unmeasured, and
the difference matters.**

All four preprocessing probes use the host's own `LinearTransformer` as the instrument, and three of
them use it at **`scale: 1, offset: 0` — the identity**. With an identity preprocessor, "the pipeline
transforms through the preprocessor it was handed" and "the pipeline ignores the preprocessor and hands
the input back" are **indistinguishable**: both answer `[1, 2, ..., 8]`, which is what the probes
recorded. So the three answers are real and they do not settle this.

A **non-identity** preprocessor separates the two: `scale: 2` doubles and an `offset` shifts, so
unchanged values would mean the preprocessor is ignored. The probe written for that is
`tests/backports/host/createml/probe/preprocessor-applied-host.swift` and **it does not build**:

    $ xcrun swiftc -typecheck preprocessor-applied-host.swift     # passes - the conformers are right
    $ xcrun swiftc -O      -o … preprocessor-applied-host.swift
    error: compile command failed due to signal 6 (use -v to see invocation)
    $ xcrun swiftc -Onone  -o … preprocessor-applied-host.swift
    error: compile command failed due to signal 6 (use -v to see invocation)

So this is a swiftc crash and not a type error, and the probe is committed as a **question rather than
as evidence** - its `.txt` says so in the same words. Which construct crashes swiftc is itself
unmeasured and is the next thing to bisect.

**What turns on it.** The port's pipelines now transform through the preprocessor they were handed -
that is the measured behaviour for the two the probes covered, and the third is unmeasured. A caller who
passes an **unfitted** preprocessor is the case where the two readings differ: if the host applies it,
the values move; if the host ignores it, they do not. The port cannot be shown right for that caller
until the probe builds.

### Which construct crashes swiftc - bisected, and the reduction stops here

`preprocessor-applied-host.swift` type-checks and then aborts the compiler. Bisected from a copy under `.agent-work/runs/probe-bisect/`, with the same `xcrun swiftc -Onone`
the other probes use, and **from the full path of the probe in this tree** -
`tests/backports/host/createml/probe/preprocessor-applied-host.swift`:

    $ head -34 tests/backports/host/createml/probe/preprocessor-applied-host.swift > ctl.swift && xcrun swiftc -Onone -o ctl ctl.swift     # the control: BUILDS
    $ head -40 tests/backports/host/createml/probe/preprocessor-applied-host.swift > p40.swift  && xcrun swiftc -Onone -o p40 p40.swift     # expected '}' in struct
    $ head -56 tests/backports/host/createml/probe/preprocessor-applied-host.swift > p56.swift  && xcrun swiftc -Onone -o p56 p56.swift     # signal 6

**The control is the first conformer alone** - the `Estimator` one, lines 23-34, closed at 34 - and it
compiles. Adding the second conformer, `struct SupervisedRecorder: UpdatableSupervisedEstimator` at
lines 37-57, aborts. The crash therefore needs **a second, complete** conformance to
`UpdatableSupervisedEstimator` in a file that already has a complete `Estimator` conformance, whose
nested `Transformer` carries `typealias Input`, `typealias Output` and an `async throws applied`.

**What the reduction rules out.** An *incomplete* second conformer does not crash - it reports
`type 'Second' does not conform to protocol ...` - whether the protocol is `UpdatableSupervisedEstimator`,
`UpdatableEstimator` or `Estimator`, and whether the nested `Transformer` carries `firstSeen`, the
`async applied`, or both. An empty plain struct after the control compiles. So the crash is not "two
conformers in a file", not one particular protocol, and not a single member of the second one: it needs
the whole second conformance to type-check and then aborts in the compiler.

**Not reached.** Which part of the compiler this is - the conformance checker walking two instantiations
of the same protocol family, the `Transformer` nested-type resolution, or the async witness - is not
determined, and narrowing it further needs a different instrument than deleting lines. The reduction
above is a boundary, not a cause, and the open question stands until a probe builds.
