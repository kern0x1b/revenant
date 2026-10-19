import UIKit
import CoreGraphics

public struct Animation: Equatable, Hashable {
    enum Curve: Equatable, Hashable { case linear, easeIn, easeOut, easeInOut, spring }
    var curve: Curve
    var duration: Double
    /// Where `.speed`, `.delay` and `.logicallyComplete` have put the animation in time.
    var retiming = Retiming()
    var delay: Double { retiming.delay }
    var rate: Double { retiming.rate }
    /// What a spring was given as its blend: held and compared as Apple's animation does, and moving nothing in time.
    var blend = 0.0
    /// How many passes the animation makes and whether every other is played back to front, as `repeatCount` and `repeatForever` set.
    var legs: Float { Float(retiming.repeated?.count ?? 1) }
    var autoreverses: Bool { retiming.repeated?.reverses ?? false }
    /// Set when the timing is a spring or one of the newer curves: what the interpolator asks instead of `curve`.
    var timing: Timing?
    /// Set when the animation computes its own values.
    var custom: CustomAnimationBox?

    enum Timing: Hashable {
        case curve(UnitCurve)
        case spring(Spring)
        case interpolating(InterpolatingSpring)

        // Two animations of springs are equal by the numbers they hold, to the last bit, which is finer than two springs
        // being equal (a pair of numbers one bit apart is the same spring and another animation, as in Apple's).
        static func == (lhs: Timing, rhs: Timing) -> Bool {
            switch (lhs, rhs) {
            case (.curve(let left), .curve(let right)): return left == right
            case (.spring(let left), .spring(let right)): return left.heldNumbers == right.heldNumbers
            case (.interpolating(let left), .interpolating(let right)): return left == right
            default: return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .curve(let curve): hasher.combine(0); hasher.combine(curve)
            case .spring(let spring): hasher.combine(1); hasher.combine(spring.heldNumbers)
            case .interpolating(let held): hasher.combine(2); hasher.combine(held)
            }
        }
    }

    init(curve: Curve, duration: Double, delay: Double, timing: Timing? = nil) {
        self.curve = curve
        self.duration = duration
        if delay != 0 { retiming = retiming.delaying(by: delay) }
        self.timing = timing
    }

