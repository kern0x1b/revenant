import SwiftUI
typealias Mine = Spring
typealias Apple = SwiftUI.Spring
var worst = 0.0
var count = 0
func note(_ what: String, _ mine: Double, _ apple: Double) {
    count += 1
    let d = abs(mine - apple)
    if d > worst { worst = d }
    if d > 1e-9 { print("DIFF", what, mine, apple) }
}
let forms: [(Double, Double)] = [(0.5, 0), (0.5, 0.3), (1, -0.2), (0.3, 0.9), (2, -0.7), (0.15, 0.15)]
for (duration, bounce) in forms {
    let m = Mine(duration: duration, bounce: bounce), a = Apple(duration: duration, bounce: bounce)
    for v0 in [0.0, 2.0, -3.0, 17.5] {
        for t in [0.0, 0.01, 0.1, 0.5, 1.3] {
            note("value \(duration) \(bounce) v0=\(v0) t=\(t)", m.value(target: 1.0, initialVelocity: v0, time: t), a.value(target: 1.0, initialVelocity: v0, time: t))
            note("velocity \(duration) \(bounce) v0=\(v0) t=\(t)", m.velocity(target: 1.0, initialVelocity: v0, time: t), a.velocity(target: 1.0, initialVelocity: v0, time: t))
            let tm = AnimatablePair(2.5, -1.5), vm = AnimatablePair(v0, 1 - v0)
            let rm = m.value(target: tm, initialVelocity: vm, time: t), ra = a.value(target: tm, initialVelocity: vm, time: t)
            note("pair.first", rm.first, ra.first); note("pair.second", rm.second, ra.second)
            let fm = m.velocity(fromValue: CGPoint(x: 0.2, y: 1), toValue: CGPoint(x: 1, y: 0), initialVelocity: CGPoint(x: v0, y: 1), time: t), fa = a.velocity(fromValue: CGPoint(x: 0.2, y: 1), toValue: CGPoint(x: 1, y: 0), initialVelocity: CGPoint(x: v0, y: 1), time: t)
            note("fromTo.x", Double(fm.x), Double(fa.x)); note("fromTo.y", Double(fm.y), Double(fa.y))
            let qm = m.velocity(target: tm, initialVelocity: vm, time: t), qa = a.velocity(target: tm, initialVelocity: vm, time: t)
            note("pairvel.first", qm.first, qa.first); note("pairvel.second", qm.second, qa.second)
        }
    }
    for (v, s) in [(0.0, 0.0), (0.25, 1.5), (0.25, -1.5), (1.4, 3.0)] {
        for dt in [1.0 / 60, 0.1, 0.4] {
            var vm = v, sm = s, va = v, sa = s
            m.update(value: &vm, velocity: &sm, target: 1, deltaTime: dt)
            a.update(value: &va, velocity: &sa, target: 1, deltaTime: dt)
            note("update value", vm, va); note("update velocity", sm, sa)
        }
    }
    var vm = 0.0, sm = 0.0, va = 0.0, sa = 0.0
    for _ in 0..<6 { m.update(value: &vm, velocity: &sm, target: 1, deltaTime: 1.0 / 60); a.update(value: &va, velocity: &sa, target: 1, deltaTime: 1.0 / 60) }
    note("six frames value", vm, va); note("six frames velocity", sm, sa)
}
var pairs = 0
func same(_ what: String, _ mine: Bool, _ apple: Bool) {
    pairs += 1
    if mine != apple { print("DIFF equal", what, "mine", mine, "apple", apple) }
}
for r in [0.1, 0.15, 0.25, 0.3, 0.5, 0.75, 1, 1.5, 2, 3] {
    for z in [0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7, 0.75, 0.8, 0.825, 0.85, 0.9, 0.95, 1.0] {
        same("response \(r) ratio \(z) / duration bounce", Mine(response: r, dampingRatio: z) == Mine(duration: r, bounce: 1 - z),
             Apple(response: r, dampingRatio: z) == Apple(duration: r, bounce: 1 - z))
        same("hash response \(r) ratio \(z) / duration bounce", Mine(response: r, dampingRatio: z).hashValue == Mine(duration: r, bounce: 1 - z).hashValue,
             Apple(response: r, dampingRatio: z).hashValue == Apple(duration: r, bounce: 1 - z).hashValue)
    }
    for b in [-0.9, -0.7, -0.5, -0.3, -0.2, -0.1] {
        same("over-damped \(r) bounce \(b)", Mine(response: r, dampingRatio: 1 / (1 + b)) == Mine(duration: r, bounce: b),
             Apple(response: r, dampingRatio: 1 / (1 + b)) == Apple(duration: r, bounce: b))
    }
    same("another response", Mine(duration: r, bounce: 0.2) == Mine(duration: r * 1.01, bounce: 0.2), Apple(duration: r, bounce: 0.2) == Apple(duration: r * 1.01, bounce: 0.2))
}
for m in [0.5, 1.0, 2.0, 3.3] {
    for k in [10.0, 50, 100, 157.91367041742973, 400] {
        for c in [1.0, 5, 10, 25.132741228718345, 40, 100, 200] {
            let mine = Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), apple = Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true)
            same("system \(m) \(k) \(c) with itself", mine == Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), apple == Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true))
            same("system \(m) \(k) \(c) with a response spring", mine == Mine(response: 2 * Double.pi * (m / k).squareRoot(), dampingRatio: c / (2 * (m * k).squareRoot())),
                 apple == Apple(response: 2 * Double.pi * (m / k).squareRoot(), dampingRatio: c / (2 * (m * k).squareRoot())))
            same("system \(m) \(k) \(c) with the same at twice the mass", mine == Mine(mass: 2 * m, stiffness: 2 * k, damping: 2 * c, allowOverDamping: true),
                 apple == Apple(mass: 2 * m, stiffness: 2 * k, damping: 2 * c, allowOverDamping: true))
        }
    }
}
same("critical system and a duration", Mine(mass: 1, stiffness: 157.91367041742973, damping: 25.132741228718345) == Mine(duration: 0.5, bounce: 0),
     Apple(mass: 1, stiffness: 157.91367041742973, damping: 25.132741228718345) == Apple(duration: 0.5, bounce: 0))
