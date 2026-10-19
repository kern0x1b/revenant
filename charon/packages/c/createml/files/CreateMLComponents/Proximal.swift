import Foundation

public enum ProximalSolver {
    public static func softThreshold(_ x: [Double], _ l: Double) -> [Double] {
        guard l > 0 else { return x }
        var out = [Double](repeating: 0, count: x.count)
        for index in 0..<x.count {
            let value = x[index]
            let magnitude = value < 0 ? -value : value
            out[index] = magnitude > l ? (value < 0 ? -(magnitude - l) : magnitude - l) : 0
        }
        return out
    }

    public static func lipschitzConstant(design: RowMatrix, iterations: Int = 20) -> Double {
        let n = design.rows
        guard n > 0, design.columns > 0 else { return 1 }
        var vector = [Double](repeating: 1, count: design.columns)
        var estimate = 0.0
        for _ in 0..<Swift.max(1, iterations) {
            let projected = design.transposedMultiplied(by: design.multiplied(by: vector))
            let next = projected.map { $0 / Double(n) }
            let norm = RowMatrix.dot(next, next)
            if norm <= 0 { return 1 }
            let scale = norm.squareRoot()
            for index in 0..<vector.count { vector[index] = next[index] / scale }
            estimate = scale
        }
        return estimate > 0 ? estimate : 1
    }

    public static func ridgeL1(design: RowMatrix,
                               targets: [Double],
                               l1Penalty: Double,
                               l2Penalty: Double,
                               iterations: Int,
                               step: Double? = nil,
                               momentum: Double = 1,
                               tolerance: Double = 1e-10) -> (weights: [Double], iterations: Int, converged: Bool) {
        let n = design.rows
        let p = design.columns
        guard n > 0, p > 0, targets.count == n else { return ([], 0, false) }
        let gradientScale = 1.0 / Double(n)
        var t = step ?? (1.0 / lipschitzConstant(design: design))
        if !(t > 0) { t = 1 }

        var w = [Double](repeating: 0, count: p)
        var y = w
        var momentumWeight = 1.0
        var previousObjective = Double.infinity
        var used = 0
        var converged = false

        for iteration in 1...Swift.max(1, iterations) {
            used = iteration
            var residual = design.multiplied(by: y)
            for index in 0..<residual.count { residual[index] -= targets[index] }
            var gradient = design.transposedMultiplied(by: residual).map { $0 * gradientScale }
            if l2Penalty > 0 {
                for index in 1..<p { gradient[index] += l2Penalty * y[index] }
            }
            var candidate = [Double](repeating: 0, count: p)
            var objective = Double.infinity
            var halvings = 0
            while true {
                candidate = softThreshold(
                    zip(y, gradient).map { $0 - t * $1 }, t * l1Penalty)
                if !candidate.isEmpty { candidate[0] = y[0] - t * gradient[0] }
                objective = ridgeL1Objective(design: design, targets: targets, weights: candidate,
                                             l1Penalty: l1Penalty, l2Penalty: l2Penalty)
                if objective <= previousObjective || halvings >= 40 { break }
                t /= 2
                halvings += 1
            }
            if halvings >= 40 && objective > previousObjective {
                w = candidate
                return (w, used, false)
            }
            previousObjective = objective
            w = candidate
            if kktResidual(design: design, targets: targets, weights: candidate,
                           l1Penalty: l1Penalty, l2Penalty: l2Penalty) <= tolerance {
                converged = true
                break
            }

            let nextMomentum = (1 + (1 + 4 * momentumWeight * momentumWeight).squareRoot()) / 2
            let ratio = (momentumWeight - 1) / nextMomentum
            y = zip(candidate, w).map { $0 + ratio * ($0 - $1) }
            w = candidate
            momentumWeight = nextMomentum
        }
        return (w, used, converged)
    }

    public static func kktResidual(design: RowMatrix, targets: [Double], weights: [Double],
                                    l1Penalty: Double, l2Penalty: Double) -> Double {
        let n = design.rows
        let p = design.columns
        guard n > 0, p > 0, targets.count == n, weights.count == p else { return .infinity }
        var residual = design.multiplied(by: weights)
        for index in 0..<n { residual[index] -= targets[index] }
        var gradient = design.transposedMultiplied(by: residual).map { $0 / Double(n) }
        if l2Penalty > 0 {
            for index in 1..<p { gradient[index] += l2Penalty * weights[index] }
        }
        var worst = 0.0
        for index in 1..<p {
            let value = weights[index]
            let gap: Double
            if value == 0 {
                gap = max(0, abs(gradient[index]) - l1Penalty)
            } else {
                gap = abs(gradient[index] + l1Penalty * (value < 0 ? -1 : 1))
            }
            worst = Swift.max(worst, gap)
        }
        return worst
    }