    public static let `default` = Animation(curve: .easeInOut, duration: 0.25, delay: 0)
    public static func linear(duration: Double = 0.25) -> Animation { Animation(curve: .linear, duration: duration, delay: 0) }
    public static var linear: Animation { linear() }
    public static func easeIn(duration: Double = 0.25) -> Animation { Animation(curve: .easeIn, duration: duration, delay: 0) }
    public static var easeIn: Animation { easeIn() }
    public static func easeOut(duration: Double = 0.25) -> Animation { Animation(curve: .easeOut, duration: duration, delay: 0) }
    public static var easeOut: Animation { easeOut() }
    public static func easeInOut(duration: Double = 0.25) -> Animation { Animation(curve: .easeInOut, duration: duration, delay: 0) }
    public static var easeInOut: Animation { easeInOut() }
    // An animation holding the spring exactly as it is given, which is what the named forms of it (a response and a
    // fraction, a duration and a bounce, a mass and a stiffness) hold in Apple's too.
    static func holding(_ spring: Spring, blendDuration: Double = 0) -> Animation {
        var held = Animation(curve: .spring, duration: spring.response, delay: 0, timing: .spring(spring))
        held.blend = blendDuration
        return held
    }
    static func interpolating(_ held: InterpolatingSpring) -> Animation {
        Animation(curve: .spring, duration: held.spring.response, delay: 0, timing: .interpolating(held))
    }
    // A spring handed over as a value comes back out of the animation as the numbers it is stored as, not as the pair it
    // was made of, so it is another animation than the one made of that pair when those differ in the last bit.
    public static func spring(_ spring: Spring, blendDuration: Double = 0) -> Animation {
        holding(spring.asFluid, blendDuration: blendDuration)
    }
    @_disfavoredOverload
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation {
        holding(Spring(response: response, dampingRatio: dampingFraction), blendDuration: blendDuration)
    }
    public static func spring(duration: Double = 0.5, bounce: Double = 0, blendDuration: Double = 0) -> Animation {
        holding(Spring(duration: duration, bounce: bounce), blendDuration: blendDuration)
    }
    public static var spring: Animation { spring() }
    @_disfavoredOverload
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation {
        holding(Spring(response: response, dampingRatio: dampingFraction), blendDuration: blendDuration)
    }
    public static func interactiveSpring(duration: Double = 0.15, extraBounce: Double = 0, blendDuration: Double = 0.25) -> Animation {
        spring(duration: duration, bounce: 0.15 + extraBounce, blendDuration: blendDuration)
    }
    public static var interactiveSpring: Animation { interactiveSpring() }
    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        spring(duration: duration, bounce: extraBounce)
    }
    public static var smooth: Animation { smooth() }
    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        spring(duration: duration, bounce: 0.15 + extraBounce)
    }
    public static var snappy: Animation { snappy() }
    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        spring(duration: duration, bounce: 0.3 + extraBounce)
    }
    public static var bouncy: Animation { bouncy() }
    public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation {
        interpolating(InterpolatingSpring(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity))
    }
    public static func interpolatingSpring(_ spring: Spring, initialVelocity: Double = 0.0) -> Animation {
        interpolating(InterpolatingSpring(spring, initialVelocity: initialVelocity))
    }
    public static func interpolatingSpring(duration: Double = 0.5, bounce: Double = 0, initialVelocity: Double = 0.0) -> Animation {
        interpolating(InterpolatingSpring(duration: duration, bounce: bounce, initialVelocity: initialVelocity))
    }
    public static func timingCurve(_ curve: UnitCurve, duration: Double) -> Animation {
        Animation(curve: .linear, duration: duration, delay: 0, timing: .curve(curve))
    }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double = 0.35) -> Animation {
        // the four numbers go in as they are: a UnitPoint holds CGFloats, which are Floats on this architecture, and a
        // control point that went through one would no longer be the number it was given
        timingCurve(UnitCurve(.bezier(c0x, c0y, c1x, c1y)), duration: duration)
    }
    public func timingCurve(_ curve: UnitCurve, duration: Double) -> Animation {
        Animation.timingCurve(curve, duration: duration)
    }
    public func delay(_ delay: Double) -> Animation { with { $0.retiming = retiming.delaying(by: delay) } }
    public func speed(_ speed: Double) -> Animation { with { $0.retiming = retiming.speeding(by: speed) } }
    /// The moment the animation's own curve says it is over, which for a spring is when it settles.
    public func logicallyComplete(after duration: Double) -> Animation { with { $0.retiming = retiming.completing(after: duration) } }

    // SwiftUI counts every pass, forwards or back, as one repeat; Core Animation counts a forward and a back together.
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation {
        with { $0.retiming = retiming.repeating(count: Double(max(repeatCount, 1)), reverses: autoreverses) }
    }
    public func repeatForever(autoreverses: Bool = true) -> Animation {
        with { $0.retiming = retiming.repeating(count: .infinity, reverses: autoreverses) }
    }

    // An entrance or an exit plays once, however the animation around it repeats.
    var once: Animation { with { $0.retiming = retiming.once } }

    /// How the animation goes after it was asked to begin, for something that is `distance` away from where it is going.
    func course(distance: Double) -> AnimationCourse {
        let base: BaseTrack
        switch timing {
        case .spring(let spring):
            base = .fluid(spring, distance: distance)
        case .interpolating(let held):
            base = .interpolating(held)
        default:
            let own = max(duration, 0.001)
            base = .lasting(own) { progress($0) }
        }
        return AnimationCourse(base, retiming: retiming)
    }

    /// How the animation goes for a value that is on its way somewhere else already: what the value takes of it when it is told to go to a
    /// new place by it.
    var pace: Pace {
        var spring: Spring?
        if case .spring(let held) = timing { spring = held }
        return Pace(retiming: retiming, spring: spring, course: { course(distance: $0) })
    }

    /// How far the animation of a curve has come at a fraction of its own length.
    private func progress(_ t: Double) -> Double {
        switch timing {
        case .curve(let unit): return unit.value(at: t)
        default: return Easing.apply(curve, t)
        }
    }

    /// How long the animation is after its delay, counting a spring by its response, or by what `logicallyComplete` was given.
    var logicalDuration: Double { max(retiming.logicalMoment(naturally: duration) - delay, 0) }

    /// The moment the animation is logically complete, in seconds after it was asked to begin: the one `logicallyComplete` gave, or for a
    /// spring the end of its response in the first pass, whatever it is repeated (the flag of Apple's flips there, `.agent-work/runs/54-hor/r5.swift`),
    /// and for any other animation the end of the last pass.
    var logicalMoment: Double {
        if let given = retiming.givenLogicalEnd { return given }
        switch timing {
        case .spring, .interpolating: return retiming.logicalMoment(naturally: duration)
        default: return course(distance: 1).length ?? .infinity
        }
    }

    /// What UIView is told the animation lasts: its duration at the rate it is played.
    var playedDuration: Double { rate > 0 ? duration / rate : duration }

    func with(_ change: (inout Animation) -> Void) -> Animation {
        var copy = self
        change(&copy)
        return copy
    }

    var options: UIView.AnimationOptions {
        var options: UIView.AnimationOptions
        switch curve {
        case .linear: options = .curveLinear
        case .easeIn: options = .curveEaseIn
        case .easeOut: options = .curveEaseOut
        case .easeInOut, .spring: options = .curveEaseInOut
        }
        if legs > 1 { options.insert(.repeat) }
        if autoreverses { options.insert(.autoreverse) }
        return options
    }

    func run(_ animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        // A test driving the clock itself has no render server to hand the animation to: the changes are made at once, and
        // the animation is over when that clock says its length has passed.
        if ValueAnimator.manual {
            animations()
            guard let completion else { return }
            let total = max(logicalMoment, 0)
            let over = ValueAnimator(delay: 0, total: total, at: { (min(max($0 / max(total, 0.001), 0), 1), $0 >= total) })
            over.finished = { completion(true) }
            over.start()
            return
        }
        if timing != nil {
            _Unsupported.note("Animation.spring", "UIView of iOS 6 animates with one of four named curves and knows no spring, so a UIView property follows the nearest of the four; the engine's own frame-by-frame animations are driven by the spring itself")
        }
        let cycles = autoreverses ? legs / 2 : legs
        UIView.animate(withDuration: playedDuration, delay: delay, options: options, animations: {
            if self.legs > 1 && self.legs.isFinite { UIView.setAnimationRepeatCount(cycles) }
            animations()
        }, completion: completion)
    }
}

