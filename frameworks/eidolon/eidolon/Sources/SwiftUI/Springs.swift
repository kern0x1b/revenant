import CoreGraphics

public struct Spring: Hashable {
    enum Form: Hashable {
        case duration(Double, Double)
        case response(Double, Double)
        case system(Double, Double, Double)
    }
    var form: Form

    private var identity: (damped: Double, decay: Double, mass: Double) {
        func root(_ square: Double) -> Double { square >= 0 ? square.squareRoot() : -(-square).squareRoot() }
        if case .system(let mass, let stiffness, let damping) = form {
            let decay = damping / (2 * mass)
            return (root(stiffness / mass - decay * decay), decay, mass)
        }
        let ratio = dampingRatio
        return (2 * Double.pi * root(1 - ratio * ratio) / response, 2 * Double.pi * ratio / response, 1)
    }

    var asFluid: Spring {
        let (damped, decay, _) = identity
        let response = 2 * Double.pi / ((damped >= 0 ? damped * damped : -(damped * damped)) + decay * decay).squareRoot()
        let ratio = decay * response / (2 * Double.pi)
        let bounce = ratio <= 1 ? 1 - ratio : 1 / ratio - 1
        return Spring(response: response, dampingRatio: bounce >= 0 ? 1 - bounce : 1 / (bounce + 1))
    }

    var heldNumbers: [Double] { [response, dampingRatio, mass, stiffness, damping] }

    public static func == (lhs: Spring, rhs: Spring) -> Bool {
        let (left, right) = (lhs.identity, rhs.identity)
        return left.damped == right.damped && left.decay == right.decay && left.mass == right.mass
    }

    public func hash(into hasher: inout Hasher) {
        let key = identity
        hasher.combine(key.damped)
        hasher.combine(key.decay)
        hasher.combine(key.mass)
    }

    var frequency: Double { 2 * Double.pi / max(response, .leastNormalMagnitude) }

    public init(response: Double, dampingRatio: Double) {
        form = .response(response, dampingRatio)
    }

    public init(duration: Double = 0.5, bounce: Double = 0) {
        form = .duration(duration, bounce)
    }

    public init(mass: Double = 1, stiffness: Double, damping: Double, allowOverDamping: Bool = false) {
        let critical = 2 * (mass * stiffness).squareRoot()
        form = .system(mass, stiffness, allowOverDamping ? damping : min(damping, critical))
    }

    public init(settlingDuration: Double, dampingRatio: Double, epsilon: Double = 0.001) {
        let time = settlingDuration.isNaN ? 0.01 : min(max(settlingDuration, 0.01), 10)
        if dampingRatio >= 1 {
            var x = 1 - log(epsilon)
            for _ in 0..<64 {
                let next = x - (log(1 + x) - x - log(epsilon)) / (1 / (1 + x) - 1)
                if next == x { break }
                x = next
            }
            self.init(response: 2 * Double.pi * time / x, dampingRatio: 1)
            return
        }
        let decay = log(dampingRatio / ((1 - dampingRatio * dampingRatio).squareRoot() * epsilon)) / time
        guard dampingRatio > 0, decay > 0 else {
            self.init(response: .nan, dampingRatio: .nan)
            return
        }
        self.init(response: 2 * Double.pi * dampingRatio / decay, dampingRatio: dampingRatio)
    }