print("compared", pairs, "pairs of springs for equality")

var made: [(Mine, Apple)] = []
let grid = [0.1, 0.15, 0.25, 0.3, 0.5, 0.75, 1, 1.5, 2, 3], ratios = [0.1, 0.2, 0.3, 0.5, 0.7, 0.825, 0.85, 0.9, 1.0, 1.25, 1.5, 2]
for r in grid { for z in ratios { made.append((Mine(response: r, dampingRatio: z), Apple(response: r, dampingRatio: z))) } }
for r in [0.15, 0.5, 1] { for b in [-0.7, -0.2, 0, 0.15, 0.3, 0.9] { made.append((Mine(duration: r, bounce: b), Apple(duration: r, bounce: b))) } }
for m in [0.5, 1.0, 2.0] { for k in [10.0, 100, 400] { for c in [1.0, 10, 40, 100] { made.append((Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true))) } } }
var animations = 0
for (mine, apple) in made {
    for r in grid { for z in ratios {
        animations += 1
        let direct = Mine(response: r, dampingRatio: z)
        same("animation of a spring and of response \(r) fraction \(z)", mine.asFluid.heldNumbers == direct.heldNumbers, Animation.spring(apple) == Animation.spring(response: r, dampingFraction: z))
    } }
}
for (mine, apple) in made {
    for (other, otherApple) in made.prefix(150) {
        animations += 1
        same("animation of a spring and of another spring", mine.asFluid.heldNumbers == other.asFluid.heldNumbers, Animation.spring(apple) == Animation.spring(otherApple))
    }
}
print("compared", animations, "pairs of animations for equality")

