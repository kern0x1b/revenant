import CoreGraphics

struct Pace {
    let retiming: Retiming
    let spring: Spring?
    let course: (Double) -> AnimationCourse
}

class Passage<Data: VectorArithmetic> {
    let end: Data

    init(end: Data) { self.end = end }

    func data(at now: Double) -> Data { end }

    func isOver(at now: Double) -> Bool { true }

    func velocity(at now: Double) -> Data? { nil }
}

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
