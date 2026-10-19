// linearregressor/main.swift - the port's MLLinearRegressor against the host's own, in one process.
//
// The same CSV goes into both frameworks' tables, the same parameters go into both regressors, and the
// metrics of both are compared: the training metrics, the validation metrics for an explicit validation
// table, and the metrics of an evaluation on a held-out table.
//
// What is compared: metrics that the data and the parameters fix. Each metric is a function of the
// predictions, so agreeing metrics on two tables is agreeing predictions on them.
//
// What is not compared: the automatic split. Each framework draws its own rows for it, so its metrics
// differ by construction and the claim would be about the draw.
//
// The unpenalised fit is compared, with feature rescaling on and off. The penalised fits are not answered
// by the port: each one is checked to be refused by name, and the host's answer to the same penalty is
// measured beside it, so the refusal is a difference the file shows and not a difference it hides.
// facts/CreateML/LinearModels.md, "The penalties", has the measurements behind that.
//
// The features sit on very different scales (about 1000, 1 and 100) so that feature rescaling changes
// the fit, and a comparison with rescaling off is a comparison that can catch a wrong rescaling.
//
// Also checked, against a value that is known rather than measured: a noiseless line is recovered as
// its own coefficients, and the export refuses by name, because the writer is not in the port yet.
import Foundation
import CreateML
import PortCreateML

var failures = 0

func check(_ passed: Bool, _ name: String, _ detail: String) {
    print((passed ? "ok    " : "FAIL  ") + name + ": " + detail)
    if !passed { failures += 1 }
}

// A generator that is the same on every run and every machine, so the tables are the same bytes.
struct Lcg {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}

// y = 3 + 0.002 x1 - 1.5 x2 + 0.5 x3 + noise, with noise of at most 0.1 either way.
func csv(rows: Int, seed: UInt64, noise: Double) -> String {
    var generator = Lcg(state: seed)
    var lines = ["x1,x2,x3,y"]
    for _ in 0..<rows {
        let x1 = generator.next() * 1000
        let x2 = generator.next()
        let x3 = generator.next() * 100 - 50
        let error = (generator.next() - 0.5) * 2 * noise
        let y = 3 + 0.002 * x1 - 1.5 * x2 + 0.5 * x3 + error
        lines.append("\(x1),\(x2),\(x3),\(y)")
    }
    return lines.joined(separator: "\n") + "\n"
}

// The files sit beside the binary, which is in the run's own folder and is removed with it.
let folder = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
func write(_ text: String, named name: String) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try text.write(to: url, atomically: true, encoding: .utf8)
    return url
}

let trainingURL = try write(csv(rows: 400, seed: 7, noise: 0.1), named: "linear-training.csv")
let heldURL = try write(csv(rows: 120, seed: 11, noise: 0.1), named: "linear-held.csv")
let noiselessURL = try write(csv(rows: 60, seed: 3, noise: 0), named: "linear-noiseless.csv")

let hostTraining = try CreateML.MLDataTable(contentsOf: trainingURL)
let portTraining = try PortCreateML.MLDataTable(contentsOf: trainingURL)
let hostHeld = try CreateML.MLDataTable(contentsOf: heldURL)
let portHeld = try PortCreateML.MLDataTable(contentsOf: heldURL)
let features = ["x1", "x2", "x3"]

// The metrics as the two frameworks name them, as a pair of numbers each.
func pair(_ metrics: CreateML.MLRegressorMetrics) -> (Double, Double) {
    (metrics.maximumError, metrics.rootMeanSquaredError)
}
func pair(_ metrics: PortCreateML.MLRegressorMetrics) -> (Double, Double) {
    (metrics.maximumError, metrics.rootMeanSquaredError)
}

func compare(_ name: String, host: (Double, Double), port: (Double, Double), tolerance: Double) {
    let difference = max(abs(host.0 - port.0), abs(host.1 - port.1))
    check(difference <= tolerance, name,
          "host max error \(host.0), rmse \(host.1); port max error \(port.0), rmse \(port.1); largest difference \(difference)")
}

// The unpenalised configurations, which the port answers and the host is compared with.
struct Configuration {
    var name: String
    var featureRescaling: Bool
}

let matched = [
    Configuration(name: "no penalty", featureRescaling: true),
    Configuration(name: "no penalty, rescaling off", featureRescaling: false),
]

for configuration in matched {
    let hostParameters = CreateML.MLLinearRegressor.ModelParameters(
        validation: .none, maxIterations: 10, l1Penalty: 0, l2Penalty: 0, stepSize: 1.0,
        convergenceThreshold: 0.01, featureRescaling: configuration.featureRescaling)
    let portParameters = PortCreateML.MLLinearRegressor.ModelParameters(
        validation: .none, maxIterations: 10, l1Penalty: 0, l2Penalty: 0, stepSize: 1.0,
        convergenceThreshold: 0.01, featureRescaling: configuration.featureRescaling)
    do {
        let host = try CreateML.MLLinearRegressor(trainingData: hostTraining, targetColumn: "y",
                                                  featureColumns: features, parameters: hostParameters)
        let port = try PortCreateML.MLLinearRegressor(trainingData: portTraining, targetColumn: "y",
                                                      featureColumns: features, parameters: portParameters)
        compare("\(configuration.name): training metrics",
                host: pair(host.trainingMetrics), port: pair(port.trainingMetrics), tolerance: 1e-9)
        compare("\(configuration.name): evaluation on the held-out table",
                host: pair(host.evaluation(on: hostHeld)), port: pair(port.evaluation(on: portHeld)), tolerance: 1e-9)
        let portPredictions = try port.predictions(from: portHeld)
        check(portPredictions.count == portHeld.count, "\(configuration.name): one prediction per row",
              "\(portPredictions.count) predictions for \(portHeld.count) rows")
    } catch {
        check(false, "\(configuration.name): fit", "threw \(error)")
    }
}