    public static func smooth(duration: Double = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: extraBounce) }
    public static func snappy(duration: Double = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: 0.15 + extraBounce) }
    public static func bouncy(duration: Double = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: 0.3 + extraBounce) }
    public static var smooth: Spring { smooth() }
    public static var snappy: Spring { snappy() }
    public static var bouncy: Spring { bouncy() }

    public var response: Double {
        switch form {
        case .duration(let duration, _): return duration
        case .response(let response, _): return response
        case .system(let mass, let stiffness, _): return 2 * Double.pi * (mass / stiffness).squareRoot()
        }
    }
    public var duration: Double { response }
    public var dampingRatio: Double {
        switch form {
        case .duration(_, let bounce):
            if bounce <= -1 { return .nan }
            if bounce < 0 { return 1 / (bounce + 1) }
            return 1 - min(bounce, 1)
        case .response(_, let ratio): return ratio
        case .system(let mass, let stiffness, let damping): return damping / (2 * (mass * stiffness).squareRoot())
        }
    }
    public var bounce: Double {
        let ratio = dampingRatio
        return ratio > 1 ? 1 / ratio - 1 : 1 - ratio
    }
    public var mass: Double {
        if case .system(let mass, _, _) = form { return mass }
        return 1
    }
    public var stiffness: Double {
        let ratio = dampingRatio
        guard ratio > 1 else {
            if case .system(_, let stiffness, _) = form { return stiffness }
            return frequency * frequency
        }
        return frequency * frequency * (2 * ratio * ratio - 1)
    }
    public var damping: Double {
        switch form {
        case .system(_, _, let damping): return damping
        default: return 2 * frequency * dampingRatio
        }
    }

    private func unit(time: Double) -> (a: Double, da: Double, b: Double, db: Double) {
        if time <= 0 { return (1, 0, 0, 1) }
        let w = frequency, z = dampingRatio
        guard w.isFinite else { return (0, 0, 0, 0) }
        if z < 1 {
            let decay = z * w
            let wd = w * (1 - z * z).squareRoot()
            let e = exp(-decay * time), c = cos(wd * time), n = sin(wd * time)
            return (e * (c + decay / wd * n), -e * n * w * w / wd, e * n / wd, e * (c - decay / wd * n))
        }
        if z == 1 {
            let e = exp(-w * time)
            return (e * (1 + w * time), -e * w * w * time, time * e, e * (1 - w * time))
        }
        let root = w * (z * z - 1).squareRoot()
        let slow = -z * w + root, fast = -z * w - root
        let es = exp(slow * time), ef = exp(fast * time)
        let gap = slow - fast
        return ((slow * ef - fast * es) / gap, slow * fast * (ef - es) / gap - 1, (es - ef) / gap, (slow * es - fast * ef) / gap)
    }

    func remaining(initialVelocity: Double, time: Double) -> Double {
        let u = unit(time: time)
        return u.a - initialVelocity * u.b
    }

    public func value<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, time: Double) -> V {
        let u = unit(time: time)
        return V.zero + target.scaled(by: 1 - u.a) + initialVelocity.scaled(by: u.b)
    }

    public func velocity<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, time: Double) -> V {
        let u = unit(time: time)
        return target.scaled(by: 0 - u.da) + initialVelocity.scaled(by: u.db)
    }

    public func force<V: VectorArithmetic>(target: V, position: V, velocity: V) -> V {
        (target - position).scaled(by: stiffness)
    }

    public func value<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, time: Double) -> V {
        var result = fromValue
        let travel = toValue.animatableData - fromValue.animatableData
        let u = unit(time: time)
        result.animatableData = fromValue.animatableData + travel.scaled(by: 1 - u.a) + initialVelocity.animatableData.scaled(by: u.b)
        return result
    }

    public func velocity<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, time: Double) -> V {
        var result = toValue
        let travel = toValue.animatableData - fromValue.animatableData
        let u = unit(time: time)
        result.animatableData = travel.scaled(by: 0 - u.da) + initialVelocity.animatableData.scaled(by: u.db)
        return result
    }

    public func force<V: Animatable>(fromValue: V, toValue: V, position: V, velocity: V) -> V {
        var result = position
        result.animatableData = (toValue.animatableData - position.animatableData).scaled(by: stiffness)
        return result
    }

    public func update<V: VectorArithmetic>(value: inout V, velocity: inout V, target: V, deltaTime: Double) {
        let travel = target - value
        let u = unit(time: deltaTime)
        let moved = travel.scaled(by: 1 - u.a) + velocity.scaled(by: u.b)
        let speed = travel.scaled(by: 0 - u.da) + velocity.scaled(by: u.db)
        value += moved
        velocity = speed
    }

    public func settlingDuration<V: VectorArithmetic>(target: V, initialVelocity: V = .zero, epsilon: Double) -> Double {
        settling(travel: target, velocity: initialVelocity, epsilon: epsilon)
    }

    public func settlingDuration<V: Animatable>(fromValue: V, toValue: V, initialVelocity: V, epsilon: Double) -> Double {
        let travel = toValue.animatableData - fromValue.animatableData
        return settling(travel: travel, velocity: initialVelocity.animatableData, epsilon: epsilon)
    }

    public var settlingDuration: Double { settling(travel: 1.0, velocity: 0.0, epsilon: 0.001) }

    private func settling<A: VectorArithmetic>(travel: A, velocity: A, epsilon: Double) -> Double {
        let z = dampingRatio
        guard !z.isNaN, response > 0 else { return 0 }
        func length(_ value: A) -> Double { value.magnitudeSquared.squareRoot() }
        if z < 1 {
            let decay = z * frequency
            if decay == 0 { return .infinity }
            let time = log((length(travel) + length(travel.scaled(by: decay) - velocity)) / epsilon) / decay
            return time.isNaN ? 0 : max(time, 0)
        }
        guard epsilon > 0 else { return 0 }
        let slowest = z == 1 ? frequency : frequency * (z - (z * z - 1).squareRoot())
        guard slowest > 0 else { return .infinity }
        var time = 0.0, settled = 0.0
        for _ in 0...Spring.scanned {
            let u = unit(time: time)
            let out = length(travel - (A.zero + travel.scaled(by: 1 - u.a) + velocity.scaled(by: u.b))) >= epsilon
            time += 0.1
            if out { settled = time }
        }
        return settled == time ? 0 : settled
    }
    private static let scanned = 1012

}

