// model.swift — the port's `.mlmodel` writer, read back by a decoder of the same schema.
//
// **What this reaches and what it does not.** The writer emits Core ML's protobuf over the schema
// vendored in `packages/c/createml/proto/`, and the check below is that `readback.lua` parses the file
// and every field in it round-trips. That proves the *schema and the encoding*.
//
// The reader is `readback.lua`, written in Lua so that the suite needs no python. It is not an
// independent implementation: its oracle is the committed output of coremltools 9.0 on the same bytes,
// which the expectations below hold. The arithmetic is not checked by it at all.
//
// It does **not** prove the arithmetic. A load and a predict is the only check that does, and on this
// machine's CoreML Swift surface it is not reachable: `MLModel.prediction(fromFeatures:options:)` is
// `unavailable in macOS`, `MLModel.prediction(from:)` takes `[String: MLTensor]` and is `async`, and
// `MLTensor(shape:scalars:)` trips a compiler crash ("failed to produce diagnostic"). So the prediction
// comparison is **not** in this suite and no claim is made about it; `facts/CreateML/Export.md` says
// so, and the writer's own comment says which estimators it covers and which it refuses.

import Foundation
import PortCoreML
import PortCreateMLComponents

var checks = 0
var failures = 0

func checkEqual<T: Equatable>(_ what: String, _ a: T, _ b: T) {
    check(what, a == b, "the port answered \(a)")
}

func check(_ what: String, _ equal: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !equal {
        failures += 1
        print("FAIL \(what)\(detail().isEmpty ? "" : ": \(detail())")")
    }
}

/// The port's own model: `y = 3 + 2*x1 - 1.5*x2`, as the schema's protobuf.
let coefficients: [Float] = [2.0, -1.5]
let intercept: Float = 3.0
let writer = ModelWriter.model(featureName: "x", outputName: "prediction",
                              weights: coefficients, bias: intercept,
                              author: "charon CreateML", version: "1.0",
                              description: "the port's linear regressor")
let path = NSTemporaryDirectory() + "/createml-model-\(getpid()).mlmodel"
do {
    try Data(writer.bytes).write(to: URL(fileURLWithPath: path))
} catch {
    print("FAIL the writer could not write its model: \(error)")
    failures += 1
    exit(1)
}

// The round trip through this package's own reader first: a writer whose reader cannot read it is
// a writer that emits the wrong bytes, whatever any other implementation thinks.
do {
    let fields = try ProtoReader.fields(writer.bytes)
    var seen = [Int: Int]()
    for (number, _) in fields { seen[number, default: 0] += 1 }
    check("the model's own reader sees the top-level fields", seen.isEmpty == false,
          "the port's reader found \(seen.count) distinct field numbers")
    var specVersion: Int?
    var description: [UInt8]?
    var network: [UInt8]?
    for (number, field) in fields {
        switch number {
        case 1: specVersion = field.intValue
        case 2: description = field.bytesValue
        case 303: network = field.bytesValue
        default: break
        }
    }
    checkEqual("specificationVersion is the one the SDK declares", specVersion, ModelWriter.specificationVersion)
    check("the description is there", description != nil)
    check("the oneof is neuralNetworkRegressor, field 303", network != nil)

    // And inside the network: one layer, whose oneof is innerProduct, field 140.
    var layers = 0
    var innerProducts = 0
    var inputChannels: Int?
    var weightValues: [Float] = []
    var biasValues: [Float] = []
    var hasBias: Bool?
    for (number, field) in try ProtoReader.fields(network ?? []) {
        guard number == 1, let layerBytes = field.bytesValue else { continue }
        layers += 1
        for (layerNumber, layerField) in try ProtoReader.fields(layerBytes) {
            if layerNumber == 140, let inner = layerField.bytesValue {
                innerProducts += 1
                for (innerNumber, innerField) in try ProtoReader.fields(inner) {
                    switch innerNumber {
                    case 1: inputChannels = innerField.intValue
                    case 10: hasBias = innerField.boolValue
                    case 20, 21:
                        let name = innerNumber == 20 ? "weights" : "bias"
                        for (_, blob) in try ProtoReader.fields(innerField.bytesValue ?? []) where blob.floatValues != nil {
                            if name == "weights" { weightValues = blob.floatValues ?? [] }
                            if name == "bias" { biasValues = blob.floatValues ?? [] }
                        }
                    default: break
                    }
                }
            }
        }
    }
    checkEqual("one layer", layers, 1)
    checkEqual("whose oneof is innerProduct", innerProducts, 1)
    checkEqual("with the feature count as its input channels", inputChannels, coefficients.count)
    checkEqual("and the weights in order", weightValues, coefficients)
    checkEqual("and the intercept", biasValues, [intercept])
    checkEqual("and hasBias set", hasBias, true)
} catch {
    print("FAIL the writer's own reader could not read the model: \(error)")
    failures += 1
}

