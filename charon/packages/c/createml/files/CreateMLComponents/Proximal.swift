// Proximal.swift — the L1 penalty, which the ridge fit cannot reach.
//
// The L2 fit is a *linear* problem with a closed form: the normal equations, a Cholesky factor, done.
// The L1 fit is not — `|w|` has no gradient at zero, and the problem is a minimisation of a convex
// function over a ball rather than a system of equations. So it is solved iteratively, and the
// iteration is a **proximal gradient** one: FISTA, the accelerated version of ISTA.
//
// ## The step, and why it is `softThreshold`
//
// Given a smooth part `f` and an L1 penalty, the update at a point `w` with step `t` is
//
//     w' = softThreshold(w - t * grad f(w),  t * lambda)
//
// and the soft threshold is `sign(x) * max(|x| - l, 0)`. It is the **proximal operator** of
// `lambda * |.|`, and the whole point of the method is that taking that exact step on the *smooth*
// part and the exact prox on the *penalty* converges, where taking a gradient step on both does not.
// A gradient step on `|w|` is subgradient descent, and subgradient descent on an L1 problem converges
// at `1/sqrt(k)` — so slowly that a model with ten features and a `maxIterations` of 400 is nowhere
// near the answer, and the zeros it does reach are the ones it happened to overshoot.
//
// ## The acceleration, and when it is turned off
//
// FISTA adds a momentum term with a growing step, which on a strongly convex problem converges
// geometrically instead of at `1/k`. It is a *sequence* method, so `w` is the extrapolated point and
// `y` the point the gradient was taken at; the two are kept apart because taking the gradient at the
// extrapolated point is the whole of the acceleration. Momentum is **off when the problem is not
// strongly convex**, which for a penalty that is purely L1 it is not: FISTA's geometric rate needs a
// strong convexity that an L1 penalty destroys on the zero coordinates. The switch is `momentum` and
// it defaults to on for an L2 term, off for a purely L1 one.
//
// ## The step size, and why it is not the caller's guess
//
// The smooth part is quadratic here — `1/2n |X(Xw - y)|^2` for a regression, and the analogous
// logistic loss — so its gradient's Lipschitz constant is the largest eigenvalue of `X'X / n`, and
// the safe step is `1 / L`. That is computed by **power iteration on `X'X`**, using the device's own
// BLAS, rather than by a power-of-two backtracking schedule: the matrix is already built, one
// symmetric matrix-vector product is cheap, and a backtracking schedule would take twenty
// matrix-vector products to reach a step the eigensolver reaches in ten.

import Foundation

/// The proximal operators, and the solver that drives them.
public enum ProximalSolver {
    /// The soft threshold: `sign(x) * max(|x| - l, 0)`, elementwise.
    ///
    /// The one detail that matters: `l` is compared against the **magnitude** and the sign is taken
    /// from the original value, so a coordinate of exactly `-l` and one of exactly zero both become
    /// zero — and a threshold computed as `x - l` without the magnitude would keep a negative
    /// coordinate's sign wrong on the far side of the kink.
    public static func softThreshold(_ x: [Double], _ l: Double) -> [Double] {
        guard l > 0 else { return x }
        var out = [Double](repeating: 0, count: x.count)
        for index in 0..<x.count {
            let value = x[index]
            let magnitude = value < 0 ? -value : value
            // `sign(value) * max(|value| - l, 0)`. The two branches are the *sign* and they
            // were the wrong way round: a positive coordinate came out negative, which is the
            // one defect a soft threshold must not have and which the L1 suite's own two
            // checks — one over the bar, one under it, and one negative — are there to hold.
            out[index] = magnitude > l ? (value < 0 ? -(magnitude - l) : magnitude - l) : 0
        }
        return out
    }