    public static func ridgeL1Objective(design: RowMatrix, targets: [Double], weights: [Double],
                                        l1Penalty: Double, l2Penalty: Double) -> Double {
        let n = design.rows
        guard n > 0, design.columns > 0 else { return .infinity }
        var squares = 0.0
        for row in 0..<n {
            var predicted = 0.0
            for column in 0..<design.columns { predicted += design[row, column] * weights[column] }
            let residual = predicted - targets[row]
            squares += residual * residual
        }
        var total = squares / (2.0 * Double(n))
        if l2Penalty > 0 {
            for column in 1..<design.columns { total += 0.5 * l2Penalty * weights[column] * weights[column] }
        }
        if l1Penalty > 0 {
            for column in 1..<design.columns {
                total += l1Penalty * (weights[column] < 0 ? -weights[column] : weights[column])
            }
        }
        return total
    }

    public static func logisticL1(design: RowMatrix,
                                 targets: [Double],
                                 l1Penalty: Double,
                                 l2Penalty: Double,
                                 iterations: Int,
                                 step: Double? = nil,
                                 momentum: Double = 1,
                                 tolerance: Double = 1e-10) -> (weights: [Double], iterations: Int, converged: Bool) {
        let n = design.rows
        let p = design.columns
        guard n > 0, p > 0, targets.count == n else { return ([], 0, false) }
        let gradientScale = 1.0 / Double(n)
        var t = step ?? (4.0 / lipschitzConstant(design: design))
        if !(t > 0) { t = 1 }

        var w = [Double](repeating: 0, count: p)
        var y = w
        var momentumWeight = 1.0
        var previousObjective = Double.infinity
        var used = 0
        var converged = false

        for iteration in 1...Swift.max(1, iterations) {
            used = iteration
            let probabilities = design.multiplied(by: y).map { RowMatrix.logistic([$0])[0] }
            var residual = probabilities
            for index in 0..<residual.count { residual[index] -= targets[index] }
            var gradient = design.transposedMultiplied(by: residual).map { $0 * gradientScale }
            if l2Penalty > 0 {
                for index in 1..<p { gradient[index] += l2Penalty * y[index] }
            }
            var candidate = [Double](repeating: 0, count: p)
            var objective = Double.infinity
            var halvings = 0
            while true {
                candidate = softThreshold(
                    zip(y, gradient).map { $0 - t * $1 }, t * l1Penalty)
                if !candidate.isEmpty { candidate[0] = y[0] - t * gradient[0] }
                objective = logisticObjective(design: design, targets: targets, weights: candidate,
                                             l1Penalty: l1Penalty, l2Penalty: l2Penalty)
                if objective <= previousObjective || halvings >= 40 { break }
                t /= 2
                halvings += 1
            }
            if halvings >= 40 && objective > previousObjective {
                w = candidate
                return (w, used, false)
            }
            previousObjective = objective
            w = candidate
            if kktResidual(design: design, targets: targets, weights: candidate,
                           l1Penalty: l1Penalty, l2Penalty: l2Penalty) <= tolerance {
                converged = true
                break
            }

            let nextMomentum = (1 + (1 + 4 * momentumWeight * momentumWeight).squareRoot()) / 2
            let ratio = (momentumWeight - 1) / nextMomentum
            y = zip(candidate, w).map { $0 + ratio * ($0 - $1) }
            w = candidate
            momentumWeight = nextMomentum
        }
        return (w, used, converged)
    }

    public static func logisticObjective(design: RowMatrix, targets: [Double], weights: [Double],
                                        l1Penalty: Double, l2Penalty: Double) -> Double {
        let n = design.rows
        guard n > 0, design.columns > 0 else { return .infinity }
        var total = 0.0
        for row in 0..<n {
            var score = 0.0
            for column in 0..<design.columns { score += design[row, column] * weights[column] }
            let target = targets[row]
            total += RowMatrix.logitLoss(target, score)
        }
        total /= Double(n)
        if l2Penalty > 0 {
            for column in 1..<design.columns { total += 0.5 * l2Penalty * weights[column] * weights[column] }
        }
        if l1Penalty > 0 {
            for column in 1..<design.columns {
                total += l1Penalty * (weights[column] < 0 ? -weights[column] : weights[column])
            }
        }
        return total
    }
}