func makeContext<V: VectorArithmetic>(_: V.Type = Double.self) -> AnimationContext<V> {
    let memory = UnsafeMutableRawPointer.allocate(byteCount: 32, alignment: 8)
    memory.initializeMemory(as: UInt8.self, repeating: 0, count: 32)
    memory.storeBytes(of: AnimationState<V>(), toByteOffset: 0, as: AnimationState<V>.self)
    memory.storeBytes(of: EnvironmentValues(), toByteOffset: 8, as: EnvironmentValues.self)
    return memory.load(as: AnimationContext<V>.self)
}
func heldBy(_ animation: Animation) -> [Double]? {
    let fields = Mirror(reflecting: Mirror(reflecting: animation).children.first!.value).children
    guard fields.contains(where: { $0.label == "stiffness" }) else { return nil }
    let speed = Mirror(reflecting: fields.first { $0.label == "initialVelocity" }!.value).children.first!.value as! Double
    return ["mass", "stiffness", "damping"].map { name in fields.first { $0.label == name }!.value as! Double } + [speed]
}
var interpolating: [(String, InterpolatingSpring, Animation)] = []
func hold(_ spring: Mine, _ velocity: Double) -> InterpolatingSpring { InterpolatingSpring(spring, initialVelocity: velocity) }
for velocity in [0.0, 1.5, -2] {
    for (mine, apple) in made { interpolating.append(("spring v \(velocity)", hold(mine, velocity), Animation.interpolatingSpring(apple, initialVelocity: velocity))) }
    for r in [0.15, 0.5, 1] { for b in [-0.9, -0.5, -0.2, 0, 0.15, 0.3, 0.4, 0.9] {
        interpolating.append(("duration \(r) bounce \(b) v \(velocity)", InterpolatingSpring(duration: r, bounce: b, initialVelocity: velocity), Animation.interpolatingSpring(duration: r, bounce: b, initialVelocity: velocity)))
    } }
    for m in [0.5, 1.0, 2.0] { for k in [10.0, 50, 100, 400] { for c in [1.0, 5, 10, 40, 100, 3 * (m * k).squareRoot(), 2 * (m * k).squareRoot()] {
        interpolating.append(("mass \(m) stiffness \(k) damping \(c) v \(velocity)", InterpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: velocity),
                              Animation.interpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: velocity)))
    } } }
}
var held = 0
for (name, mine, apple) in interpolating {
    held += 1
    same("held numbers of \(name)", heldBy(apple) == [mine.mass, mine.stiffness, mine.damping, mine.initialVelocity], true)
    same("interpolating \(name) is not the animation of a spring", false, apple == Animation.spring(response: 0.5, dampingFraction: 0.7) || apple == Animation.spring(duration: 0.5, bounce: 0.3))
}
print("compared", held, "interpolating springs' held numbers")
var interpolatingPairs = 0
for (_, mine, apple) in interpolating {
    for (_, other, otherApple) in interpolating {
        interpolatingPairs += 1
        same("interpolating springs equal", mine == other, apple == otherApple)
        if apple == otherApple { same("interpolating springs hash alike", true, apple.hashValue == otherApple.hashValue) }
    }
}
print("compared", interpolatingPairs, "pairs of interpolating springs for equality")
var solved = 0
for (name, mine, apple) in interpolating {
    var context = makeContext()
    for t in [0.0, 0.01, 0.05, 0.1, 0.2, 0.4, 0.8, 1.5] {
        for distance in [1.0, 3.0, -2.0] {
            let got = apple.animate(value: distance, time: t, context: &context)
            solved += 1
            same("interpolating \(name) answers at \(t) as long as it has not settled", got == nil, t >= mine.settlingTime)
            if let got { note("interpolating \(name) at \(t) over \(distance)", distance * mine.progress(at: t), got) }
        }
    }
}
print("compared", solved, "values of interpolating springs")
var settled = 0
func compareEnds(_ name: String, _ mine: InterpolatingSpring, _ apple: Animation) {
    settled += 1
    let end = mine.settlingTime
    var context = makeContext()
    if end == 0 { same("\(name) is over at once", apple.animate(value: 1, time: 0, context: &context) == nil, true); return }
    if end.isFinite {
        let before = apple.animate(value: 1, time: end - 1e-9 * max(1, end), context: &context)
        same("\(name) answers just before it settles, at \(end)", before != nil, true)
        if let before { note("\(name) just before its end", mine.progress(at: end - 1e-9 * max(1, end)), before) }
        same("\(name) answers nothing just after it settles, at \(end)", apple.animate(value: 1, time: end + 1e-9 * max(1, end), context: &context) == nil, true)
    } else {
        same("\(name) answers for ever", apple.animate(value: 1, time: 1e6, context: &context) != nil, true)
    }
}
for (name, mine, apple) in interpolating { compareEnds(name, mine, apple) }
for m in [0.3, 1.0, 2.5] { for k in [20.0, 100.0, 700.0] { for ratio in [0.01, 0.1, 0.5, 0.9, 0.999, 0.9999999, 1, 1.0000001, 1.5, 4] { for v in [0.0, 1.0, -3.0, 10.0, 50.0, 200.0, -40.0] {
    let c = ratio * 2 * (m * k).squareRoot()
    compareEnds("sweep mass \(m) stiffness \(k) damping \(c) v \(v)", InterpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: v), Animation.interpolatingSpring(mass: m, stiffness: k, damping: c, initialVelocity: v))
} } } }
for (m, k, c) in [(1.0, 100.0, 0.0), (1.0, 100.0, 1e-6), (1.0, 100.0, -2.0), (0.0, 100.0, 10.0), (1.0, 0.0, 10.0), (-1.0, 100.0, 10.0), (1.0, -100.0, 10.0), (1.0, 100.0, Double.nan), (1.0, 100.0, Double.infinity), (Double.nan, 100.0, 10.0), (1.0, Double.nan, 10.0), (Double.infinity, 100.0, 10.0), (1.0, Double.infinity, 10.0), (1.0, 1e-4, 0.01), (1e-4, 100.0, 1e-3)] {
    compareEnds("odd mass \(m) stiffness \(k) damping \(c)", InterpolatingSpring(mass: m, stiffness: k, damping: c), Animation.interpolatingSpring(mass: m, stiffness: k, damping: c))
}
print("compared", settled, "ends of interpolating springs")

var pairsAsked = 0
for (name, mine, apple) in interpolating where name.contains("v 1.5") || name.contains("v -2") {
    for (x, y) in [(3.0, 4.0), (-0.3, 0.4), (60.0, -80.0), (0.0, 7.0)] {
        var context = makeContext(AnimatablePair<Double, Double>.self)
        let end = mine.settlingTime
        for t in [0.0, 0.03, 0.1, 0.25, 0.6, 1.2, 2.0, 5.0] {
            let got = apple.animate(value: AnimatablePair(x, y), time: t, context: &context)
            pairsAsked += 1
            same("pair \(name) \(x) \(y) at \(t) over when the scalar is", got == nil, t >= end)
            if let got { note("pair.first", mine.progress(at: t) * x, got.first); note("pair.second", mine.progress(at: t) * y, got.second) }
        }
    }
}
print("asked Apple's interpolating springs", pairsAsked, "times of a pair")

