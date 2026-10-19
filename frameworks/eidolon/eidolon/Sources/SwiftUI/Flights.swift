import CoreGraphics

// What a value does when it is told to go somewhere else while it is on its way to the last place it was told to go, as Apple's does
// (macOS 27, an NSHostingView over a Shape that records the data it is drawn with, retargeted a number of times at moments in the
// first animation: `host/retargetcmp.swift` asks it, and compares the numbers a `Flight` gives with the ones it showed). Nothing in
// this file knows of the screen: it works on the vectors the data of a value is made of, so that the host can compare it.
//
// - An animation that is not a fluid spring (a curve, an interpolating spring, whatever repeat or delay it has) takes over without a
//   break: the value is where the first one still takes it, and the new one covers the way left from there to the new place, by its own
//   progress: `old(t) + (target - old(t)) * progress(s)`, with the first going on to its end underneath.
// - A fluid spring starts again from where the value is, and keeps the speed it is going at only if the one it takes over from is a
//   fluid spring as well, whatever time it was put in (a speed of 2 does not double it, nor a delay take it off: the speed the
//   spring has in its own seconds, which the new one is let go with in its own).
// - No animation at all leaves the first going to its end, the new place moving it by the difference to where that was going.
// - A new place that is the one it is going to changes nothing.
// Not matched by any rule fitted to Apple's numbers, and so left as the port had it before (a fluid spring starting from where the value is, with
// no speed, the first one given up): a fluid spring that is delayed or sped up, told to go elsewhere (a curve, a spring from where the value is or
// from where it is when the delay is over, and a speed from the first, or any speed at all, none within a hundredth of the way).

/// How an animation goes, for a value that is on its way, without the animation: the three things the value needs from it.
struct Pace {
    let retiming: Retiming
    /// The spring of a fluid one, the only kind that takes the speed of the one it follows and goes on from there.
    let spring: Spring?
    /// How it goes for something `distance` apart from where it is going.
    let course: (Double) -> AnimationCourse
}

/// A value on its way: where it is at a moment (in the seconds of a clock the passages share), and the place it comes to.
/// This one is not on its way anywhere: it is at the place.
class Passage<Data: VectorArithmetic> {
    let end: Data

    init(end: Data) { self.end = end }

    func data(at now: Double) -> Data { end }

    func isOver(at now: Double) -> Bool { true }

    /// How fast it is going, in the seconds of the spring that takes it, if that is a fluid one; nothing else has a speed to give.
    func velocity(at now: Double) -> Data? { nil }
}

/// A new animation of a curve, or of an interpolating spring, over the way left to the new place, with what was going on still going on
/// underneath it: it is at `old + (end - old) * progress`, and at the place when it is over.
final class Blend<Data: VectorArithmetic>: Passage<Data> {
    private let old: Passage<Data>
    private let start: Double
    private let course: AnimationCourse

    init(old: Passage<Data>, end: Data, start: Double, course: AnimationCourse) {
        self.old = old
        self.start = start
        self.course = course
        super.init(end: end)
    }

    override func data(at now: Double) -> Data {
        let (progress, done) = course.position(elapsed: now - start)
        if done { return end }
        let from = old.data(at: now)
        var way = end - from
        way.scale(by: progress)
        return from + way
    }

    override func isOver(at now: Double) -> Bool { course.position(elapsed: now - start).done }
}

/// A fluid spring let go at the value, with the speed it was going at if the spring before was a fluid one (`speed`, in the seconds of the
/// spring before): the value is the place it comes to, plus the way left from where it started times the first part of the spring's
/// solution, plus the speed times the second.
final class Sprung<Data: VectorArithmetic>: Passage<Data> {
    private let from: Data
    private let start: Double
    private let retiming: Retiming
    private let remainder: Data
    private let speed: Data?
    private let track: FluidTrack
    private let course: AnimationCourse

    init(from: Data, end: Data, start: Double, spring: Spring, retiming: Retiming, speed: Data?) {
        let remainder = from - end
        var release: FluidTrack.Release?
        var carried = speed
        if let moving = speed, moving.magnitudeSquared > 0 {
            let together = remainder + moving
            release = FluidTrack.Release(remainderSquared: remainder.magnitudeSquared,
                                         crossed: (together.magnitudeSquared - remainder.magnitudeSquared - moving.magnitudeSquared) / 2,
                                         speedSquared: moving.magnitudeSquared)
        } else {
            carried = nil
        }
        self.from = from
        self.start = start
        self.retiming = retiming
        self.remainder = remainder
        self.speed = carried
        track = FluidTrack(spring, distance: remainder.magnitudeSquared.squareRoot(), release: release)
        course = AnimationCourse(.fluid(track), retiming: retiming)
        super.init(end: end)
    }

    override func data(at now: Double) -> Data {
        let elapsed = now - start
        let (progress, done) = course.position(elapsed: elapsed)
        if done { return end }
        guard let speed else {
            var way = end - from
            way.scale(by: progress)
            return from + way
        }
        let (left, kicked) = track.remainders(at: retiming.inner(at: elapsed))
        var rest = remainder
        rest.scale(by: left)
        var moving = speed
        moving.scale(by: kicked)
        return end + rest + moving
    }