// The penalised configurations: the port refuses each one by name, and the host's answer is printed.
// The default parameters carry the framework's own L2 penalty of 0.01, so the default constructor is one
// of them.
let penalised: [(String, Double, Double)] = [
    ("default parameters (L2 0.01)", 0, 0.01),
    ("L2 1", 0, 1),
    ("L1 0.1", 0.1, 0),
]
for (name, l1, l2) in penalised {
    do {
        _ = try PortCreateML.MLLinearRegressor(
            trainingData: portTraining, targetColumn: "y", featureColumns: features,
            parameters: PortCreateML.MLLinearRegressor.ModelParameters(
                validation: .none, l1Penalty: l1, l2Penalty: l2))
        check(false, "\(name): refused", "the port fitted a penalised model")
    } catch let error as PortCreateML.MLCreateError {
        if case .penaltyNotMatched = error {
            check(true, "\(name): refused", "the port names the penalty it does not answer")
        } else {
            check(false, "\(name): refused", "refused with another error: \(error)")
        }
    } catch {
        check(false, "\(name): refused", "refused with a non-CreateML error: \(error)")
    }
    do {
        let host = try CreateML.MLLinearRegressor(
            trainingData: hostTraining, targetColumn: "y", featureColumns: features,
            parameters: CreateML.MLLinearRegressor.ModelParameters(validation: .none, l1Penalty: l1, l2Penalty: l2))
        print("      host, for the record: training rmse \(host.trainingMetrics.rootMeanSquaredError)")
    } catch {
        check(false, "\(name): host fit", "the host threw \(error)")
    }
}

// An explicit validation table: the host's validation metrics are compared with the port's.
do {
    let hostWithValidation = try CreateML.MLLinearRegressor(
        trainingData: hostTraining, targetColumn: "y", featureColumns: features,
        parameters: CreateML.MLLinearRegressor.ModelParameters(validation: .table(hostHeld), l2Penalty: 0))
    let portWithValidation = try PortCreateML.MLLinearRegressor(
        trainingData: portTraining, targetColumn: "y", featureColumns: features,
        parameters: PortCreateML.MLLinearRegressor.ModelParameters(validation: .table(portHeld), l2Penalty: 0))
    compare("validation table: validation metrics",
            host: pair(hostWithValidation.validationMetrics), port: pair(portWithValidation.validationMetrics),
            tolerance: 1e-9)
    // Without a validation set the host's metrics are not comparable; the port says the same through its error.
    let hostWithout = try CreateML.MLLinearRegressor(
        trainingData: hostTraining, targetColumn: "y", featureColumns: features,
        parameters: CreateML.MLLinearRegressor.ModelParameters(validation: .none, l2Penalty: 0))
    let portWithout = try PortCreateML.MLLinearRegressor(
        trainingData: portTraining, targetColumn: "y", featureColumns: features,
        parameters: PortCreateML.MLLinearRegressor.ModelParameters(validation: .none, l2Penalty: 0))
    check(hostWithout.validationMetrics.isValid == portWithout.validationMetrics.isValid,
          "no validation: metrics validity",
          "host valid \(hostWithout.validationMetrics.isValid), port valid \(portWithout.validationMetrics.isValid)")
} catch {
    check(false, "validation table: fit", "threw \(error)")
}

// Known answers: a noiseless line is recovered as its own coefficients, to the closed form's precision.
do {
    let noiseless = try PortCreateML.MLDataTable(contentsOf: noiselessURL)
    let port = try PortCreateML.MLLinearRegressor(
        trainingData: noiseless, targetColumn: "y", featureColumns: features,
        parameters: PortCreateML.MLLinearRegressor.ModelParameters(validation: .none, l2Penalty: 0))
    let expected = [3.0, 0.002, -1.5, 0.5]
    let found = port.model.coefficients
    let largest = zip(found, expected).map { abs($0 - $1) }.max() ?? .infinity
    check(found.count == expected.count && largest < 1e-6, "noiseless line: coefficients",
          "found \(found), expected \(expected), largest difference \(largest)")
} catch {
    check(false, "noiseless line: fit", "threw \(error)")
}

// The export is refused, and it says so by its code. A file would be written with the wrong shape otherwise.
do {
    let port = try PortCreateML.MLLinearRegressor(
        trainingData: portTraining, targetColumn: "y", featureColumns: features,
        parameters: PortCreateML.MLLinearRegressor.ModelParameters(validation: .none, l2Penalty: 0))
    do {
        try port.write(toFile: folder.appendingPathComponent("linear.mlmodel").path)
        check(false, "write refuses", "write returned without an error")
    } catch let error as PortCreateML.MLCreateError {
        check(error == PortCreateML.MLCreateErrorCode.cannotWriteModel.error, "write refuses", "\(error)")
    }
} catch {
    check(false, "write refuses: fit", "threw \(error)")
}

print(failures == 0 ? "linearregressor: OK (0 failures)" : "linearregressor: \(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
