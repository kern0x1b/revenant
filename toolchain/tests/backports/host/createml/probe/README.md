# The Objective-C prediction probe

`probe.m` is the **synchronous Objective-C** route to loading and predicting a model the port wrote:
`+[MLModel compileModelAtURL:error:]`, `+[MLModel modelWithContentsOfURL:error:]`,
`MLDictionaryFeatureProvider` with an `MLMultiArray` input, and `-[MLModel predictionFromFeatures:error:]`.
The Swift overlay's `unavailable in macOS` on `prediction(fromFeatures:)` does not gate the Objective-C
method, and using the Objective-C one is what got the probe running at all.

**It has already earned its place.** The first version of the writer put the input and output at the
model level, and Core ML's own validator rejected it:

```
validator error: Specification is missing regressor predictedFeatureName
```

which is the only thing that has ever found that, and which coremltools 9.0 — a protobuf parser, not a
validator — read the same file without complaint. The writer now carries a `FunctionDescription`, and
the compiler gets past that check.

**Where it stops:** the compiler then throws a C++ `std::out_of_range` out of its own
`unordered_map::at` instead of returning an `NSError`, so the function form is closer and not yet
right. That is the next step and it is not a claim that the arithmetic is right.

Three API details stopped this probe first, and all three are in its comments:

- `MLMultiArray`'s subscripts take a **flat** `NSInteger` index, not an array of them.
- `-[MLMultiArray initWithShape:dataType:error:]` and
  `-[MLDictionaryFeatureProvider initWithDictionary:error:]` both have an `error:` out-parameter.
- `-[MLModel predictionFromFeatures:error:]` is the synchronous prediction; the Swift
  `prediction(fromFeatures:options:)` is `unavailable in macOS` and `prediction(from:)` is `async` over
  `[String: MLTensor]`, where `MLTensor(shape:scalars:)` trips a compiler crash.