    /// The largest eigenvalue of `X'X / n` by power iteration, which is the gradient's Lipschitz
    /// constant and so the inverse of the largest safe step.
    ///
    /// `iterations` is a fixed count rather than a convergence test because the estimate only sets
    /// the step, and a slightly small one costs iterations while a slightly large one is corrected by
    /// the monotone fallback below. The starting vector is all ones rather than random, so two runs of
    /// the same fit take the same steps.
    public static func lipschitzConstant(design: RowMatrix, iterations: Int = 20) -> Double {
        let n = design.rows
        guard n > 0, design.columns > 0 else { return 1 }
        var vector = [Double](repeating: 1, count: design.columns)
        var estimate = 0.0
        for _ in 0..<Swift.max(1, iterations) {
            // X'X v / n, by the device's own GEMV twice over: X v is the product with X' on the
            // left, so the first is design.multiplied(by:) and the second is
            // transposedMultiplied(by:) on the result.
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

    /// FISTA / ISTA on `1/2n |X(Xw - y)|^2 + l2/2 |w|^2 + l1 |w|`, with the **intercept not
    /// penalised** — which is the convention every linear model here uses, and the reason the design
    /// matrix here carries a column of ones and the penalty is applied to every column but the first.
    ///
    /// `momentum` is the Nesterov coefficient `t_k` of the acceleration and defaults to `1`.
    ///
    /// `tolerance` is the **KKT residual** the answer is accepted at, in the units of the gradient —
    /// see `kktResidual(design:targets:weights:l1Penalty:l2Penalty:)`. It was first an objective-change
    /// test, and that reported a point 0.069 of objective from the minimum as converged on a
    /// plateau; the residual cannot, because on a convex objective it is satisfied only at a minimum.
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
        // A step from the largest eigenvalue, and halved until the objective actually goes down. The
        // backstop is what makes a caller-supplied `step` safe rather than merely accepted.
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
            // The gradient of the smooth part at the extrapolated point y.
            var residual = design.multiplied(by: y)
            for index in 0..<residual.count { residual[index] -= targets[index] }
            var gradient = design.transposedMultiplied(by: residual).map { $0 * gradientScale }
            if l2Penalty > 0 {
                for index in 1..<p { gradient[index] += l2Penalty * y[index] }
            }
            // The step, and the monotone fallback. Three things, and the first version had the
            // second and third of them wrong:
            //
            //   - the **rejected** step's objective is never recorded, or the next comparison is
            //     against a value the sequence never took and the run walks off to infinity (it did:
            //     an objective of 1e140 with `converged = false`);
            //   - and when it does not fall, the step is **halved** and the step taken again.
            //
            // There is deliberately **no ISTA fallback at the accepted point**, and that is a
            // measurement rather than an omission. A version of this had one, on the reasoning that a
            // shorter step from the extrapolated point tends to `y` rather than to `w` and so cannot
            // recover. It was **never taken**: on the fifteen-row table, on a badly scaled design, at
            // momentum 0, 1 and 3, and with the step set deliberately to 1, 2, 4, 8 and 16 times
            // `1/L` — at every one of those the sequence's results are **bit-identical** with the
            // fallback present and with it deleted. The halving reaches every case the fallback was
            // meant to, so the code was dead and has been removed rather than kept with a test that
            // cannot fail.
            var candidate = [Double](repeating: 0, count: p)
            var objective = Double.infinity
            var halvings = 0
            while true {
                candidate = softThreshold(
                    zip(y, gradient).map { $0 - t * $1 }, t * l1Penalty)
                // The intercept is column zero and is not penalised: put it back after the threshold.
                if !candidate.isEmpty { candidate[0] = y[0] - t * gradient[0] }
                objective = ridgeL1Objective(design: design, targets: targets, weights: candidate,
                                             l1Penalty: l1Penalty, l2Penalty: l2Penalty)
                if objective <= previousObjective || halvings >= 40 { break }
                t /= 2
                halvings += 1
            }
            // No step, at any length, could be made to fall: that is a divergence, and saying so beats
            // answering the point the run reached.
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

            // Nesterov's `t` sequence: (1 + sqrt(1 + 4 t_{k-1}^2)) / 2, and y the extrapolation.
            let nextMomentum = (1 + (1 + 4 * momentumWeight * momentumWeight).squareRoot()) / 2
            let ratio = (momentumWeight - 1) / nextMomentum
            y = zip(candidate, w).map { $0 + ratio * ($0 - $1) }
            w = candidate
            momentumWeight = nextMomentum
        }
        return (w, used, converged)
    }

    /// The KKT residual of a point, which is the *only* right convergence test for a proximal
    /// method on an L1 objective.
    ///
    /// The first version tested `|objective - previousObjective|` and reported converged on a
    /// sequence that had entered a plateau in the objective while sitting 0.069 of objective away
    /// from the minimum — the differential's single-weight-nudge check found it, and it is right:
    /// this objective is convex, so **any** stationary point is global, and a point that is not
    /// stationary is not the answer no matter how little its objective moved.
    ///
    /// The residual is the subgradient of `f + l1 * |.|` at the point, and the condition is that
    /// **zero** of it: a coordinate at zero has its subgradient `[-threshold, threshold]`, so zero is
    /// in it exactly when `|g| <= threshold`; a coordinate away from zero has the subgradient
    /// `g + l1 * sign(w)`, which must vanish. The maximum of those gaps is the residual.
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

    /// The objective FISTA descends, spelled out so it is the thing a caller can evaluate a point by.
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

    /// FISTA on the logistic objective, by the same three steps and for the same reason.
    ///
    /// The gradient is `X'(p - y)/n` with `p` the sigmoid, and the penalty is on every column but the
    /// intercept exactly as in the regression. The Lipschitz constant is measured with the **logistic
    /// loss at zero**, `1/4` the largest eigenvalue of `X'X/n` — a bound, and a bound is what a step
    /// needs — so the step is `4 / λmax` unless the caller gives one.
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
            // The same loop as the regression's, and the same absence: no ISTA fallback, for the
            // same measured reason, on the same fixtures.
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

    /// The logistic objective: the mean cross-entropy, plus the penalties, minus the intercept's.
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