extension VectorArithmetic {
    func scaled(by share: Double) -> Self {
        var copy = self
        copy.scale(by: share)
        return copy
    }
}

struct Retiming: Hashable {
    enum Step: Hashable {
        case speed(Double)
        case delay(Double)
        case complete(Double)
        case repeating(count: Double, reverses: Bool)
    }
    private(set) var steps: [Step] = []

    init(steps: [Step] = []) { self.steps = steps }

    func speeding(by speed: Double) -> Retiming { appending(.speed(speed)) }
    func delaying(by seconds: Double) -> Retiming { appending(.delay(seconds)) }
    func completing(after seconds: Double) -> Retiming { appending(.complete(seconds)) }
    func repeating(count: Double, reverses: Bool) -> Retiming { appending(.repeating(count: count, reverses: reverses)) }

    private func appending(_ step: Step) -> Retiming {
        var next = self
        next.steps.append(step)
        return next
    }

    private var folded: (rate: Double, delay: Double, logicalEnd: Double?) {
        var rate = 1.0, delay = 0.0
        var logicalEnd: Double?
        for step in steps {
            switch step {
            case .speed(let speed):
                rate *= speed
                if speed > 0 { delay /= speed; logicalEnd = logicalEnd.map { $0 / speed } }
            case .delay(let seconds):
                delay += seconds
                logicalEnd = logicalEnd.map { $0 + seconds }
            case .complete(let seconds):
                logicalEnd = seconds
            case .repeating:
                break
            }
        }
        return (rate, delay, logicalEnd)
    }
    var rate: Double { folded.rate }
    var delay: Double { folded.delay }
    var givenLogicalEnd: Double? { folded.logicalEnd }

    func logicalMoment(naturally seconds: Double) -> Double {
        let now = folded
        return now.logicalEnd ?? now.delay + outer(seconds)
    }

    func inner(at elapsed: Double) -> Double {
        let now = folded
        return now.rate > 0 ? max(now.rate * (elapsed - now.delay), 0) : 0
    }

    var isRetimed: Bool { !steps.isEmpty }

    func baseTime(at elapsed: Double) -> Double {
        var time = elapsed
        for step in steps.reversed() {
            switch step {
            case .speed(let speed): time *= speed
            case .delay(let seconds): time = max(time - seconds, 0)
            case .complete, .repeating: break
            }
        }
        return time
    }

    func outer(_ inner: Double) -> Double { rate > 0 ? inner / rate : .infinity }

    func after(_ inner: Double) -> Double { rate > 0 ? delay + inner / rate : .infinity }

    var repeated: (count: Double, reverses: Bool, inside: Retiming, outside: Retiming)? {
        guard let index = steps.lastIndex(where: { if case .repeating = $0 { return true } else { return false } }),
              case .repeating(let count, let reverses) = steps[index] else { return nil }
        return (count, reverses, Retiming(steps: Array(steps[..<index])).once, Retiming(steps: Array(steps[(index + 1)...])))
    }

