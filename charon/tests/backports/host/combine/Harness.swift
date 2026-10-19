#if APPLE_COMBINE
import Combine
#else
import CombineKit
#endif

enum TestError: Error, Equatable {
    case failed
    case replaced
}

final class TestScheduler: Scheduler {

    typealias SchedulerTimeType = Time
    typealias SchedulerOptions = String
    typealias Stride = Time.Interval

    struct Time: Strideable, Comparable {
        typealias Stride = TestScheduler.Time.Interval

        struct Interval: SchedulerTimeIntervalConvertible, Comparable, AdditiveArithmetic,
                         ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {

            var seconds: Double
            var magnitude: Int { return Int(seconds) }

            init(_ seconds: Double) { self.seconds = seconds }
            init(integerLiteral value: Int) { self.seconds = Double(value) }
            init(floatLiteral value: Double) { self.seconds = value }

            static var zero: Interval { return Interval(0) }

            static func seconds(_ value: Int) -> Interval { return Interval(Double(value)) }
            static func seconds(_ value: Double) -> Interval { return Interval(value) }
            static func milliseconds(_ value: Int) -> Interval { return Interval(Double(value) / 1000) }
            static func microseconds(_ value: Int) -> Interval { return Interval(Double(value) / 1_000_000) }
            static func nanoseconds(_ value: Int) -> Interval { return Interval(Double(value) / 1_000_000_000) }

            static func < (lhs: Interval, rhs: Interval) -> Bool { return lhs.seconds < rhs.seconds }
            static func + (lhs: Interval, rhs: Interval) -> Interval { return Interval(lhs.seconds + rhs.seconds) }
            static func - (lhs: Interval, rhs: Interval) -> Interval { return Interval(lhs.seconds - rhs.seconds) }
            static func * (lhs: Interval, rhs: Interval) -> Interval { return Interval(lhs.seconds * rhs.seconds) }
            static func * (lhs: Interval, rhs: Double) -> Interval { return Interval(lhs.seconds * rhs) }
            static func / (lhs: Interval, rhs: Double) -> Interval { return Interval(lhs.seconds / rhs) }
        }

        var seconds: Double

        init(_ seconds: Double) { self.seconds = seconds }

        static func < (lhs: Time, rhs: Time) -> Bool { return lhs.seconds < rhs.seconds }
        static func + (lhs: Time, rhs: Stride) -> Time { return Time(lhs.seconds + rhs.seconds) }
        static func - (lhs: Time, rhs: Time) -> Interval { return Interval(lhs.seconds - rhs.seconds) }

        func advanced(by stride: Stride) -> Time { return self + stride }
        func distance(to other: Time) -> Interval { return other - self }
    }

    private struct Work {
        let due: Time
        let interval: Stride?
        let action: () -> Void
        var cancelled = false
    }

    private var works: [Work] = []
    private(set) var current = Time(0)

    var now: Time { return current }

    var minimumTolerance: Stride { return Stride(0) }

    func advance(to seconds: Double) {
        let target = Time(seconds)
        while true {
            let due = works.filter { !$0.cancelled && $0.due <= target }
                .sorted { $0.due.seconds < $1.due.seconds }
            guard let next = due.first else { break }
            works.removeAll { $0.due == next.due && !$0.cancelled }
            current = next.due
            if let interval = next.interval {
                works.append(Work(due: next.due + interval, interval: interval, action: next.action))
            }
            next.action()
        }
        works.removeAll { $0.cancelled }
        current = target
    }

    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        works.append(Work(due: current, interval: nil, action: action))
    }

    func schedule(after date: Time, tolerance: Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        works.append(Work(due: date, interval: nil, action: action))
    }

    func schedule(after date: Time,
                  interval: Stride,
                  tolerance: Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable
    {
        works.append(Work(due: date, interval: interval, action: action))
        return TestCancellable { [weak self] in self?.cancel(due: date) }
    }

    private func cancel(due: Time) {
        for index in works.indices where works[index].due == due {
            works[index].cancelled = true
        }
    }
}

