# The preprocessing pipelines: which of them fit their preprocessor, and how that is decided

The host was asked, one probe per type, with the host's own `LinearTransformer` as the instrument — a
*fitted* linear transformer has non-identity `scale` and `offset` while an unfitted one is the identity,
so "was it fitted" is two numbers read off the transformer's public `inner`. Nothing here is
transcribed from Apple's source; every value is read out of the running framework.

## The mechanism, and the check that constrains it

A pipeline's `Preprocessor` is a **`Transformer`**, and the `Transformer` protocol
(`CreateMLComponents.swiftinterface` line 1853) requires only `Input`, `Output` and
`applied(to:eventHandler:)` — there is no `fitted(to:)` on it. So the pipeline cannot fit its
preprocessor, and fitting is a separate step the *caller* performs.

**The check, with its command, its count and its controls.** A type's conformance clause is the text
between its name and the first `where` or `{`, and membership of both protocol names is tested **in
that clause alone**. That is what makes the answer unfoolable: a generic parameter *named* `Estimator`,
and a `where Preprocessor : Transformer` constraint, each put both words on one line without either
being a conformance.

    # the discriminator probe (removed) printed the lines below:
        /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/\
CreateMLComponents.framework/Modules/CreateMLComponents.swiftmodule/arm64e-apple-ios-macabi.swiftinterface

    POSITIVE control - two types conforming to both: 2
       BothOnAContinuation
       BothOnOneLine
       expected ['BothOnAContinuation', 'BothOnOneLine'] -> CONTROL PASSES
    NEGATIVE control - one of the two, in each order, with Transformer only as a parameter and a
       where clause: 0
       expected [] -> CONTROL PASSES
    BOUNDARY control - a second protocol after an early where: 0
       note: the emitter cannot produce this - conformances precede where - so this pins the
             boundary of the parser rather than defending a reachable case
       expected [] -> CONTROL PASSES

    real interface: arm64e-apple-ios-macabi.swiftinterface
       types whose conformance clause names BOTH Transformer and Estimator: 0
       TransformerToEstimatorAdaptor's clause: [<Transformer> : CreateMLComponents::Estimator]
          names Transformer: False  names Estimator: True  -> listed: False
       PreprocessingEstimator's clause: [<Preprocessor, Estimator> : CreateMLComponents::Estimator]
          names Transformer: False  names Estimator: True  -> listed: False

    controls: positive PASS, boundary PASS, negatives PASS

**The count is 0: no type in the framework conforms to both `Transformer` and `Estimator`.** Two
earlier attempts got this wrong and both are worth recording, because they are the shapes the check
has to resist:

- *a grep for both words on one line* reports **18**, every one a `Preprocessing*` pipeline whose
  generic parameter is named `Estimator` and whose `Preprocessor` is constrained *to* `Transformer`;
- *a two-alternative grep* reports **2**, and reading those two lines suggested one of them was
  `TransformerToEstimatorAdaptor` conforming to both. **It does not.** Its conformance clause is
  `<Transformer> : CreateMLComponents::Estimator` — it conforms to `Estimator`, and the `Transformer`
  in it is a *generic parameter name*.

**The positive control has to be synthetic**, because the real interface contains no type conforming to
both and so cannot show that the tool is able to answer yes at all. It is a scratch text with both
protocols on one line after the name, and in a two-line continuation form, and the discriminator must
list both. A discriminator that matched nothing would otherwise report 0 for the right reason and give
a reader no way to tell that from a broken parser.

So the rule, with the count known:

- a `Transformer` has no `fitted(to:)` of its own, and **a pipeline never fits its preprocessor**;
- a caller who wants a fitted preprocessor reaches it through `TransformerToEstimatorAdaptor`, which is
  an `Estimator` wrapping a `Transformer` — so fitting the adaptor yields a fitted `Transformer` to
  hand to the pipeline.

"The host never fits the preprocessor" is a statement about the **pipeline**, and not a prohibition on
fitting a `Transformer` at all.

## One line per type

| type | the port | the host | evidence |
| --- | --- | --- | --- |
| `PreprocessingUpdatableSupervisedEstimator` | **does not fit** — `makeTransformer()` (line 168) hands the preprocessor to `ComposedTransformer.init` (line 33), which stores it as given | **does not fit** — `scale=1.0 offset=0.0` after `makeTransformer()`, after the first update and after the second | `tests/backports/host/createml/probe/preprocessing-updatable-host.swift` and its `.txt` |
| `PreprocessingEstimator` | **fitted** — `preprocessed(from:)` line 56 and `fitted(on:)` line 61 both called `preprocessor.fitted(on: training)`; now neither does | **does not fit** — `scale=1.0 offset=0.0` after `fitted(to:)`, and `preprocessed(from:)` returns the raw `[1, 2, 3, 4, 5, 6, 7, 8]` | `tests/backports/host/createml/probe/preprocessing-estimator-host.swift` and its `.txt` |
| `PreprocessingUpdatableEstimator` | **fitted** — `preprocessed(from:)` line 136; now it does not | **does not fit** — `preprocessed(from:)` returns the raw `[1, 2, 3, 4, 5, 6, 7, 8]` | `tests/backports/host/createml/probe/preprocessing-updatable-estimator-host.swift` and its `.txt` |

## A divergence in the API surface, in the same family

**A claim withdrawn: there is no `transformed(_:)` on any of the three pipelines.** Two reports - mine
and the coordinator's instruction that followed it - said the port had `transformed(_:)` at
`Preprocessing.swift:57` and `:137` and that it was a third invented public name. There is no such
member. Lines 57 and 137 are **body** lines inside `preprocessed(from:)`, calling the *preprocessor's*
`transformed`. The pipelines' public members are `preprocessed(from:)`, `fitted(on:)`,
`featuresOnly(from:)`, `makeTransformer()` and `update(_:with:)`, and `grep -n 'public func
transformed'` over the file returns nothing. The check that would have caught it is one `grep` for a
declaration rather than a call, and I read a body line as a declaration twice.

**Nothing in the tree calls a pipeline's `transformed(_:)`.** The `.transformed(` calls that remain are
on the scalers themselves - `standard.transformed(numbers)` and the rest in the transformers suite -
which is `ColumnarTransformer`, a different type, and correct there.

**Still OPEN: does a pipeline *apply* the preprocessor it was given?** The three probes all used
`LinearTransformer(scale: 1, offset: 0)`, the identity, so they cannot distinguish "transforms through
the caller's preprocessor" from "ignores the preprocessor and hands the input back". A non-identity
preprocessor separates them, and the probe written for that does not build - `swiftc -typecheck` passes
and then both `-O` and `-Onone` abort with signal 6. The question and the probe's path are
`tests/backports/host/createml/probe/preprocessor-applied-host.swift`, whose `.txt` records the failure.
The claim "does not fit" is measured; "does not use" is not, and the distinction bears on what a caller
who passes an *unfitted* preprocessor should expect.

**All three types, measured, and the port fits two of them where the host fits none.** The rule above
predicts exactly this and the third probe confirms it rather than being predicted: the host's
`PreprocessingUpdatableEstimator` returns the raw `[1, 2, 3, 4, 5, 6, 7, 8]` from `preprocessed(from:)`,
where the port's line 137 fits and would transform. The port is wrong in three places and right in one,
and the right one is the one I had written a red case to "fix" last week.