    var once: Retiming { Retiming(steps: steps.filter { if case .repeating = $0 { return false } else { return true } }) }
}

struct BaseTrack {
    let ended: (Double) -> Double?
    let at: (Double) -> Double

    static func fluid(_ spring: Spring, distance: Double) -> BaseTrack {
        fluid(FluidTrack(spring, distance: distance))
    }

    static func fluid(_ track: FluidTrack) -> BaseTrack {
        BaseTrack(ended: { track.end(by: $0) }, at: { track.progress(at: $0) })
    }

    static func interpolating(_ held: InterpolatingSpring) -> BaseTrack {
        let length = held.settlingTime
        return BaseTrack(ended: { length <= $0 ? length : nil }, at: { held.progress(at: $0) })
    }

    static func lasting(_ length: Double, progress: @escaping (Double) -> Double) -> BaseTrack {
        BaseTrack(ended: { length <= $0 ? length : nil }, at: { progress($0 / length) })
    }
}

struct AnimationCourse {
    private let ended: (Double) -> Double?
    private let at: (Double) -> Double

    init(_ base: BaseTrack, retiming: Retiming) {
        guard let repeated = retiming.repeated else {
            ended = { elapsed in base.ended(retiming.inner(at: elapsed)).map { retiming.after($0) } }
            at = { base.at(retiming.inner(at: $0)) }
            return
        }
        let (count, reverses, outside) = (repeated.count, repeated.reverses, repeated.outside)
        let pass = AnimationCourse(base, retiming: repeated.inside)
        func value(_ seconds: Double) -> Double {
            guard let length = pass.ended(seconds) else { return pass.at(seconds) }
            guard length > 0 else { return 1 }
            let passes = seconds / length
            let whole = passes.rounded(.down)
            let into = pass.at((passes - whole) * length)
            return reverses && whole.truncatingRemainder(dividingBy: 2) != 0 ? 1 - into : into
        }
        func total(_ seconds: Double) -> Double? {
            guard let length = pass.ended(seconds), count.isFinite, seconds >= count * length else { return nil }
            return count * length
        }
        ended = { elapsed in total(outside.inner(at: elapsed)).map { outside.after($0) } }
        at = { value(outside.inner(at: $0)) }
    }

    var length: Double? { ended(.infinity) }

    func position(elapsed: Double) -> (value: Double, done: Bool) {
        guard elapsed >= 0 else { return (0, false) }
        if ended(elapsed) != nil { return (1, true) }
        return (at(elapsed), false)
    }
}

final class FluidTrack {
    static let step = 1.0 / 300
    private static let highestFrequency = 0.5.squareRoot() / step
    struct Release {
        var remainderSquared: Double
        var crossed: Double
        var speedSquared: Double
    }

    private let stiffness: Double
    private let damping: Double
    private let size: Double
    private let release: Release?
    private var positions = [0.0]
    private var speeds = [0.0]
    private var kicks = [0.0]
    private var kickSpeeds = [1.0]
    private var tested = 0
    private var ended: Int?

    init(_ spring: Spring, distance: Double, release: Release? = nil) {
        let response = spring.response
        let frequency = response > 0 ? min(2 * Double.pi / response, FluidTrack.highestFrequency) : (response <= 0 ? FluidTrack.highestFrequency : .nan)
        stiffness = frequency * frequency
        damping = 2 * spring.dampingRatio * frequency
        size = abs(distance)
        self.release = release
    }

    private func reach(_ index: Int) {
        while positions.count <= index {
            let speed = speeds[speeds.count - 1] + FluidTrack.step * (stiffness * (1 - positions[positions.count - 1]) - damping * speeds[speeds.count - 1])
            speeds.append(speed)
            positions.append(positions[positions.count - 1] + FluidTrack.step * speed)
            let kickSpeed = kickSpeeds[kickSpeeds.count - 1] + FluidTrack.step * (-stiffness * kicks[kicks.count - 1] - damping * kickSpeeds[kickSpeeds.count - 1])
            kickSpeeds.append(kickSpeed)
            kicks.append(kicks[kicks.count - 1] + FluidTrack.step * kickSpeed)
        }
    }

    private func index(at time: Double) -> Int {
        time > 0 ? Int((time / FluidTrack.step).rounded(.up)) - 1 : 0
    }

