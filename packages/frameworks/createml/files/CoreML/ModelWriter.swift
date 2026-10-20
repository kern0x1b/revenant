import Foundation

public enum ModelWriter {
    public static let specificationVersion = 5

    public static func numericFeature(name: String, shape: [Int]) -> ProtoWriter {
        var array = ProtoWriter()
        array.packedInt64(1, shape)
        array.varint(2, 65568)
        var featureType = ProtoWriter()
        featureType.message(5, array)
        var feature = ProtoWriter()
        feature.string(1, name)
        feature.message(3, featureType)
        return feature
    }

    public static func linearLayer(name: String, input: String, output: String,
                                   weights: [Float], bias: Float) -> ProtoWriter {
        var weightParams = ProtoWriter()
        weightParams.packedFloat(1, weights)
        var biasParams = ProtoWriter()
        biasParams.packedFloat(1, [bias])

        var inner = ProtoWriter()
        inner.varint(1, UInt64(weights.count))
        inner.varint(2, 1)
        inner.bool(10, true)
        inner.message(20, weightParams)
        inner.message(21, biasParams)

        var layer = ProtoWriter()
        layer.string(1, name)
        layer.string(2, input)
        layer.string(3, output)
        layer.message(140, inner)
        return layer
    }

    public static func neuralNetworkRegressor(featureName: String, outputName: String,
                                             weights: [Float], bias: Float) -> ProtoWriter {
        var network = ProtoWriter()
        network.message(1, linearLayer(name: "linear", input: featureName, output: outputName,
                                       weights: weights, bias: bias))
        return network
    }

    public static func model(featureName: String, outputName: String,
                             weights: [Float], bias: Float,
                             author: String, version: String, description: String) -> ProtoWriter {
        var metadata = ProtoWriter()
        metadata.string(1, description)
        metadata.string(2, version)
        metadata.string(3, author)

        var function = ProtoWriter()
        function.string(1, "main")
        function.message(2, numericFeature(name: featureName, shape: [1, weights.count]))
        function.message(3, numericFeature(name: outputName, shape: [1, 1]))
        function.string(4, outputName)

        var modelDescription = ProtoWriter()
        modelDescription.message(20, function)
        modelDescription.message(1, numericFeature(name: featureName, shape: [1, weights.count]))
        modelDescription.message(10, numericFeature(name: outputName, shape: [1, 1]))
        modelDescription.message(100, metadata)

        var model = ProtoWriter()
        model.varint(1, specificationVersion)
        model.message(2, modelDescription)
        model.message(303, neuralNetworkRegressor(featureName: featureName, outputName: outputName,
                                                 weights: weights, bias: bias))
        return model
    }
}
