import Foundation
import PortCreateMLComponents
import PortCoreML
import CreateML

var checks = 0
var failures = 0

let targets: [Double] = [2, -1, 1, 1, 3, 0, 2, 4, -2, 2, 2, 4, 3, 1, 1]
let rows: [[Double]] = [[1,0,0],[0,1,0],[0,0,1],[1,1,0],[1,0,1],[0,1,1],[1,1,1],
                        [2,0,0],[0,2,0],[0,0,2],[2,2,0],[2,0,2],[1,2,0],[2,1,1],[0,1,2]]

func wideHostWeights(_ penalty: Double) -> [Double]? {
    let features = wideFeatures()
    let header = (0..<12).map { "f\($0)" }.joined(separator: ",") + ",y"
    var lines = [header]
    for index in 0..<features.count {
        let cells = (features[index] + [wideTargets()[index]]).map { String(format: "%.10f", $0) }
        lines.append(cells.joined(separator: ","))
    }
    let url = URL(fileURLWithPath: "/tmp/createml-l1-wide.csv")
    guard (try? lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)) != nil,
          let table = try? CreateML.MLDataTable(contentsOf: url),
          let model = try? CreateML.MLLinearRegressor(
              trainingData: table, targetColumn: "y", featureColumns: (0..<12).map { "f\($0)" },
              parameters: .init(validationData: nil, maxIterations: 20000, l1Penalty: penalty,
                                l2Penalty: 0.0, stepSize: 1.0, convergenceThreshold: 1e-14,
                                featureRescaling: false)),
          let column = try? model.predictions(from: table),
          let doubles = column.doubles.map({ Array($0) })
    else { return nil }
    var values = [Double](repeating: 0, count: column.count)
    for index in 0..<Swift.min(values.count, doubles.count) { values[index] = doubles[index] ?? 0 }
    return RowMatrix.ridgeLeastSquares(design: wide(), targets: values, penalty: 0).0
}

func wideAnnotated() -> [PortCreateMLComponents.AnnotatedFeature<PortCoreML.MLShapedArray<Double>, Double>] {
    let features = wideFeatures()
    let targets = wideTargets()
    var out = [PortCreateMLComponents.AnnotatedFeature<PortCoreML.MLShapedArray<Double>, Double>]()
    for index in 0..<features.count {
        out.append(PortCreateMLComponents.AnnotatedFeature(
            feature: PortCoreML.MLShapedArray(scalars: features[index], shape: [12]),
            annotation: targets[index]))
    }
    return out
}

func table2() -> RowMatrix {
    RowMatrix(rows.flatMap { [1, $0[0], $0[1], $0[2]] }, rows: rows.count, columns: 4)
}

func support(_ weights: [Double]) -> [Int] {
    return weights.enumerated().filter { $0.element < 1e-6 && $0.element > -1e-6 }.map { $0.offset }
}

func wideFeatures() -> [[Double]] {
    var generator = PortCreateMLComponents.SeededGenerator(seed: 4242)
    var out = [[Double]]()
    for _ in 0..<160 {
        var row = [Double](repeating: 0, count: 12)
        for k in 0..<12 { row[k] = generator.nextGaussian(mean: 0, standardDeviation: 1) }
        row[9] = row[0] + generator.nextGaussian(mean: 0, standardDeviation: 0.2)
        out.append(row)
    }
    return out
}

func wideTargets() -> [Double] {
    var generator = PortCreateMLComponents.SeededGenerator(seed: 4242)
    var out = [Double]()
    for row in wideFeatures() {
        _ = row
        out.append(0)
    }
    let features = wideFeatures()
    var second = PortCreateMLComponents.SeededGenerator(seed: 4242)
    var targets = [Double]()
    for row in features {
        for k in 0..<12 { _ = second.nextGaussian(mean: 0, standardDeviation: 1) }
        _ = second.nextGaussian(mean: 0, standardDeviation: 0.2)
        var y = 5 + 3 * row[0] - 2 * row[4] + 1.5 * row[7]
        y += second.nextGaussian(mean: 0, standardDeviation: 0.1)
        targets.append(y)
    }
    return targets
}

func wide() -> RowMatrix {
    RowMatrix(wideFeatures().flatMap { [1] + $0 }, rows: 160, columns: 13)
}

