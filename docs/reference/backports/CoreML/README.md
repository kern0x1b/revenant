# CoreML model loading and compiling on iOS 6

The backport's CoreML is Objective-C classes plus a Swift module of the same name (`frameworks/Backports/src/CoreML`, the
`CoreML` target of the `Swift` component). It is built with `-import-underlying-module`, as a Swift module named like an SDK
framework must be, and its sources do not import it.

`MLModelLoad.swift` carries the Swift forms the SDK's CoreML interface gives `MLModel`:

- `MLModel.load(contentsOf:configuration:completionHandler:)` with a `Result`, and the `async throws` form;
- `MLModel.compileModel(at:completionHandler:)` with a `Result`, and the `async throws` form;
- `MLModel.prediction(from:options:)` as `async throws`, beside the synchronous `throws` form the header gives. A program
  that calls it with `await` compiled against the headers alone fails with "no 'async' operations occur within 'await'
  expression", because the SDK marks the completion-handler method `NS_SWIFT_DISABLE_ASYNC` and writes the `async` form in
  Swift.

Each forwards to the refined Objective-C method the backport implements. A completion that carries neither a model nor an
error stops with a message, because no caller can act on it.

`ShapedArray.swift` carries `MLShapedArray`, the scalars it holds (`Float`, `Double`, `Int32`) and its slice, and
`MLShapedArray(_ multiArray: MLMultiArray)`, the form that Telegram's `AgeNet.swift` uses on a model output: it reads the
multi array's shape and strides, takes a copy in the shaped array's row-major order (one copy when the multi array is
already contiguous, an element walk when its strides leave padding), and stops when the multi array's data type is not the
scalar's, as the SDK does. The SDK's `init(converting:)`, which converts between data types, and `MLMultiArray(_:)` of a
shaped array are not carried.

## Consumer

A target that imports CoreML builds the `CoreML` target of the `Swift` component and passes its module folder with `-I`.
`TabularData`, `CreateMLComponents` and `CreateML` are built the same way; the CreateML gap is closed (see
`docs/reference/backports/CreateML/README.md`).

The module is built with `-module-link-name CoreML`, as every static target of the component is, so an object that imports
it asks the linker for `-lCoreML`. The consumer's link puts the folder of `libCoreML.a` on `-L` and names no library for
it. Without the entry, `MLModel.load(contentsOf:configuration:completionHandler:)` was undefined at the link of an app
that calls it, although the archive defines it.

The classes behind the module (`MLModel`, `MLFeatureValue`, `MLModelConfiguration`, `MLPredictionOptions`) are in
`libCoreMLBackports.dylib`, which the link names with the other Backports libraries and before any `CoreML` framework, so
that `MLModel` binds to the dylib (bound to the framework, which iOS 6.0 lacks, the class is nil). The engine that runs a model is C
code of `src/CoreML` (`RevenantMLModel.c`, `RevenantMLPredict.c`, `RevenantMLLayers.c`). `revenant_ml_model_read` takes the
program from the `coremldata.bin` of a bundle, as a `CoreML.Specification.Model` message, and a bundle without that file or
with a message it cannot run fails with an error that reaches the completion handler as `.failure`.

Not checked: a bundle that Apple's `coremlc` compiled. Telegram's `u2netp.mlmodelc` is one: the app downloads it as a zip
from the channel `stickersbackgroundseparation` at run time, and the repository holds no `.mlmodelc` fixture. Whether
that bundle keeps its network in `coremldata.bin` is therefore not known here, and nothing in `src/CoreML` reads another
file of a bundle.

## Checked

`frameworks/Backports/tests/coreml_swift_test.lua` builds the module for armv7 iOS 6.0 and typechecks
`frameworks/Backports/tests/CoreML/load.swift`, the lines of Telegram's `U2netp.swift` that load and compile, and the lines
of `AgeNet.swift` that make a shaped array of a model output and predict synchronously and asynchronously.

Measured on an iPhone 4S with iOS 6.1.3 (see `docs/explanation/backports/lowered-implemented-names.md`): a model written by
`ModelWriter` is compiled, loaded and predicted through the Swift forms, and a load of a missing bundle ends in `.failure`.

Not measured on a device: a load of a model that Apple's `coremlc` compiled.
