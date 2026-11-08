# CoreML model loading and compiling on iOS 6

The backport's CoreML is Objective-C classes plus a Swift module of the same name (`frameworks/Backports/src/CoreML`, the
`CoreML` target of the `Swift` component). It is built with `-import-underlying-module`, as a Swift module named like an SDK
framework must be, and its sources do not import it.

`MLModelLoad.swift` carries the Swift forms the SDK's CoreML interface gives `MLModel`:

- `MLModel.load(contentsOf:configuration:completionHandler:)` with a `Result`, and the `async throws` form;
- `MLModel.compileModel(at:completionHandler:)` with a `Result`, and the `async throws` form.

Each forwards to the refined Objective-C method the backport implements. A completion that carries neither a model nor an
error stops with a message, because no caller can act on it.

## Consumer

A target that imports CoreML builds the `CoreML` target of the `Swift` component and passes its module folder with `-I`.
`TabularData`, `CreateMLComponents` and `CreateML` are built the same way; the CreateML gap is closed (see
`docs/reference/backports/CreateML/README.md`).

## Checked

`frameworks/Backports/tests/coreml_swift_test.lua` builds the module for armv7 iOS 6.0 and typechecks
`frameworks/Backports/tests/CoreML/load.swift`, the lines of Telegram's `U2netp.swift` that load and compile.

Not measured on a device: a load of a real model.