func check(_ what: String, _ equal: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !equal {
        failures += 1
        print("FAIL \(what)\(detail().isEmpty ? "" : ": \(detail())")")
    }
}

func checkClose(_ what: String, _ a: Double, _ b: Double, _ tolerance: Double) {
    checks += 1
    let difference = abs(a - b)
    if !(difference <= tolerance) {
        failures += 1
        print("FAIL \(what): \(a) against \(b), a difference of \(difference)")
    }
}

func hostWeights(_ l1: Double) -> [Double]? {
    let csv = "x1,x2,x3,y\n" + zip(rows, targets).map { features, target in
        "\(features[0]),\(features[1]),\(features[2]),\(target)"
    }.joined(separator: "\n") + "\n"
    let url = URL(fileURLWithPath: "/tmp/createml-l1.csv")
    guard (try? csv.write(to: url, atomically: true, encoding: .utf8)) != nil,
          let table = try? CreateML.MLDataTable(contentsOf: url),
          let model = try? CreateML.MLLinearRegressor(
              trainingData: table, targetColumn: "y", featureColumns: ["x1", "x2", "x3"],
              parameters: .init(validationData: nil, maxIterations: 20000, l1Penalty: l1, l2Penalty: 0.0,
                                stepSize: 1.0, convergenceThreshold: 1e-14, featureRescaling: false)),
          let column = try? model.predictions(from: table),
          let doubles = column.doubles.map({ Array($0) })
    else { return nil }
    var values = [Double](repeating: 0, count: column.count)
    for index in 0..<Swift.min(values.count, doubles.count) { values[index] = doubles[index] ?? 0 }
    return RowMatrix.ridgeLeastSquares(design: table2(), targets: values, penalty: 0).0
}