func answersOf(_ animation: Animation, distance: Double, at times: [Double]) -> [Double?] {
    var context = makeContext()
    return times.map { animation.animate(value: distance, time: $0, context: &context) }
}
var blended = 0
let blendTimes = (0..<240).map { (Double($0) + 0.5) / 300 }
for (r, z) in [(0.5, 0.825), (0.15, 0.86), (1.0, 0.5), (0.3, 1.0), (0.4, 1.4)] {
    let plain = answersOf(Animation.spring(response: r, dampingFraction: z), distance: 1, at: blendTimes)
    for blend in [0.1, 0.25, 1.0] {
        blended += 1
        same("blend \(blend) of response \(r) fraction \(z) moves nothing in time", true, answersOf(Animation.spring(response: r, dampingFraction: z, blendDuration: blend), distance: 1, at: blendTimes) == plain)
    }
}
print("compared", blended, "blends against none")

var fluidAsked = 0, fluidEnds = 0
func compareFluid(_ name: String, _ mine: Mine, _ apple: Animation, distance: Double, limit: Int = 3000) {
    let track = FluidTrack(mine, distance: distance), end = track.end(by: Double(limit) / 300) ?? .infinity
    var context = makeContext()
    for k in 0..<limit {
        let t = (Double(k) + 0.5) / 300
        let got = apple.animate(value: distance, time: t, context: &context)
        let expected: Double? = t > end ? nil : distance * track.progress(at: t)
        fluidAsked += 1
        if (got == nil) != (expected == nil) { print("DIFF fluid end", name, "distance", distance, "step", k, "apple", got as Any, "mine", expected as Any); return }
        guard let got, let expected else { fluidEnds += 1; return }
        let scale = max(1, abs(got))
        note("fluid \(name) distance \(distance) step \(k)", expected / scale, got / scale)
    }
}
for r in [0.1, 0.15, 0.25, 0.3, 0.5, 0.75, 1, 1.5, 2, 3] {
    for z in [0.1, 0.2, 0.3, 0.5, 0.7, 0.825, 0.9, 1, 1.25, 1.5, 2] {
        for d in [0.01, 0.3, 1, 3, 17, 100, 1000] {
            compareFluid("response \(r) fraction \(z)", Mine(response: r, dampingRatio: z), Animation.spring(response: r, dampingFraction: z), distance: d)
        }
    }
}
for (r, b) in [(0.5, 0.0), (0.5, 0.15), (0.5, 0.3), (0.15, 0.15), (0.35, -0.4)] {
    for d in [0.5, 4, 60] { compareFluid("duration \(r) bounce \(b)", Mine(duration: r, bounce: b), Animation.spring(duration: r, bounce: b), distance: d) }
}
for (r, z) in [(0.0, 0.8), (-1.0, 0.8), (0.0001, 0.8), (0.02, 0.5), (0.0296, 0.5), (0.03, 0.5), (0.5, 0.0), (0.5, 0.001), (0.5, -0.5), (0.5, 50), (0.5, Double.nan), (Double.nan, 0.5)] {
    compareFluid("odd response \(r) fraction \(z)", Mine(response: r, dampingRatio: z), Animation.spring(response: r, dampingFraction: z), distance: 1)
}
print("asked Apple's fluid spring", fluidAsked, "times; it ended", fluidEnds, "of its runs")
var vectorAsked = 0
for (r, z) in [(0.5, 0.825), (0.3, 0.4), (1.0, 1.0), (0.4, 1.5)] {
    for (x, y) in [(3.0, 4.0), (-0.3, 0.4), (60.0, -80.0), (0.003, 0.004)] {
        let track = FluidTrack(Mine(response: r, dampingRatio: z), distance: (x * x + y * y).squareRoot()), end = track.end(by: 10) ?? .infinity
        var context = makeContext(AnimatablePair<Double, Double>.self)
        let animation = Animation.spring(response: r, dampingFraction: z)
        for k in 0..<3000 {
            let t = (Double(k) + 0.5) / 300
            let got = animation.animate(value: AnimatablePair(x, y), time: t, context: &context)
            vectorAsked += 1
            same("vector \(r) \(z) \(x) \(y) step \(k) ends with its length", got == nil, t > end)
            guard let got else { break }
            note("vector.first", track.progress(at: t) * x, got.first); note("vector.second", track.progress(at: t) * y, got.second)
        }
    }
}
print("asked Apple's fluid spring", vectorAsked, "times of a pair")
var longAsked = 0
for z in [1e-3, 1e-4, 1e-5] {
    let track = FluidTrack(Mine(response: 0.5, dampingRatio: z), distance: 1), apple = Animation.spring(response: 0.5, dampingFraction: z)
    var context = makeContext()
    var k = 0, first: Int?
    while first == nil && k < 20_000_000 {
        if apple.animate(value: 1, time: (Double(k) + 0.5) / 300, context: &context) == nil { first = k }
        k += 1
    }
    longAsked += k
    let mineEnd = track.end(by: 20_000_000.0 / 300).map { Int(($0 * 300).rounded()) }
    same("response 0.5 ratio \(z) answers until step \(String(describing: mineEnd))", first == mineEnd, true)
}
print("asked Apple's fluid spring", longAsked, "times of springs that rest after hours")

