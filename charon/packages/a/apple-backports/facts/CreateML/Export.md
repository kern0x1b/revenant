# The `.mlmodel` export, and exactly how far it is verified

## What is written

A **linear** model, as a Core ML `NeuralNetworkRegressor` of one `innerProduct` layer, and that is not a
wrapper: for a row of features `x` the layer computes `bias + weights · x`, which *is* a linear model,
and Core ML executes it. Every field number is read out of the vendored schema in `packages/c/createml/proto/`:

| message | fields used |
| --- | --- |
| `Model` | `specificationVersion = 1`, `description = 2`, `neuralNetworkRegressor = 303` |
| `ModelDescription` | `input = 1`, `output = 10`, `metadata = 100` |
| `FeatureDescription` | `name = 1`, `type = 3` |
| `FeatureTypes` | oneof `{ doubleType = 2, multiArrayType = 5 }` |
| `ArrayFeatureType` | `shape = 1`, `dataType = 2` (FLOAT32 = `0x10000\|32` = 65568) |
| `NeuralNetworkRegressor` | `layers = 1` — **the layers are direct**, not a nested `NeuralNetwork` |
| `NeuralNetworkLayer` | `name = 1`, `input = 2`, `output = 3`, oneof `{ innerProduct = 140 }` |
| `InnerProductLayerParams` | `inputChannels = 1`, `outputChannels = 2`, `hasBias = 10`, `weights = 20`, `bias = 21` |
| `WeightParams` | `floatValue = 1` |

Two details a hand-written writer gets wrong first, and both are said so in `ModelWriter.swift`:
`NeuralNetworkRegressor` carries its layers **directly** (the older spelling nested a `NeuralNetwork`),
and `hasBias` must be set even when the bias is zero, because a layer with `hasBias` false and a bias
blob is a model the reader rejects.

## How far it is verified, and what is not verified

**Reached, and independently:** `coremltools 9.0` — a protobuf implementation written by neither this
port nor Swift's Core ML — parses the file and every field round-trips. The suite checks all of it:
the specification version, the oneof, the input and output names, the input shape `[1, n]`, the
`FLOAT32` data type, `inputChannels`, `outputChannels`, `hasBias`, the weights in order, and the
intercept. It also round-trips through the port's own reader, so a writer whose reader cannot read it
is caught before any other implementation is asked.

**Not reached: a load and a predict.** That is the only check that says the *arithmetic* is right and
not only the schema, and on this machine's CoreML Swift surface it is not reachable:

- `MLModel.prediction(fromFeatures:options:)` — `unavailable in macOS`;
- `MLModel.prediction(from:)` — takes `[String: MLTensor]` and is `async`, so it needs a top-level
  `await`, which is allowed only in a file named `main.swift`;
- `MLTensor(shape:scalars:)` — trips a compiler crash, `failed to produce diagnostic for expression`.

**So the differential compares predictions, not a loaded model, and no claim is made about the
arithmetic.** **`write(to:)` on all six estimators still throws `MLCreateErrorCode.cannotWriteModel`:** the writer
exists and is proven, and wiring it into the estimators' `write(to:)` is not done. That is the crutch.

## What is not written, and why it is refused rather than approximated

The forests and the boosted forests are `TreeEnsembleRegressor` (field 302) with a different layer
set, and the three classifiers are `NeuralNetworkClassifier` (403) with a string output. A model file
that said `NeuralNetworkRegressor` and carried a forest would be a model Core ML loads and answers with
**the wrong arithmetic**, which is the failure the rules name. So those five refuse, and their
`write(to:)` says which kind is missing.

## The mutation, and it dies

Writing the intercept into the `weights` field and the weights into `bias` — the classic transposition
in a linear model, and the one field order the read-back is there to hold:

```
FAIL and the weights in order: the port answered [3.0]
FAIL and the intercept: the port answered 2.0,-1.5,3.0
```

The check is every field read back by **an implementation that is not this port's**, with the weights
and the intercept compared *in order* — so a wrong field number, a transposed weight vector, and a
scalar where a vector belongs are all caught, by coremltools rather than by the port's own reader.

The writer's own round trip runs first, so a writer whose reader cannot read it is caught before any
other implementation is asked.

### The package build, and why `MLMultiArrayDataType` is not there

The build fails in the `CoreML` module at `ShapedArray.swift`:

```
files/CoreML/ShapedArray.swift:47:36: error: cannot find type 'MLMultiArrayDataType' in scope
```