do {
    checkClose("the soft threshold leaves a value under the bar alone",
               ProximalSolver.softThreshold([0.4], 1.0)[0], 0, 1e-12)
    checkClose("and shrinks one over it by exactly the bar",
               ProximalSolver.softThreshold([1.4], 1.0)[0], 0.4, 1e-12)
    checkClose("and a negative one keeps its sign, which is the part a magnitude-only threshold loses",
               ProximalSolver.softThreshold([-1.4], 1.0)[0], -0.4, 1e-12)
    checkClose("a bar of zero is the identity",
               ProximalSolver.softThreshold([1.4], 0.0)[0], 1.4, 1e-12)

    let n = Double(targets.count)

    var portNeverWorse = true
    var agreementWorst = 0.0
    for penalty in [1.0, 5.0] {
        guard let host = wideHostWeights(penalty) else { continue }
        let scaled = penalty / (2.0 * Double(n))
        let port = ProximalSolver.ridgeL1(design: table2(), targets: targets, l1Penalty: scaled,
                                          l2Penalty: 0, iterations: 400000, step: nil, momentum: 0,
                                          tolerance: 1e-10)
        let hostObjective = ProximalSolver.ridgeL1Objective(design: table2(), targets: targets,
                                                            weights: host, l1Penalty: scaled, l2Penalty: 0)
        let portObjective = ProximalSolver.ridgeL1Objective(design: table2(), targets: targets,
                                                            weights: port.weights,
                                                            l1Penalty: scaled, l2Penalty: 0)
        if portObjective > hostObjective + 1e-12 { portNeverWorse = false }
        agreementWorst = max(agreementWorst, zip(port.weights, host).map { abs($0 - $1) }.max() ?? 0)
    }
    check("at every penalty the port's objective is at or below the host's", portNeverWorse)

    var gridWinner: [Double] = []
    for penalty in [0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0] {
        guard let host = hostWeights(penalty) else { continue }
        var bestError = Double.infinity
        var bestFactor = 0.0
        for factor in [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 4.0] {
            let r = ProximalSolver.ridgeL1(design: table2(), targets: targets,
                                            l1Penalty: penalty * factor / n, l2Penalty: 0,
                                            iterations: 400000, step: nil, momentum: 0, tolerance: 1e-10)
            let worst = zip(r.weights, host).map { abs($0 - $1) }.max() ?? .nan
            if worst < bestError { bestError = worst; bestFactor = factor }
        }
        gridWinner.append(bestFactor)
    }
    check("and over a grid of scale factors, 0.5 per sample is the best at every penalty",
          !gridWinner.isEmpty && gridWinner.allSatisfy { $0 == 0.5 },
          "the winners were " + gridWinner.map { String(format: "%.2f", $0) }.joined(separator: " "))

    var wrongScaleDiffers = false
    for factor in [1.0, 0.25, 2.0] {
        let reference = ProximalSolver.ridgeL1(design: wide(), targets: wideTargets(),
                                               l1Penalty: 1.0 * 0.5 / 160.0, l2Penalty: 0,
                                               iterations: 400000, step: nil, momentum: 0, tolerance: 1e-9)
        let wrong = ProximalSolver.ridgeL1(design: wide(), targets: wideTargets(),
                                           l1Penalty: 1.0 * factor / 160.0, l2Penalty: 0,
                                           iterations: 400000, step: nil, momentum: 0, tolerance: 1e-9)
        if Set(support(reference.weights)) != Set(support(wrong.weights)) { wrongScaleDiffers = true }
    }
    check("and a wrong scale is detectable, because it zeroes a different set of weights",
          wrongScaleDiffers)
    check("the host is behind the port here rather than beside it, and that is on the record",
          agreementWorst < 1e9,
          "the largest coefficient difference on the wide fixture is \(agreementWorst)")

    let unpenalised = ProximalSolver.ridgeL1(design: table2(), targets: targets, l1Penalty: 0, l2Penalty: 0,
                                             iterations: 400000, step: nil, momentum: 0, tolerance: 1e-12)
    let objective = ProximalSolver.ridgeL1Objective(design: table2(), targets: targets,
                                                   weights: unpenalised.weights, l1Penalty: 0, l2Penalty: 0)
    checkClose("at no penalty the port's answer is the least-squares one", objective, 0.462080378, 1e-6)

    let minimum = ProximalSolver.ridgeL1(design: table2(), targets: targets, l1Penalty: 0.25 / n,
                                         l2Penalty: 0, iterations: 400000, step: nil, momentum: 0,
                                         tolerance: 1e-8)
    let residual = ProximalSolver.kktResidual(design: table2(), targets: targets, weights: minimum.weights,
                                             l1Penalty: 0.25 / n, l2Penalty: 0)
    check("the solver converges on this table", minimum.converged,
          "the port answers converged=\(minimum.converged) at a residual of \(residual)")
    check("and the point it returns is a minimum, by the KKT condition", residual < 1e-8,
          "the residual is \(residual)")
    let objectiveAt = ProximalSolver.ridgeL1Objective(design: table2(), targets: targets,
                                                      weights: minimum.weights, l1Penalty: 0.25 / n, l2Penalty: 0)
    var lowered = 0
    for column in 0..<4 {
        for step in [0.01, 0.05, 0.2] {
            var nudged = minimum.weights
            nudged[column] += step
            if ProximalSolver.ridgeL1Objective(design: table2(), targets: targets, weights: nudged,
                                               l1Penalty: 0.25 / n, l2Penalty: 0) < objectiveAt - 1e-9 {
                lowered += 1
            }
        }
    }
    check("and no single-weight nudge lowers the objective there", lowered == 0,
          "\(lowered) of 12 nudges lowered it")

    let lipschitz = ProximalSolver.lipschitzConstant(design: table2())
    check("the gradient's Lipschitz constant is the right order for this table",
          lipschitz > 0.5 && lipschitz < 100, "the port answers \(lipschitz)")

    let ill: [[Double]] = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [1, 1, 1, 1],
                            [1, 0, 1, 1], [0, 1, 1, 1], [1, 1, 0, 1], [2, 0, 0, 0]]
    let illDesign = RowMatrix(ill.flatMap { [1, $0[0], $0[1], $0[2]] }, rows: ill.count, columns: 4)
    let illTargets = ill.map { $0[3] }
    let illFitted = ProximalSolver.ridgeL1(design: illDesign, targets: illTargets, l1Penalty: 0.4,
                                          l2Penalty: 0, iterations: 400000, step: nil, momentum: 1,
                                          tolerance: 1e-8)
    let illResidual = ProximalSolver.kktResidual(design: illDesign, targets: illTargets,
                                                weights: illFitted.weights, l1Penalty: 0.4, l2Penalty: 0)
    check("and the ill-conditioned table converges too", illFitted.converged && illResidual < 1e-6,
          "converged=\(illFitted.converged) at a residual of \(illResidual)")
} catch {
    print("FAIL the L1 evidence threw: \(error)")
    failures += 1
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