// The independent read is readback.lua: a protobuf decoder over Core ML's schema, run by xmake, that
// prints the fields this suite checks. It replaces the coremltools 9.0 scripts the suite ran through
// /usr/bin/python3. The expectations below are the committed output of coremltools for this model, and
// the Lua reader must print the same strings for the same file. Its path is beside this source.
let readbackScript = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("readback.lua").path

/// The fields readback.lua prints for a model file, split on the bar with empty fields kept; nil when
/// the reader did not run to the end.
func readBack(_ file: String) -> [String]? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["xmake", "l", readbackScript, file]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let text = String(data: data, encoding: .utf8) ?? ""
    guard let line = text.split(separator: "\n").last else { return nil }
    return line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
}

let readBackFields = readBack(path)
check("the Lua reader read the port's model", readBackFields?.count == 11,
      "it answered " + (readBackFields?.joined(separator: "|") ?? "nothing"))
if let fields = readBackFields, fields.count == 11 {
    checkEqual("with the specification version the SDK declares",
               fields[0], String(ModelWriter.specificationVersion))
    checkEqual("as a neuralNetworkRegressor", fields[1], "neuralNetworkRegressor")
    checkEqual("one input, named", fields[2], "x")
    checkEqual("one output, named", fields[3], "prediction")
    checkEqual("of the shape the weights need", fields[4], "1,2")
    checkEqual("and Core ML's single-precision array type", fields[5], "65568")
    checkEqual("with the feature count as input channels", fields[6], "2")
    checkEqual("and one output channel", fields[7], "1")
    checkEqual("and a bias", fields[8], "True")
    checkEqual("and the weights in order", fields[9], "2.0,-1.5")
    checkEqual("and the intercept", fields[10], "3.0")
}
// The public `write(to:)` a caller actually calls, on a model that was fitted, read back by the same
// independent reader. This is the check that the writer is reachable from the model rather than only
// from the suite, and that the intercept is moved out of the front of the coefficient array into the
// layer's bias field instead of being written as if it were a weight.
let fitted = LinearRegressorModel<Double>(coefficients: [7.0, 2.0, -1.5])
let publicPath = NSTemporaryDirectory() + "/createml-public-\(getpid()).mlmodel"
try? FileManager.default.removeItem(atPath: publicPath)
var wrote = false
do {
    try fitted.write(to: URL(fileURLWithPath: publicPath))
    wrote = FileManager.default.fileExists(atPath: publicPath)
} catch {
    print("public write(to:) threw: \(error)")
}
check("the fitted model's own write(to:) produces a file", wrote)

// The same reader on the fitted model's file. Its weights and bias are exact at six places, so the one
// line serves both reads.
let publicFields = readBack(publicPath)
if let fields = publicFields, fields.count == 11 {
    checkEqual("the intercept is the layer's bias, not a weight",
               fields[10].split(separator: ",").map(String.init), ["7.0"])
    checkEqual("the weights are the coefficients, in order, without the intercept",
               fields[9].split(separator: ",").map(String.init), ["2.0", "-1.5"])
    checkEqual("inputChannels is the feature count", fields[6], "2")
    checkEqual("outputChannels is one, a scalar prediction", fields[7], "1")
} else {
    check("the Lua reader read the file write(to:) produced", false,
          "it answered " + (publicFields?.joined(separator: "|") ?? "nothing"))
}
try? FileManager.default.removeItem(atPath: publicPath)

try? FileManager.default.removeItem(atPath: path)

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
