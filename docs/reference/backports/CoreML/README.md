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

## Checked

`frameworks/Backports/tests/coreml_swift_test.lua` builds the module for armv7 iOS 6.0 and typechecks
`frameworks/Backports/tests/CoreML/load.swift`, the lines of Telegram's `U2netp.swift` that load and compile, and the lines
of `AgeNet.swift` that make a shaped array of a model output and predict synchronously and asynchronously.

Not measured on a device: a load of a real model.