**The port's headers are working. The type is genuinely absent from the port's releases.** `MLMultiArrayDataType`
is declared in the iPhoneOS 16.4 SDK's `MLMultiArray.h:17` as

```objc
typedef NS_ENUM(NSInteger, MLMultiArrayDataType) {
    MLMultiArrayDataTypeDouble  = 0x10000 | 64,
    MLMultiArrayDataTypeFloat32 = 0x10000 | 32,
} API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0));
```

**iOS 11.0** — the annotation on the closing brace covers the whole enumeration. The port's Swift
targets are armv7, and the compiler itself fixes the window: `ios6.1` is refused with *"Swift requires
a minimum deployment target of iOS 7.0.0"* and every `ios11.0`-and-above with *"does not support
emitting binaries or IR for armv7"*. So the range the port can build armv7 into is iOS 7.0-10.x, and
inside it the type is unavailable:

| deployment | diagnostic |
| --- | --- |
| ios7.0 / 8.0 / 9.0 / 10.0 | `error: 'MLMultiArrayDataType' is only available in iOS 11.0 or newer` |
| ios11.0 and above | armv7 unsupported outright |

That is a **decision, not a defect**, and it is the coordinator's to make, because the two honest
answers are both a change of contract:

- **Relax the availability, which is what a backport of a header-only enum is.** The type is
  `NS_ENUM(NSInteger, ...)` with no runtime presence: the *values* are wire numbers, and the
  arithmetic is done by this port's own code. A port header that carried the port's releases instead
  of the SDK's would make it legal, and then `registry/CoreML/createml-shapedarray.json` — which already
  claims the type and its cases as this package's — becomes true. This is the better answer: it keeps
  the public surface Apple's.
- **Carry the wire value, and say so.** `Float32` is `0x10000 | 32` and `Double` is `0x10000 | 64`,
  numbers the registry already records as read out of Apple's own header, and the writer already
  emits them. A `multiArrayDataType` returning a number would build everywhere, at the cost of a
  public surface that is not Apple's.

**What is not an answer**, and is the one this package deliberately did not take: declaring the enum a
second time inside the overlay. The registry already claims the type as this package's, so a hand
written copy would be the second copy of a declaration that exists, and the port's rule is to fix the
original rather than to add a parallel one.

The writer itself does not need the type: it emits the numbers, and the two independent readers check
them. So this blocks the **package build** and nothing in the host suites, which is why 489 checks
pass on the host while the device build does not compile.

## The error the six refusals give, and why the rows are `absent`

The six rows for `write(to:)` — one per estimator, in `registry/CreateML.json` — are `absent`, and
this is the measurement that decides it. **Apple's own `write(to:metadata:)` writes a model** for
every one of these estimators on every release that has it, so a refusal here is a refusal where
Apple's would work. A row that refuses where Apple's also refuses is `implemented` and its effect
says so; these are the other case, so they are `absent`, and the reason and the error belong here.

The error is `MLCreateErrorCode.cannotWriteModel`, **case 6** of that code's enumeration, and the
text it carries is

    The model cannot be written from this build or platform

which is the port's own sentence, in `CreateML/TabularEstimators.swift`, and it is what a caller sees
from both spellings — `write(to:metadata:)` and `write(toFile:metadata:)`, six estimators, twelve
throws.

**Why the refusal, and what it is not.** The `.mlmodel` writer is not missing: it is in this
package's own CoreML module, it is a protobuf over the published coremltools schema, and the linear
model writes through it. What these six cannot use it for is the kind of model they are. A decision
tree, a forest and a booster are a `TreeEnsembleRegressor` (field 302) — a branch per tree, a branch
per iteration — and a tree or forest classifier is a `NeuralNetworkClassifier` (field 403), with a
string label output and a probabilities output. The writer writes a `NeuralNetworkRegressor`, whose
single inner-product layer is exactly the arithmetic a linear model is and exactly not the arithmetic
these six are. A file carrying one of those under `NeuralNetworkRegressor` would be a model Core ML
loads and answers with the **wrong numbers**, silently, which is the failure the whole corpus
contract treats as worse than an honest error.

**What would move a row to `implemented`.** A writer for field 302 or field 403 in this package's
CoreML module, and a model it produces that two readers accept — coremltools 9.0, and Core ML's own
compiler. The tree-ensemble case also has an open question recorded above: coremltools 9.0's
`TreeEnsembleRegressor` carries only `treeEnsemble` and `postEvaluationTransform`, with no
`predictedFeatureName` anywhere on it, so whatever answers the validator for the neural-network form
has to be found for this one too.