final class TestCancellable: Cancellable {
    private let onCancel: () -> Void
    init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

final class Trace {
    private(set) var lines: [String] = []
    private(set) var subscriptions: [AnyCancellable] = []

    func sink<P: Publisher>(_ publisher: P) {
        subscriptions.append(publisher.sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished:
                self?.lines.append("finished")
            case .failure(let error):
                self?.lines.append("failure " + Trace.describe(error))
            }
        }, receiveValue: { [weak self] in self?.value($0) }))
    }

    func value(_ any: Any) {
        lines.append("value " + Trace.describe(any))
    }

    func note(_ line: String) {
        lines.append(line)
    }

    func completion<Failure: Error>(_ completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            lines.append("finished")
        case .failure(let error):
            lines.append("failure " + Trace.describe(error))
        }
    }

    static func describe(_ any: Any) -> String {
        switch any {
        case let value as Int:
            return String(value)
        case let value as String:
            return value
        case let value as Bool:
            return String(value)
        case let value as [Int]:
            return "[" + value.map(String.init).joined(separator: ",") + "]"
        case let value as (Int, Int):
            return "(\(value.0),\(value.1))"
        case let value as (Int, Int, Int):
            return "(\(value.0),\(value.1),\(value.2))"
        case let value as (String, Int):
            return "(\(value.0),\(value.1))"
        case let value as TestError:
            return "TestError." + (value == .failed ? "failed" : "replaced")
        default:
            return String(describing: any)
        }
    }
}

final class RecordingSubscriber<Input, Failure: Error>: Subscriber {
    let trace: Trace
    private let initial: Subscribers.Demand
    private(set) var subscription: Subscription?

    init(trace: Trace, initial: Subscribers.Demand) {
        self.trace = trace
        self.initial = initial
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(initial)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        trace.value(input)
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        trace.completion(completion)
    }
}

final class ManualPublisher<Output>: Publisher {
    typealias Failure = TestError

    private(set) var cancelled = false
    private(set) var subscription: ManualSubscription?
    private var downstream: AnySubscriber<Output, TestError>?

    var requested: Subscribers.Demand { return subscription?.requested ?? .none }

    func send(_ value: Output) {
        _ = downstream?.receive(value)
    }

    func fail(_ error: TestError) {
        downstream?.receive(completion: .failure(error))
    }

    func complete() {
        downstream?.receive(completion: .finished)
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == TestError {
        let any = AnySubscriber(subscriber)
        downstream = any
        let manual = ManualSubscription { [weak self] in
            self?.cancelled = true
        }
        subscription = manual
        any.receive(subscription: manual)
    }
}

final class ManualSubscription: Subscription {
    private(set) var requested: Subscribers.Demand = .none
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func request(_ demand: Subscribers.Demand) { requested += demand }
    func cancel() { onCancel() }
}

extension TestScheduler.Time.Interval: SignedNumeric {

    init?<T: BinaryInteger>(exactly source: T) {
        self.init(Double(source))
    }

    init?<T: BinaryFloatingPoint>(exactly source: T) {
        self.init(Double(source))
    }

    static func / (lhs: TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval {
        return TestScheduler.Time.Interval(lhs.seconds / rhs.seconds)
    }

    static func % (lhs: TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval {
        return TestScheduler.Time.Interval(lhs.seconds.truncatingRemainder(dividingBy: rhs.seconds))
    }

    static func += (lhs: inout TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) { lhs = lhs + rhs }
    static func -= (lhs: inout TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) { lhs = lhs - rhs }
    static func *= (lhs: inout TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) { lhs = lhs * rhs }
    static func /= (lhs: inout TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) { lhs = lhs / rhs }
    static func %= (lhs: inout TestScheduler.Time.Interval, rhs: TestScheduler.Time.Interval) { lhs = lhs % rhs }

    func multiplied(by other: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval { return self * other }
    func divided(by other: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval { return self / other }
    func remainder(dividingBy other: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval { return self % other }

    func multiplying(by other: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval { return self * other }
    func dividing(by other: TestScheduler.Time.Interval) -> TestScheduler.Time.Interval { return self / other }

    var description: String { return "\(seconds)s" }
}