    func progress(at time: Double) -> Double {
        guard time > 0 else { return 0 }
        let index = index(at: time)
        reach(index)
        return positions[index]
    }

    func remainders(at time: Double) -> (way: Double, speed: Double) {
        let index = index(at: time)
        reach(index)
        return (1 - positions[index], kicks[index])
    }

    func rates(at time: Double) -> (way: Double, speed: Double) {
        let index = index(at: time)
        reach(index)
        return (-speeds[index], kickSpeeds[index])
    }

    func end(by time: Double) -> Double? {
        if let n = ended { return Double(n) * FluidTrack.step <= time ? Double(n) * FluidTrack.step : nil }
        while Double(tested) * FluidTrack.step <= time {
            let n = tested
            reach(n + 1)
            let left = 1 - positions[n]
            let acceleration = stiffness * left - damping * speeds[n]
            if positions[n].isNaN || isAtRest(step: n, way: left, acceleration: acceleration) {
                ended = n
                return Double(n) * FluidTrack.step
            }
            tested += 1
        }
        return nil
    }

    private func isAtRest(step n: Int, way left: Double, acceleration: Double) -> Bool {
        guard let release else {
            return abs(left) < 0.01 && abs(acceleration) * size < 0.06 && abs(speeds[n] + speeds[n + 1]) / 2 * size < 0.06
        }
        func length(_ way: Double, _ speed: Double) -> Double {
            (way * way * release.remainderSquared + 2 * way * speed * release.crossed + speed * speed * release.speedSquared).squareRoot()
        }
        let kickAcceleration = -stiffness * kicks[n] - damping * kickSpeeds[n]
        return length(left, kicks[n]) < 0.01 * size
            && length(-acceleration, kickAcceleration) < 0.06
            && length(-(speeds[n] + speeds[n + 1]) / 2, (kickSpeeds[n] + kickSpeeds[n + 1]) / 2) < 0.06
    }
}

struct InterpolatingSpring: Hashable {
    var mass: Double
    var stiffness: Double
    var damping: Double
    var initialVelocity: Double

    init(mass: Double, stiffness: Double, damping: Double, initialVelocity: Double = 0) {
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
        self.initialVelocity = initialVelocity
    }

    init(_ spring: Spring, initialVelocity: Double = 0) {
        let fluid = spring.asFluid
        self.init(response: fluid.response, fraction: fluid.dampingRatio, initialVelocity: initialVelocity)
    }

    init(duration: Double, bounce: Double, initialVelocity: Double = 0) {
        self.init(response: duration, fraction: Spring(duration: duration, bounce: bounce).dampingRatio, initialVelocity: initialVelocity)
    }

    private init(response: Double, fraction: Double, initialVelocity: Double) {
        let frequency = 2 * Double.pi / response
        self.init(mass: 1, stiffness: frequency * frequency, damping: 2 * frequency * fraction, initialVelocity: initialVelocity)
    }

    private var solvedDamping: Double {
        let critical = 2 * (mass * stiffness).squareRoot()
        return damping.isNaN ? critical : min(damping, critical)
    }

    var spring: Spring { Spring(mass: mass, stiffness: stiffness, damping: solvedDamping) }

    func progress(at time: Double) -> Double {
        1 - spring.remaining(initialVelocity: initialVelocity, time: time)
    }

    var settlingTime: Double {
        guard mass > 0, mass.isFinite, stiffness > 0, stiffness.isFinite, initialVelocity.isFinite else { return 0 }
        let damping = solvedDamping
        guard damping >= 0 else { return 0 }
        guard damping > 0 else { return .infinity }
        if damping < 2 * (mass * stiffness).squareRoot() {
            let decay = damping / (2 * mass)
            let damped = (stiffness / mass - decay * decay).squareRoot()
            return log(1000 * (1 + abs(decay - initialVelocity) / damped)) / decay
        }
        let omega = (stiffness / mass).squareRoot()
        var time = 0.0
        for _ in 0..<InterpolatingSpring.horizon {
            time += 0.1
            if abs((1 + (omega - initialVelocity) * time) * exp(-omega * time)) < 0.001 { return time }
        }
        return 0
    }
    private static let horizon = 1012
}
