// ModelWriter.swift — a Core ML model of these estimators, as the schema's own protobuf.
//
// Apple's `.mlmodel` is a protobuf over the schema vendored in `packages/c/createml/proto/`, and
// **every field number below is read out of those files** rather than recalled:
//
//     Model                   specificationVersion = 1, description = 2, neuralNetworkRegressor = 303
//     ModelDescription        functions = 20, input = 1, output = 10, metadata = 100
//     FunctionDescription     name = 1, input = 2, output = 3, predictedFeatureName = 4
//     FeatureDescription      name = 1, shortDescription = 2, type = 3
//     FeatureTypes            oneof { int64Type = 1, doubleType = 2, stringType = 3, multiArrayType = 5 }
//     ArrayFeatureType        shape = 1, dataType = 2   (FLOAT32 = 0x10000|32 = 65568)
//     NeuralNetworkRegressor  layers = 1, preprocessing = 2
//     NeuralNetworkLayer      name = 1, input = 2, output = 3, oneof { innerProduct = 140 }
//     InnerProductLayerParams inputChannels = 1, outputChannels = 2, hasBias = 10, weights = 20, bias = 21
//     WeightParams            floatValue = 1
//
// **The model shape is a one-input, one-output neural network with a single inner-product layer**, and
// that is not a wrapper: for a row of features `x` the layer computes `bias + weights · x`, which *is*
// a linear model, and Core ML executes it as one. So an exported linear regressor is a model Core ML
// will load and predict with, and the differential proves it by loading it and predicting — which is
// what "exported" has to mean.
//
// `NeuralNetworkRegressor` carries the layers **directly** (field 1), not a nested `NeuralNetwork`, and
// that is the detail a hand-written writer gets wrong first: the older spelling nested a network and
// the current one does not.
//
// The estimators that are not linear are **not** written here. A tree ensemble is a different message
// with a different layer set, and a model file that says `NeuralNetworkRegressor` and carries a forest
// would be a model Core ML loads and answers with the wrong arithmetic. `write(to:)` on those throws
// `MLCreateErrorCode.cannotWriteModel` and says which kind is missing.

import Foundation

/// The writer for the messages above.
public enum ModelWriter {
    /// The Core ML specification version these are written at. **5** is the version the 16.4 SDK
    /// declares, and a model written above a reader's version is a model that reader refuses.
    public static let specificationVersion = 5

    /// A `FeatureDescription` for one input or output, a double array of the given shape.
    ///
    /// `FLOAT32` and not `DOUBLE`, because Core ML's own feature descriptions for a numeric input
    /// are single-precision and a double array in a model's own description is a type the compiler
    /// does not accept. The **values** are single precision too — a Core ML weight blob is
    /// `repeated float` — and the loss that costs is measured by the differential, which compares the
    /// host's predictions against the port's.
    public static func numericFeature(name: String, shape: [Int]) -> ProtoWriter {
        var array = ProtoWriter()
        array.packedInt64(1, shape)          // ArrayFeatureType.shape = 1
        array.varint(2, 65568)               // ArrayFeatureType.dataType = 2, FLOAT32
        var featureType = ProtoWriter()
        featureType.message(5, array)        // FeatureTypes.multiArrayType = 5
        var feature = ProtoWriter()
        feature.string(1, name)              // FeatureDescription.name = 1
        feature.message(3, featureType)      // FeatureDescription.type = 3
        return feature
    }