    override func isOver(at now: Double) -> Bool { course.position(elapsed: now - start).done }

    override func velocity(at now: Double) -> Data? {
        let elapsed = now - start
        guard retiming.repeated == nil else { return nil }
        guard retiming.rate > 0, elapsed >= retiming.delay, !course.position(elapsed: elapsed).done else { return .zero }
        let (left, kicked) = track.rates(at: retiming.inner(at: elapsed))
        var rate = remainder
        rate.scale(by: left)
        guard var moving = speed else { return rate }
        moving.scale(by: kicked)
        rate += moving
        return rate
    }
}

/// No new animation: what was going on goes on to where it was going, the value moved by how far the new place is from it.
final class Shifted<Data: VectorArithmetic>: Passage<Data> {
    private let old: Passage<Data>
    private let shift: Data

    init(old: Passage<Data>, end: Data) {
        self.old = old
        shift = end - old.end
        super.init(end: end)
    }

    override func data(at now: Double) -> Data { old.isOver(at: now) ? end : old.data(at: now) + shift }

    override func isOver(at now: Double) -> Bool { old.isOver(at: now) }

    override func velocity(at now: Double) -> Data? { old.velocity(at: now) }
}

extension Passage {
    /// What a value on its way `old` does when it is told, at a moment, to go to `end` instead, by an animation or none. Told to go where it is already going, it is the same one: nothing is begun.
    static func redirecting(_ old: Passage<Data>, to end: Data, pace: Pace?, now: Double) -> Passage<Data> {
        if (end - old.end).magnitudeSquared <= 1e-12 { return old }
        guard let pace else { return old.isOver(at: now) ? Passage(end: end) : Shifted(old: old, end: end) }
        let current = old.data(at: now)
        if let spring = pace.spring {
            return Sprung(from: current, end: end, start: now, spring: spring, retiming: pace.retiming,
                          speed: pace.retiming.isRetimed ? nil : old.velocity(at: now))
        }
        return Blend(old: old, end: end, start: now, course: pace.course((end - current).magnitudeSquared.squareRoot()))
    }
}

// MARK: the data of a value whose kind is not known

/// The data of a value of a kind that is only known when it is opened, as a vector: of that kind's own data, which it holds, or nothing,
/// which is the zero of any kind. Two of them are of one kind where they are put together.
struct ErasedVector: VectorArithmetic {
    fileprivate var box: VectorBox?

    init<V: VectorArithmetic>(_ value: V) { box = Box(value) }

    fileprivate init(box: VectorBox?) { self.box = box }

    static var zero: ErasedVector { ErasedVector(box: nil) }

    static func + (a: ErasedVector, b: ErasedVector) -> ErasedVector {
        guard let left = a.box else { return b }
        return ErasedVector(box: left.adding(b.box))
    }

    static func - (a: ErasedVector, b: ErasedVector) -> ErasedVector {
        guard let left = a.box else {
            guard var right = b.box else { return .zero }
            right = right.scaled(by: -1)
            return ErasedVector(box: right)
        }
        return ErasedVector(box: left.subtracting(b.box))
    }

    static func == (a: ErasedVector, b: ErasedVector) -> Bool {
        switch (a.box, b.box) {
        case (nil, nil): return true
        case (let left?, let right?): return left.isEqual(to: right)
        default: return false
        }
    }

    mutating func scale(by rhs: Double) { box = box?.scaled(by: rhs) }

    var magnitudeSquared: Double { box?.magnitudeSquared ?? 0 }

    /// The data it holds, if it holds that kind of data.
    func data<V: VectorArithmetic>(as type: V.Type) -> V? {
        guard let box else { return V.zero }
        return (box as? Box<V>)?.value
    }
}

fileprivate protocol VectorBox {
    func adding(_ other: VectorBox?) -> VectorBox
    func subtracting(_ other: VectorBox?) -> VectorBox
    func scaled(by factor: Double) -> VectorBox
    var magnitudeSquared: Double { get }
    func isEqual(to other: VectorBox) -> Bool
}

fileprivate struct Box<V: VectorArithmetic>: VectorBox {
    let value: V

    init(_ value: V) { self.value = value }

    func adding(_ other: VectorBox?) -> VectorBox {
        guard let other = other as? Box<V> else { return self }
        return Box(value + other.value)
    }

    func subtracting(_ other: VectorBox?) -> VectorBox {
        guard let other = other as? Box<V> else { return self }
        return Box(value - other.value)
    }

    func scaled(by factor: Double) -> VectorBox {
        var copy = value
        copy.scale(by: factor)
        return Box(copy)
    }

    var magnitudeSquared: Double { value.magnitudeSquared }

    func isEqual(to other: VectorBox) -> Bool { (other as? Box<V>)?.value == value }
}