enum Retime { case speed(Double), delay(Double), complete(Double), `repeat`(Int, Bool), forever(Bool) }
func retime(_ animation: Animation, _ ops: [Retime]) -> Animation {
    ops.reduce(animation) { all, op in
        switch op {
        case .speed(let s): return all.speed(s)
        case .delay(let d): return all.delay(d)
        case .complete(let c): return all.logicallyComplete(after: c)
        case .repeat(let n, let reverses): return all.repeatCount(n, autoreverses: reverses)
        case .forever(let reverses): return all.repeatForever(autoreverses: reverses)
        }
    }
}
func retimed(_ retiming: Retiming, _ ops: [Retime]) -> Retiming {
    ops.reduce(retiming) { all, op in
        switch op {
        case .speed(let s): return all.speeding(by: s)
        case .delay(let d): return all.delaying(by: d)
        case .complete(let c): return all.completing(after: c)
        case .repeat(let n, let reverses): return all.repeating(count: Double(max(n, 1)), reverses: reverses)
        case .forever(let reverses): return all.repeating(count: .infinity, reverses: reverses)
        }
    }
}
var retimedAsked = 0
func compareRetimed(_ name: String, _ apple: Animation, _ ops: [Retime], distance: Double, natural: Double, base: BaseTrack) {
    let retiming = retimed(Retiming(), ops), mine = AnimationCourse(base, retiming: retiming)
    if mine.position(elapsed: 0).done { return }
    var context = makeContext()
    let step = 1 / (300 * max(retiming.rate, 1))
    var length = Double.infinity
    var probe = 0.0
    while probe < 1000 { if mine.position(elapsed: probe).done { length = probe; break }; probe += 0.05 }
    let limit = length.isFinite ? Int(length / step) + 80 : 600
    for j in 0..<limit {
        let t = (Double(j) + 0.5) * step
        let got = apple.animate(value: distance, time: t, context: &context)
        let (fraction, done) = mine.position(elapsed: t)
        let expected: Double? = done ? nil : distance * fraction
        retimedAsked += 1
        if (got == nil) != (expected == nil) { print("DIFF retimed end", name, ops, "step", j, "apple", got as Any, "mine", expected as Any); return }
        if let got, let expected { note("retimed \(name) \(ops) step \(j)", expected, got) }
        if got != nil { same("retimed \(name) \(ops) is logically complete from its moment, step \(j)", context.isLogicallyComplete, t >= retiming.logicalMoment(naturally: natural)) }
        if got == nil { return }
    }
}
let orders: [[Retime]] = [[], [.speed(2)], [.speed(0.5)], [.delay(1)], [.delay(-0.25)], [.delay(0.1)], [.speed(2), .delay(1)], [.delay(1), .speed(2)], [.speed(2), .speed(2)],
                          [.delay(1), .delay(1)], [.delay(1), .speed(0.5), .delay(0.5)], [.speed(0.5), .delay(1), .speed(2)], [.speed(3), .delay(-0.2)], [.speed(0)], [.delay(0.4), .speed(0)],
                          [.complete(0.2)], [.complete(0.2), .speed(2)], [.speed(2), .complete(0.2)], [.complete(0.2), .delay(1)], [.delay(1), .complete(0.2)], [.speed(2), .delay(1), .complete(0.9), .speed(0.5)]]
let fluidSprings = [(0.5, 0.825), (0.15, 0.86), (0.35, 0.4)]
for (r, z) in fluidSprings {
    let spring = Mine(response: r, dampingRatio: z)
    for d in [1.0, 30.0] {
        for ops in orders + [[.speed(-1)], [.delay(1), .speed(-1)]] {
            compareRetimed("fluid \(r) \(z) distance \(d)", retime(Animation.spring(response: r, dampingFraction: z), ops), ops, distance: d, natural: r, base: .fluid(spring, distance: d))
        }
    }
}
for (name, held, apple) in [("mass 1 stiffness 100 damping 10", InterpolatingSpring(mass: 1, stiffness: 100, damping: 10), Animation.interpolatingSpring(mass: 1, stiffness: 100, damping: 10)),
                            ("critical", InterpolatingSpring(mass: 1, stiffness: 100, damping: 50), Animation.interpolatingSpring(mass: 1, stiffness: 100, damping: 50)),
                            ("speed 3", InterpolatingSpring(mass: 1, stiffness: 100, damping: 10, initialVelocity: 3), Animation.interpolatingSpring(mass: 1, stiffness: 100, damping: 10, initialVelocity: 3)),
                            ("spring", InterpolatingSpring(Mine(response: 0.5, dampingRatio: 0.7)), Animation.interpolatingSpring(Apple(response: 0.5, dampingRatio: 0.7)))] {
    for ops in orders {
        compareRetimed("interpolating \(name)", retime(apple, ops), ops, distance: 2, natural: held.spring.response, base: .interpolating(held))
    }
}
print("asked Apple", retimedAsked, "times of springs that were sped up, slowed down and delayed")