public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    let previous = Updates.pendingAnimation
    Updates.pendingAnimation = animation
    defer { Updates.pendingAnimation = previous }
    return try body()
}

struct AnimationModifier: NodeModifier {
    let animation: Animation?
    var value: AnyHashable? = nil
    var changed: ((Any?) -> Bool)? = nil
    var boxed: Any? = nil
    func makeModifierNode(_ content: any View, _ env: EnvironmentValues) -> Node { AnimationNode() }
}

final class AnimationNode: Node {
    var child: Node?
    var lastValue: Any?
    override var disposableChildren: [Node] { child.map { [$0] } ?? [] }
    override var flattened: [LayoutNode] { child?.flattened ?? [] }
    override func update(_ view: any View, _ env: EnvironmentValues) {
        super.update(view, env)
        let m = view as! ModifiedViewLike
        let modifier = m.modifierValue as! AnimationModifier
        var inner = env
        if let changed = modifier.changed {
            let moved = changed(lastValue)
            inner.animation = moved ? modifier.animation : env.animation
            if moved, let animation = modifier.animation, Updates.animationForFlush == nil { Updates.animationForFlush = animation }
            lastValue = modifier.boxed
        } else {
            inner.animation = modifier.animation
        }
        child = adopt(reconcile(child, m.modifiedContent, inner))
    }
    override func mountContents() { child?.mount() }
}

extension View {
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        _ModifiedView(content: self, modifier: AnimationModifier(animation: animation, value: nil, changed: { last in
            guard let last else { return false }
            return (last as? V) != value
        }).withValue(value))
    }
    public func animation(_ animation: Animation?) -> some View {
        _ModifiedView(content: self, modifier: AnimationModifier(animation: animation))
    }
}

extension AnimationModifier {
    func withValue<V>(_ value: V) -> AnimationModifier {
        var copy = self
        copy.boxed = value
        return copy
    }
}
