import CoreGraphics

// The timing curves of the newer animations. Apple's values are three cubic Béziers and three circular
// arcs, measured against the framework of macOS 27 to nine decimals (.agent-work/host/spring.out).
public struct UnitCurve: Hashable {
    enum Kind: Hashable {
        case linear
        case bezier(Double, Double, Double, Double)
        case circularIn, circularOut, circularInOut
    }
    let kind: Kind

    init(_ kind: Kind) { self.kind = kind }

    public static let linear = UnitCurve(.linear)
    public static let easeIn = UnitCurve(.bezier(0.42, 0, 1, 1))
    public static let easeOut = UnitCurve(.bezier(0, 0, 0.58, 1))
    public static let easeInOut = UnitCurve(.bezier(0.42, 0, 0.58, 1))
    @available(*, deprecated, message: "Use easeInOut instead")
    public static let easeInEaseOut = easeInOut
    public static let circularEaseIn = UnitCurve(.circularIn)
    public static let circularEaseOut = UnitCurve(.circularOut)
    public static let circularEaseInOut = UnitCurve(.circularInOut)

    public static func bezier(startControlPoint: UnitPoint, endControlPoint: UnitPoint) -> UnitCurve {
        UnitCurve(.bezier(Double(startControlPoint.x), Double(startControlPoint.y),
                         Double(endControlPoint.x), Double(endControlPoint.y)))
    }

    public var inverse: UnitCurve {
        switch kind {
        case .linear: return UnitCurve(.linear)
        case .bezier(let x1, let y1, let x2, let y2): return UnitCurve(.bezier(y1, x1, y2, x2))
        case .circularIn: return UnitCurve(.circularOut)
        case .circularOut: return UnitCurve(.circularIn)
        case .circularInOut: return UnitCurve(.circularInOut)
        }
    }

    // A quarter circle of radius one, from (0,0) to (1,1): the arc a quarter turn of a wheel traces.
    static func arc(_ t: Double) -> Double { 1 - (1 - t * t).squareRoot() }
    static func arcSlope(_ t: Double) -> Double { t / (1 - t * t).squareRoot() }

    // The point of the curve at a progress, for the circular ones: the arc's own parameter.
    private func circular(_ t: Double) -> Double {
        switch kind {
        case .circularIn: return UnitCurve.arc(t)
        case .circularOut: return 1 - UnitCurve.arc(1 - t)
        default: return t < 0.5 ? UnitCurve.arc(t * 2) / 2 : 1 - UnitCurve.arc(2 - t * 2) / 2
        }
    }

    private func circularSlope(_ t: Double) -> Double {
        switch kind {
        case .circularIn: return UnitCurve.arcSlope(t)
        case .circularOut: return UnitCurve.arcSlope(1 - t)
        default: return t < 0.5 ? UnitCurve.arcSlope(t * 2) : UnitCurve.arcSlope(2 - t * 2)
        }
    }
    public func value(at progress: Double) -> Double {
        if progress <= 0 { return 0 }
        if progress >= 1 { return 1 }
        switch kind {
        case .linear: return progress
        case .circularIn, .circularOut, .circularInOut: return circular(progress)
        case .bezier: return bezierValue(progress)
        }
    }

    public func velocity(at progress: Double) -> Double {
        switch kind {
        case .linear: return 1
        case .circularIn, .circularOut, .circularInOut: return circularSlope(progress)
        case .bezier:
            // At either end the curve's own parameter is the end itself, where the slope of a Bézier
            // is a limit; it is taken from just inside.
            let u = progress <= 0 ? 1e-7 : (progress >= 1 ? 1 - 1e-7 : parameter(progress))
            let (dx, dy) = slope(u)
            return dx == 0 ? 0 : dy / dx
        }
    }

    // The Bézier's own parameter for a progress: the x of a Bézier is not its parameter.
    private func parameter(_ x: Double) -> Double {
        guard case .bezier(let x1, _, let x2, _) = kind else { return x }
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var low = 0.0, high = 1.0
        for _ in 0..<40 {
            let u = (low + high) / 2
            if UnitCurve.sample(x1, x2, u) < x { low = u } else { high = u }
        }
        return (low + high) / 2
    }

    private func bezierValue(_ x: Double) -> Double {
        guard case .bezier(_, let y1, _, let y2) = kind else { return x }
        return UnitCurve.sample(y1, y2, parameter(x))
    }

    private func slope(_ u: Double) -> (x: Double, y: Double) {
        guard case .bezier(let x1, let y1, let x2, let y2) = kind else { return (1, 1) }
        return (3 * UnitCurve.slope(x1, x2, u), 3 * UnitCurve.slope(y1, y2, u))
    }

    private static func sample(_ a: Double, _ b: Double, _ u: Double) -> Double {
        let v = 1 - u
        return 3 * a * v * v * u + 3 * b * v * u * u + u * u * u
    }

    private static func slope(_ a: Double, _ b: Double, _ u: Double) -> Double {
        let v = 1 - u
        return 3 * a * (v * v - 2 * v * u) + 3 * b * (2 * v * u - u * u) + 3 * u * u
    }
}