var repeatedAsked = 0
func compareRepeated(_ name: String, _ apple: Animation, _ ops: [Retime], base: BaseTrack, step: Double, until: Double) {
    let retiming = retimed(Retiming(), ops), mine = AnimationCourse(base, retiming: retiming)
    let passes = retiming.repeated.map { $0.count.isFinite ? Int($0.count) : Int(until) + 1 } ?? 1
    let drift = Double(passes + 1) * step
    var context = makeContext()
    var j = 0
    while Double(j) * step < until {
        let t = (Double(j) + 0.5) * step
        let got = apple.animate(value: 1, time: t, context: &context)
        repeatedAsked += 1
        if got == nil {
            same("repeated \(name) \(ops) is over by \(t) (the port's is at \(mine.position(elapsed: t + step).done))", mine.position(elapsed: t + step).done && !mine.position(elapsed: t - drift - step).done, true)
            return
        }
        if mine.position(elapsed: t - drift - step).done { print("DIFF repeated end", name, ops, "apple still answers at", t, "mine over from", t - drift - step); return }
        var low = Double.infinity, high = -Double.infinity, jumps = false, last: Double?, nearest = Double.infinity
        var u = max(t - drift, 0)
        while u <= t + step {
            let v = mine.position(elapsed: u).value
            low = min(low, v); high = max(high, v)
            if let last, abs(v - last) > 0.5 { jumps = true }
            last = v
            nearest = min(nearest, abs(v - got!))
            u += step / 8
        }
        let atPassEnd = (got! == 0 || got! == 1) && (jumps || nearest < step)
        if !atPassEnd && (got! < low - 1e-9 || got! > high + 1e-9) { print("DIFF repeated", name, ops, "at", t, "apple", got!, "mine between", low, high) }
        j += 1
    }
    if !(retiming.repeated.map { !$0.count.isFinite } ?? false) { print("DIFF repeated end", name, ops, "apple never ends in", until) }
}
let repeatedCases: [[Retime]] = [[.repeat(2, false)], [.repeat(3, false)], [.repeat(2, true)], [.repeat(3, true)], [.repeat(4, true)], [.repeat(1, false)], [.repeat(1, true)],
                                 [.forever(false)], [.forever(true)], [.speed(2), .repeat(2, false)], [.repeat(3, false), .speed(2)], [.speed(0.5), .repeat(2, true)], [.repeat(2, true), .speed(0.5)],
                                 [.delay(0.5), .repeat(2, false)], [.delay(0.5), .repeat(3, false)], [.delay(0.5), .repeat(2, true)], [.delay(0.5), .repeat(3, true)], [.repeat(2, true), .delay(0.5)], [.repeat(3, false), .delay(0.5)],
                                 [.speed(2), .delay(0.5), .repeat(2, true)], [.delay(0.5), .speed(2), .repeat(2, true)], [.delay(0.5), .repeat(2, true), .speed(2)], [.delay(1), .repeat(2, false), .delay(1)],
                                 [.speed(2), .repeat(2, true), .delay(0.5), .speed(0.5)]]
for ops in repeatedCases {
    for step in [0.01, 0.0037] {
        compareRepeated("curve", retime(Animation.linear(duration: 1), ops), ops, base: .lasting(1) { $0 }, step: step, until: 12)
        compareRepeated("fluid", retime(Animation.spring(response: 0.5, dampingFraction: 0.825), ops), ops, base: .fluid(Mine(response: 0.5, dampingRatio: 0.825), distance: 1), step: step, until: 12)
    }
}
print("asked Apple", repeatedAsked, "times of animations that repeat")
let equalityOps: [Retime] = [.speed(1), .speed(2), .delay(0), .delay(1), .complete(1)]
var equalitySequences: [[Retime]] = [[]]
for _ in 0..<3 { equalitySequences += equalitySequences.filter { $0.count == equalitySequences.map(\.count).max()! }.flatMap { sequence in equalityOps.map { sequence + [$0] } } }
for base in [Animation.linear(duration: 1), Animation.spring(response: 0.5, dampingFraction: 0.8)] {
    for first in equalitySequences {
        for second in equalitySequences {
            let equalMine = retimed(Retiming(), first) == retimed(Retiming(), second), equalApple = retime(base, first) == retime(base, second)
            same("retimed \(first) == \(second)", equalMine, equalApple)
            if equalApple { same("retimed \(first) hashes as \(second)", retimed(Retiming(), first).hashValue == retimed(Retiming(), second).hashValue, true) }
        }
    }
}
print("compared", equalitySequences.count * equalitySequences.count * 2, "pairs of retimed animations for equality")

nonisolated(unsafe) var customAsked: [Double] = []
struct Recording: CustomAnimation {
    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? { customAsked.append(time); return time >= 8 ? nil : value }
    func velocity<V: VectorArithmetic>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V? { value }
    func shouldMerge<V: VectorArithmetic>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool { true }
}
var customTimes = 0
let customGrid = [-2.0, -1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 4.0]
for ops in equalitySequences + [[.speed(-1)], [.delay(1), .speed(-1)], [.speed(-1), .delay(1)], [.speed(0.5)], [.speed(3), .delay(-0.2)], [.delay(-1)], [.repeat(2, false)], [.speed(2), .repeat(3, true)], [.delay(0.5), .repeat(2, false), .speed(2)]] {
    let apple = retime(Animation(Recording()), ops), mine = retimed(Retiming(), ops)
    var context = makeContext()
    for t in customGrid {
        customAsked = []
        _ = apple.animate(value: 1.0, time: t, context: &context)
        customTimes += 1
        if mine.repeated != nil && t > 1.9 { continue }
        let got = customAsked.first ?? .nan
        if abs(got - mine.baseTime(at: t)) > 1e-12 && !(got == 0 && mine.baseTime(at: t) == 0) { print("DIFF custom time", ops, "at", t, "apple", got, "mine", mine.baseTime(at: t)) }
    }
    let velocity = apple.velocity(value: 1.0, time: 0.5, context: makeContext())
    var other = makeContext()
    same("custom velocity under \(ops) is nothing once a call has been made", velocity == nil, mine.isRetimed)
    same("custom animation under \(ops) merges only when no call has been made", apple.shouldMerge(previous: .linear, value: 1.0, time: 0.5, context: &other), !mine.isRetimed)
}
print("asked Apple", customTimes, "times of a custom animation under calls")