    /// The inner-product layer of a linear model: `y = bias + weights · x`.
    ///
    /// `weights` is `[C_out, C_in]` row-major, so for one output it is the weight vector itself, and
    /// `inputChannels` is the number of features. `hasBias` is 10 and is set even when the bias is
    /// zero, because a layer with `hasBias` false and a bias blob is a model the reader rejects.
    public static func linearLayer(name: String, input: String, output: String,
                                   weights: [Float], bias: Float) -> ProtoWriter {
        var weightParams = ProtoWriter()
        weightParams.packedFloat(1, weights)      // WeightParams.floatValue = 1
        var biasParams = ProtoWriter()
        biasParams.packedFloat(1, [bias])         // WeightParams.floatValue = 1

        var inner = ProtoWriter()
        inner.varint(1, UInt64(weights.count))    // inputChannels = 1
        inner.varint(2, 1)                         // outputChannels = 2
        inner.bool(10, true)                        // hasBias = 10
        inner.message(20, weightParams)             // weights = 20
        inner.message(21, biasParams)               // bias = 21

        var layer = ProtoWriter()
        layer.string(1, name)                       // name = 1
        layer.string(2, input)                      // input = 2
        layer.string(3, output)                     // output = 3
        layer.message(140, inner)                   // oneof layer { innerProduct = 140 }
        return layer
    }

    /// A whole `NeuralNetworkRegressor` of one linear layer.
    public static func neuralNetworkRegressor(featureName: String, outputName: String,
                                             weights: [Float], bias: Float) -> ProtoWriter {
        var network = ProtoWriter()
        network.message(1, linearLayer(name: "linear", input: featureName, output: outputName,
                                       weights: weights, bias: bias))  // layers = 1
        return network
    }

    /// A whole `Model` of one linear regressor.
    ///
    /// The input is a double array of shape `[1, n]` — a single row of `n` features — and the output
    /// a double array of shape `[1, 1]`. That is the shape a `MLMultiArray` of one row has, and it is
    /// what the differential hands the host.
    public static func model(featureName: String, outputName: String,
                             weights: [Float], bias: Float,
                             author: String, version: String, description: String) -> ProtoWriter {
        var metadata = ProtoWriter()
        metadata.string(1, description)            // Metadata.shortDescription = 1
        metadata.string(2, version)                // versionString = 2
        metadata.string(3, author)                  // author = 3

        // **The description is a FUNCTION, not the model-level input/output.** Core ML's own
        // validator rejected the model-level form with
        //
        //     validator error: Specification is missing regressor predictedFeatureName
        //
        // because `predictedFeatureName` — which `Model.proto:167` marks *"[Required for regressor
        // and classifier functions]"* — exists **only on `FunctionDescription`** (field 4), and
        // `ModelDescription`'s own `input`/`output` are documented as "use these fields below only
        // when `functions` above is empty". The first version wrote the model-level form; coremltools
        // read it happily, because a protobuf parser does not validate, and the **real compiler** is
        // what caught it. That is the whole argument for loading a written model rather than parsing it.
        var function = ProtoWriter()
        function.string(1, "main")                                                  // name = 1
        function.message(2, numericFeature(name: featureName, shape: [1, weights.count]))  // input = 2
        function.message(3, numericFeature(name: outputName, shape: [1, 1]))            // output = 3
        function.string(4, outputName)                                                 // predictedFeatureName = 4

        // The function is there because the **validator** wants `predictedFeatureName`, and the
        // model-level `input`/`output` are there because the **prediction path** reads them. Which of
        // the two is which is measured, not assumed: of sixteen compiled variants, every one *with*
        // a function passes the validator and then throws out of Core ML's own `unordered_map::at`,
        // and every one *without* one is rejected for the missing `predictedFeatureName`. So both are
        // required, and neither is sufficient — the file is a correct protobuf that Core ML's compiler
        // does not yet accept. `facts/CreateML/Export.md` has the table and the bisect.
        var modelDescription = ProtoWriter()
        modelDescription.message(20, function)                                         // functions = 20
        modelDescription.message(1, numericFeature(name: featureName, shape: [1, weights.count]))  // input = 1
        modelDescription.message(10, numericFeature(name: outputName, shape: [1, 1]))            // output = 10
        modelDescription.message(100, metadata)                                        // metadata = 100

        var model = ProtoWriter()
        model.varint(1, specificationVersion)                       // specificationVersion = 1
        model.message(2, modelDescription)                          // description = 2
        model.message(303, neuralNetworkRegressor(featureName: featureName, outputName: outputName,
                                                 weights: weights, bias: bias))
        return model
    }
}