var settlings = 0
func settle(_ what: String, _ mine: Double, _ apple: Double) {
    settlings += 1
    if mine == apple || (mine.isNaN && apple.isNaN) { return }
    if abs(mine - apple) > 1e-9 { print("DIFF settling", what, "mine", mine, "apple", apple) }
}
var sweptSprings: [(String, Mine, Apple)] = []
for (d, b) in [(0.5, 0.0), (0.5, 0.3), (1, -0.2), (0.3, 0.9), (2, -0.7), (0.15, 0.15), (0.5, 0.15), (0.25, 0.6), (0.4, 0.99), (0.4, -0.01), (3, 0.05)] {
    sweptSprings.append(("duration \(d) bounce \(b)", Mine(duration: d, bounce: b), Apple(duration: d, bounce: b)))
}
for (r, z) in [(0.5, 0.7), (0.3, 0.9999), (0.3, 1.0001), (1.0, 0.1), (0.1, 0.5), (2.0, 1.01), (0.5, 0.0), (0.5, 3)] {
    sweptSprings.append(("response \(r) ratio \(z)", Mine(response: r, dampingRatio: z), Apple(response: r, dampingRatio: z)))
}
for (m, k, c) in [(2.0, 100.0, 5.0), (1.0, 100.0, 40.0), (0.5, 20.0, 3.0), (1.0, 100.0, 20.0)] {
    sweptSprings.append(("mass \(m) stiffness \(k) damping \(c)", Mine(mass: m, stiffness: k, damping: c, allowOverDamping: true), Apple(mass: m, stiffness: k, damping: c, allowOverDamping: true)))
}
for (name, m, a) in sweptSprings {
    settle("\(name) property", m.settlingDuration, a.settlingDuration)
    for eps in [0.1, 0.01, 0.001, 1e-5] {
        for target in [0.2, 1.0, 5.0, 100.0, -2.0] {
            for v0 in [0.0, 2.0, -3.0, 20.0, -50.0, 500.0] {
                settle("\(name) eps \(eps) target \(target) v0 \(v0)", m.settlingDuration(target: target, initialVelocity: v0, epsilon: eps), a.settlingDuration(target: target, initialVelocity: v0, epsilon: eps))
            }
        }
        for (tp, vp) in [(AnimatablePair(3.0, 4.0), AnimatablePair(1.0, -2.0)), (AnimatablePair(3.0, 4.0), AnimatablePair(0.0, 0.0)), (AnimatablePair(-0.3, 0.4), AnimatablePair(50.0, 20.0)), (AnimatablePair(0.0, 0.0), AnimatablePair(5.0, 1.0))] {
            settle("\(name) pair \(tp) \(vp) eps \(eps)", m.settlingDuration(target: tp, initialVelocity: vp, epsilon: eps), a.settlingDuration(target: tp, initialVelocity: vp, epsilon: eps))
        }
        for (from, to, iv) in [(CGPoint(x: 0.5, y: 1), CGPoint(x: 4, y: -2), CGPoint(x: 1, y: 2)), (CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 50), CGPoint(x: -300, y: 0)), (CGPoint(x: 1, y: 1), CGPoint(x: 1, y: 1), CGPoint(x: 4, y: 3))] {
            settle("\(name) point \(from) \(to) \(iv) eps \(eps)", m.settlingDuration(fromValue: from, toValue: to, initialVelocity: iv, epsilon: eps), a.settlingDuration(fromValue: from, toValue: to, initialVelocity: iv, epsilon: eps))
        }
    }
}
for z in [0.0, -0.2, 1.0, 2.0, 0.5, Double.nan] {
    let m = Mine(response: 0.5, dampingRatio: z), a = Apple(response: 0.5, dampingRatio: z)
    for (target, v0, eps) in [(1.0, 0.0, 0.001), (1e-4, 0.0, 0.001), (0.0, 0.0, 0.001), (0.0, 5.0, 0.001), (1.0, 0.0, 0.0), (1.0, 0.0, -1.0), (1.0, 0.0, 1e-300), (1.0, 0.0, Double.nan), (Double.nan, 0.0, 0.001), (1.0, Double.nan, 0.001)] {
        settle("response 0.5 ratio \(z) target \(target) v0 \(v0) eps \(eps)", m.settlingDuration(target: target, initialVelocity: v0, epsilon: eps), a.settlingDuration(target: target, initialVelocity: v0, epsilon: eps))
    }
}
for r in [0.0, -1.0, Double.nan, 1e-9, 1e5] {
    settle("response \(r)", Mine(response: r, dampingRatio: 0.5).settlingDuration, Apple(response: r, dampingRatio: 0.5).settlingDuration)
    settle("response \(r) with a speed", Mine(response: r, dampingRatio: 0.5).settlingDuration(target: 1.0, initialVelocity: 3, epsilon: 0.001), Apple(response: r, dampingRatio: 0.5).settlingDuration(target: 1.0, initialVelocity: 3, epsilon: 0.001))
}
for z in [0.3, 0.5, 0.7, 0.9, 1.0, 1.3, 2.0] {
    for t in [0.2, 0.5, 1.0, 2.5] {
        for eps in [0.01, 0.001, 1e-5] {
            let mine = Mine(settlingDuration: t, dampingRatio: z, epsilon: eps).response, apple = Apple(settlingDuration: t, dampingRatio: z, epsilon: eps).response
            settlings += 1
            if abs(mine - apple) > 5e-5 * apple { print("DIFF settling response for a settling of \(t) at ratio \(z) epsilon \(eps) mine", mine, "apple", apple) }
        }
    }
}
for (t, z, eps) in [(1e-9, 0.5, 0.001), (0.005, 0.5, 0.001), (0.01, 0.5, 0.001), (100.0, 0.5, 0.001), (1e4, 0.5, 0.001), (0.0, 0.5, 0.001), (-1.0, 0.5, 0.001), (Double.nan, 0.5, 0.001),
                    (1.0, 0.0, 0.001), (1.0, -0.5, 0.001), (1.0, Double.nan, 0.001), (1.0, 1e-6, 0.001), (1.0, 0.001, 0.001), (1.0, 1.0000001, 0.001), (1.0, 3.0, 0.1), (100.0, 1.0, 0.001), (0.001, 2.0, 0.001)] {
    let mine = Mine(settlingDuration: t, dampingRatio: z, epsilon: eps), apple = Apple(settlingDuration: t, dampingRatio: z, epsilon: eps)
    settlings += 1
    let (m, a) = ((mine.response, mine.dampingRatio), (apple.response, apple.dampingRatio))
    if !((m.0.isNaN && a.0.isNaN) || abs(m.0 - a.0) <= 5e-5 * abs(a.0)) || !((m.1.isNaN && a.1.isNaN) || abs(m.1 - a.1) <= 1e-12) { print("DIFF settling response for a settling of \(t) at ratio \(z) epsilon \(eps) mine", m, "apple", a) }
}
func settleCap(_ what: String, _ ratio: Double, _ target: Double, _ eps: Double, _ v0: Double) {
    var lo = 1.0, hi = 400.0
    for _ in 0..<70 {
        let mid = (lo + hi) / 2
        if Apple(response: mid, dampingRatio: ratio).settlingDuration(target: target, initialVelocity: v0, epsilon: eps) == 0 { hi = mid } else { lo = mid }
    }
    for response in [lo * (1 - 1e-9), hi * (1 + 1e-9), lo * 0.999, hi * 1.001, 150, 300] {
        settle("\(what) response \(response)", Mine(response: response, dampingRatio: ratio).settlingDuration(target: target, initialVelocity: v0, epsilon: eps),
               Apple(response: response, dampingRatio: ratio).settlingDuration(target: target, initialVelocity: v0, epsilon: eps))
    }
    if Mine(response: lo * (1 - 1e-9), dampingRatio: ratio).settlingDuration(target: target, initialVelocity: v0, epsilon: eps) < 101 { print("DIFF settling cap", what, "answered under 101 s at", lo) }
}
for (z, target, eps, v0) in [(1.0, 1.0, 0.001, 0.0), (2.0, 1.0, 0.001, 0.0), (1.0, 5.0, 0.01, 0.0), (1.0, 0.3, 0.001, 3.0), (1.5, 100.0, 1e-4, -4.0)] { settleCap("ratio \(z) target \(target) epsilon \(eps) speed \(v0)", z, target, eps, v0) }
func passes(_ apple: Animation) -> Bool {
    var context = makeContext()
    return apple.animate(value: 1, time: 0, context: &context) != nil
}
for m in [0.5, 1.0, 2.0] {
    var lo = 1e-4, hi = 1e-1
    for _ in 0..<60 {
        let mid = (lo * hi).squareRoot()
        if passes(Animation.interpolatingSpring(mass: m, stiffness: mid, damping: 2 * (m * mid).squareRoot())) { hi = mid } else { lo = mid }
    }
    for k in [lo * (1 - 1e-9), hi * (1 + 1e-9), lo * 0.999, hi * 1.001] { compareEnds("critical cap mass \(m) stiffness \(k)", InterpolatingSpring(mass: m, stiffness: k, damping: 2 * (m * k).squareRoot()), Animation.interpolatingSpring(mass: m, stiffness: k, damping: 2 * (m * k).squareRoot())) }
    let end = InterpolatingSpring(mass: m, stiffness: hi * (1 + 1e-9), damping: 2 * (m * hi * (1 + 1e-9)).squareRoot()).settlingTime
    same("critical cap mass \(m) answers up to 101.2 s", abs(end - 101.2) < 1e-9, true)
}
print("compared", settlings, "settling durations")
print("compared", count, "numbers; worst difference", worst)
