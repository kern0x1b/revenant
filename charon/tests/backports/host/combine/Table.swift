//
//  Table.swift
//
//  The behaviour table. One entry per case, each returning the lines a subscriber was
//  given, in order; the two runs are compared line for line, so anything the host's own
//  Combine does differently from the module this port builds shows up as a differing
//  line. The groups are the four the work is grouped by: the operators, the schedulers,
//  the demand and the backpressure, and cancellation.
//

#if APPLE_COMBINE
import Combine
#else
import CombineKit
#endif

typealias Behaviour = () -> [String]
typealias Case = (name: String, body: Behaviour)

let table: [Case] = mergeCases
  + combineLatestCases
  + collectCases
  + schedulerCases
  + demandCases
  + cancelCases
  + operatorCases
  + valueCases

private let mergeCases: [Case] = [

    // MARK: The merge family

    ("merge/two/interleaved", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.merge(with: b))
        a.send(1)
        b.send(2)
        a.send(3)
        a.send(completion: .finished)
        b.send(completion: .finished)
        return trace.lines
    }),

    ("merge/two/finishes-after-both", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.merge(with: b))
        a.send(completion: .finished)
        trace.note("after the first upstream finished")
        b.send(completion: .finished)
        return trace.lines
    }),

    ("merge/two/holds-until-demanded", { () -> [String] in
        // A publisher that sends at subscription time, before the merged publisher has
        // been told about the subscription: the value must still arrive.
        let trace = Trace()
        trace.sink(Publishers.Merge(Just(1), Just(2)))
        return trace.lines
    }),

    ("merge/three/chains", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let c = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.merge(with: b).merge(with: c))
        c.send(9)
        a.send(8)
        b.send(7)
        return trace.lines
    }),

    ("merge/many/sequence", { () -> [String] in
        let trace = Trace()
        trace.sink(Publishers.MergeMany([Just(1), Just(2), Just(3)]))
        return trace.lines
    }),

    ("merge/many/empty", { () -> [String] in
        let trace = Trace()
        trace.sink(Publishers.MergeMany([PassthroughSubject<Int, TestError>]()))
        return trace.lines
    }),

    ("merge/failure/forwarded", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.merge(with: b))
        a.send(1)
        b.send(completion: .failure(.failed))
        a.send(2)
        return trace.lines
    }),

    ("merge/demand/limited", { () -> [String] in
        let a = ManualPublisher<Int>()
        let b = ManualPublisher<Int>()
        let trace = Trace()
        Publishers.Merge(a, b).subscribe(RecordingSubscriber<Int, TestError>(trace: trace,
                                                                             initial: .max(1)))
        a.send(1)
        b.send(2)
        a.send(3)
        trace.note("upstream asked for " + Trace.describe(a.requested))
        trace.note("upstream asked for " + Trace.describe(b.requested))
        return trace.lines
    }),

]

private let combineLatestCases: [Case] = [

    // MARK: The combineLatest family

    ("combineLatest/two/waits-for-both", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.combineLatest(b))
        a.send(1)
        trace.note("after one upstream")
        b.send(2)
        a.send(3)
        return trace.lines
    }),

    ("combineLatest/three/transform", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let c = PassthroughSubject<String, TestError>()
        let trace = Trace()
        trace.sink(a.combineLatest(b, c) { "\($0)-\($1)-\($2)" })
        a.send(1)
        b.send(2)
        c.send("x")
        a.send(10)
        c.send("y")
        return trace.lines
    }),

    ("combineLatest/two/finishes-after-both", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.combineLatest(b))
        a.send(1)
        a.send(completion: .finished)
        trace.note("after the first upstream finished")
        b.send(2)
        b.send(completion: .finished)
        return trace.lines
    }),

    ("combineLatest/two/failure", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(a.combineLatest(b))
        a.send(1)
        b.send(completion: .failure(.failed))
        return trace.lines
    }),

    ("combineLatest/demand/one-per-upstream", { () -> [String] in
        // A combined value is only sent once the downstream asks for one, so each
        // upstream holds one value; the demand each is given says so.
        let a = ManualPublisher<Int>()
        let b = ManualPublisher<Int>()
        let trace = Trace()
        a.combineLatest(b).subscribe(RecordingSubscriber<(Int, Int), TestError>(trace: trace,
                                                                                 initial: .max(1)))
        a.send(1)
        trace.note("a asked for " + Trace.describe(a.requested))
        b.send(2)
        trace.note("b asked for " + Trace.describe(b.requested))
        return trace.lines
    }),

]

private let collectCases: [Case] = [

    // MARK: collect(byTime:)

    ("collect/byTime/on-the-tick", { () -> [String] in
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(subject.collect(.byTime(scheduler, TestScheduler.Stride.seconds(1))))
        subject.send(1)
        subject.send(2)
        trace.note("at " + String(scheduler.now.seconds))
        scheduler.advance(to: 1.5)
        subject.send(3)
        scheduler.advance(to: 2.5)
        subject.send(completion: .finished)
        scheduler.advance(to: 4.5)
        trace.note("after the upstream finished and the clock ran on")
        return trace.lines
    }),

    ("collect/byTimeOrCount/on-the-count", { () -> [String] in
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(subject.collect(.byTimeOrCount(scheduler, TestScheduler.Stride.seconds(1), 2)))
        subject.send(1)
        subject.send(2)
        subject.send(3)
        scheduler.advance(to: 1.5)
        subject.send(completion: .finished)
        scheduler.advance(to: 2.5)
        trace.note("after the upstream finished and the clock ran on")
        return trace.lines
    }),

    ("collect/byTime/forwards-failure", { () -> [String] in
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        trace.sink(subject.collect(.byTime(scheduler, TestScheduler.Stride.seconds(1))))
        subject.send(1)
        subject.send(completion: .failure(.failed))
        scheduler.advance(to: 2)
        trace.note("after the upstream failed and the clock ran on")
        return trace.lines
    }),

]

private let schedulerCases: [Case] = [

    // MARK: The schedulers

    ("scheduler/immediate/strides", { () -> [String] in
        let trace = Trace()
        let immediate = ImmediateScheduler.shared
        trace.note("now " + String(immediate.now == immediate.now))
        trace.note("minimumTolerance " + String(immediate.minimumTolerance.magnitude))
        var ran = 0
        immediate.schedule(after: immediate.now.advanced(by: .seconds(5))) {
            ran += 1
        }
        trace.note("ran " + String(ran))
        return trace.lines
    }),

    ("scheduler/test/debounce-and-throttle", { () -> [String] in
        let trace = Trace()
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, TestError>()
        let debounced = Trace()
        let throttled = Trace()
        debounced.sink(subject.debounce(for: TestScheduler.Stride.seconds(1), scheduler: scheduler))
        throttled.sink(subject.throttle(for: TestScheduler.Stride.seconds(2), scheduler: scheduler, latest: true))
        subject.send(1)
        scheduler.advance(to: 0.5)
        subject.send(2)
        scheduler.advance(to: 1.5)
        subject.send(3)
        scheduler.advance(to: 4.5)
        for line in debounced.lines { trace.note("debounced " + line) }
        for line in throttled.lines { trace.note("throttled " + line) }
        return trace.lines
    }),

    ("scheduler/test/timeout-and-measure", { () -> [String] in
        let trace = Trace()
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, TestError>()
        let timedOut = Trace()
        let measured = Trace()
        timedOut.sink(subject.timeout(.seconds(1), scheduler: scheduler))
        measured.sink(subject.measureInterval(using: scheduler))
        subject.send(1)
        scheduler.advance(to: 1.5)
        for line in timedOut.lines { trace.note("timeout " + line) }
        for line in measured.lines { trace.note("measure " + line) }
        return trace.lines
    }),

]

private let demandCases: [Case] = [

    // MARK: Demand and backpressure

    ("demand/map/limited", { () -> [String] in
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        publisher.map { $0 * 2 }
            .subscribe(RecordingSubscriber<Int, TestError>(trace: trace, initial: .max(2)))
        publisher.send(1)
        publisher.send(2)
        publisher.send(3)
        trace.note("upstream asked for " + Trace.describe(publisher.requested))
        return trace.lines
    }),

    ("demand/map/additional-demand", { () -> [String] in
        // A subscriber that asks for more from inside receive(_:) has that demand reach
        // the publisher.
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        let subscriber = GrowingSubscriber(trace: trace, growth: 2, ceiling: 5)
        publisher.subscribe(subscriber)
        for value in 1...6 { publisher.send(value) }
        trace.note("upstream asked for " + Trace.describe(publisher.requested))
        return trace.lines
    }),

    ("demand/buffer/dropOldest", { () -> [String] in
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        publisher.buffer(size: 2, prefetch: .byRequest, whenFull: .dropOldest)
            .subscribe(RecordingSubscriber<Int, TestError>(trace: trace, initial: .none))
        for value in 1...4 { publisher.send(value) }
        publisher.send(5)
        publisher.send(6)
        publisher.complete()
        return trace.lines
    }),

    ("demand/buffer/dropNewest", { () -> [String] in
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        publisher.buffer(size: 2, prefetch: .byRequest, whenFull: .dropNewest)
            .subscribe(RecordingSubscriber<Int, TestError>(trace: trace, initial: .none))
        for value in 1...4 { publisher.send(value) }
        publisher.send(5)
        publisher.send(6)
        publisher.complete()
        return trace.lines
    }),

    ("demand/subject/accounts", { () -> [String] in
        let subject = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        subject.buffer(size: 3, prefetch: .keepFull, whenFull: .dropOldest)
            .subscribe(RecordingSubscriber<Int, TestError>(trace: trace, initial: .max(1)))
        for value in 1...5 { subject.send(value) }
        subject.send(completion: .finished)
        return trace.lines
    }),

    ("demand/retry-and-catch", { () -> [String] in
        var attempts = 0
        let trace = Trace()
        let retried = Deferred { () -> AnyPublisher<Int, TestError> in
            attempts += 1
            let current = attempts
            return current < 3 ? Fail<Int, TestError>(error: .failed).eraseToAnyPublisher()
                               : Just(current).setFailureType(to: TestError.self).eraseToAnyPublisher()
        }
        trace.sink(retried.retry(2))
        trace.note("attempts " + String(attempts))
        return trace.lines
    }),

    ("demand/flatMap/maxPublishers", { () -> [String] in
        let outer = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        let flattened = outer.flatMap(maxPublishers: .max(1)) { value -> AnyPublisher<Int, TestError> in
            Just(value).setFailureType(to: TestError.self).delay(for: .seconds(1),
                                                                scheduler: ImmediateScheduler.shared)
                .eraseToAnyPublisher()
        }
        trace.sink(flattened)
        outer.send(1)
        outer.send(2)
        return trace.lines
    }),

]

private let cancelCases: [Case] = [

    // MARK: Cancellation

    ("cancel/stops-values", { () -> [String] in
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        let cancellable: AnyCancellable? = publisher.map { $0 * 2 }
            .sink(receiveCompletion: { trace.completion($0) }, receiveValue: { trace.value($0) })
        publisher.send(1)
        cancellable?.cancel()
        publisher.send(2)
        trace.note("upstream cancelled " + String(publisher.cancelled))
        return trace.lines
    }),

    ("cancel/reaches-upstream-through-operators", { () -> [String] in
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        let cancellable: AnyCancellable? = publisher
            .filter { $0 % 2 == 0 }
            .map { $0 / 2 }
            .removeDuplicates()
            .sink(receiveCompletion: { trace.completion($0) }, receiveValue: { trace.value($0) })
        for value in 1...6 { publisher.send(value) }
        cancellable?.cancel()
        publisher.send(8)
        trace.note("upstream cancelled " + String(publisher.cancelled))
        return trace.lines
    }),

    ("cancel/handleEvents-order", { () -> [String] in
        let publisher = ManualPublisher<Int>()
        let trace = Trace()
        let cancellable: AnyCancellable? = publisher
            .handleEvents(receiveSubscription: { _ in trace.note("subscription") },
                          receiveOutput: { trace.note("output \($0)") },
                          receiveCompletion: { trace.note("completion \($0)") },
                          receiveCancel: { trace.note("cancel") },
                          receiveRequest: { trace.note("request \($0)") })
            .sink(receiveCompletion: { trace.completion($0) }, receiveValue: { trace.value($0) })
        publisher.send(1)
        cancellable?.cancel()
        return trace.lines
    }),

    ("cancel/anycancellable-deinit", { () -> [String] in
        let trace = Trace()
        do {
            let publisher = ManualPublisher<Int>()
            var cancellable: AnyCancellable? = publisher.sink(receiveCompletion: { trace.completion($0) },
                                                            receiveValue: { trace.value($0) })
            publisher.send(1)
            trace.note("held " + String(cancellable != nil))
            cancellable = nil
            trace.note("upstream cancelled " + String(publisher.cancelled))
        }
        return trace.lines
    }),

]

private let operatorCases: [Case] = zipCase + switchCase + sequenceCase
  + shareCase + assignCase + futureCase

private let zipCase: [Case] = [
    ("operators/zip-two", { () -> [String] in
        let a = PassthroughSubject<Int, TestError>()
        let b = PassthroughSubject<String, TestError>()
        let trace = Trace()
        trace.sink(a.zip(b))
        a.send(1)
        b.send("x")
        a.send(2)
        b.send("y")
        b.send("z")
        return trace.lines
    }),
]

private let switchCase: [Case] = [
    ("operators/switchToLatest", { () -> [String] in
        let trace = Trace()
        let outer = PassthroughSubject<PassthroughSubject<Int, TestError>, TestError>()
        trace.sink(outer.switchToLatest())
        let firstInner = PassthroughSubject<Int, TestError>()
        let secondInner = PassthroughSubject<Int, TestError>()
        outer.send(firstInner)
        firstInner.send(11)
        outer.send(secondInner)
        firstInner.send(99)
        secondInner.send(22)
        outer.send(completion: .finished)
        return trace.lines
    }),
]

private let sequenceCase: [Case] = [
    ("operators/first-where-and-reduce", { () -> [String] in
        let trace = Trace()
        // The failure type of a sequence publisher comes from its use, so each chain
        // says it with setFailureType.
        let first = Publishers.Sequence(sequence: [1, 2, 3, 4, 5])
            .first(where: { $0 > 2 })
            .setFailureType(to: TestError.self)
        trace.sink(first)
        let reduced = Publishers.Sequence(sequence: [1, 2, 3, 4])
            .reduce(0, +)
            .setFailureType(to: TestError.self)
        trace.sink(reduced)
        let distinct = Publishers.Sequence(sequence: [1, 1, 2, 2, 3])
            .removeDuplicates()
            .setFailureType(to: TestError.self)
        trace.sink(distinct)
        return trace.lines
    }),
]

private let shareCase: [Case] = [
    ("operators/share-and-autoconnect", { () -> [String] in
        let subject = PassthroughSubject<Int, TestError>()
        let trace = Trace()
        let shared = subject.share()
        trace.sink(shared)
        trace.sink(shared)
        subject.send(1)
        return trace.lines
    }),
]

private let assignCase: [Case] = [
    ("operators/assign-to-a-property", { () -> [String] in
        let subject = PassthroughSubject<Int, Never>()
        let trace = Trace()
        let box = Box()
        subject.assign(to: \.value, on: box)
        Publishers.Sequence(sequence: [1, 2, 3])
            .sink { [weak subject] in subject?.send($0) }
        trace.note("value " + String(box.value))
        return trace.lines
    }),
]

private let futureCase: [Case] = [
    ("operators/future-and-deferred", { () -> [String] in
        let trace = Trace()
        var built = 0
        trace.sink(Future<Int, TestError> { promise in
            built += 1
            promise(.success(7))
        })
        trace.sink(Deferred { [built] () -> Just<Int> in
            trace.note("deferred built")
            return Just(built)
        })
        return trace.lines
    }),
]

private let valueCases: [Case] = [

    // MARK: The equality and hashing Apple's interface declares in the open

    ("equality/publishers", { () -> [String] in
        let trace = Trace()
        func note(_ name: String, _ value: Bool) {
            trace.note(name + " " + String(value))
        }
        note("merge same", Publishers.Merge(Just(1), Just(2)) == Publishers.Merge(Just(1), Just(2)))
        note("merge other", Publishers.Merge(Just(1), Just(2)) == Publishers.Merge(Just(1), Just(3)))
        note("combineLatest",
             Publishers.CombineLatest(Just(1), Just(2)) == Publishers.CombineLatest(Just(1), Just(2)))
        note("combineLatest3",
             Publishers.CombineLatest3(Just(1), Just(2), Just(3))
                 == Publishers.CombineLatest3(Just(1), Just(2), Just(3)))
        note("combineLatest4",
             Publishers.CombineLatest4(Just(1), Just(2), Just(3), Just(4))
                 == Publishers.CombineLatest4(Just(1), Just(2), Just(3), Just(4)))
        note("mergeMany",
             Publishers.MergeMany([Just(1), Just(2)]) == Publishers.MergeMany([Just(1), Just(2)]))
        note("zip", Publishers.Zip(Just(1), Just(2)) == Publishers.Zip(Just(1), Just(2)))
        note("zip3", Publishers.Zip3(Just(1), Just(2), Just(3)) == Publishers.Zip3(Just(1), Just(2), Just(3)))
        note("zip4", Publishers.Zip4(Just(1), Just(2), Just(3), Just(4))
                 == Publishers.Zip4(Just(1), Just(2), Just(3), Just(4)))
        note("collect", Publishers.Collect(upstream: Just(1)) == Publishers.Collect(upstream: Just(1)))
        note("count", Publishers.Count(upstream: Just(1)) == Publishers.Count(upstream: Just(1)))
        note("drop", Publishers.Drop(upstream: Just(1), count: 1)
                 == Publishers.Drop(upstream: Just(1), count: 2))
        note("retry", Publishers.Retry(upstream: Just(1), retries: 3)
                  == Publishers.Retry(upstream: Just(1), retries: 9))
        note("output", Publishers.Output(upstream: Just(1), range: 0..<2)
                  == Publishers.Output(upstream: Just(1), range: 1..<2))
        note("setFailureType", Just(1).setFailureType(to: TestError.self)
                                == Just(1).setFailureType(to: TestError.self))
        note("replaceEmpty", Publishers.ReplaceEmpty(upstream: Just(1), output: 0)
                             == Publishers.ReplaceEmpty(upstream: Just(1), output: 0))
        note("concatenate", Publishers.Concatenate(prefix: Just(1), suffix: Just(2))
                                 == Publishers.Concatenate(prefix: Just(1), suffix: Just(2)))
        note("empty", Empty<Int, TestError>() == Empty<Int, TestError>())
        note("fail", Fail<Int, TestError>(error: .failed) == Fail<Int, TestError>(error: .failed))
        note("just", Just(1) == Just(1))
        note("prefetch", Publishers.PrefetchStrategy.keepFull == Publishers.PrefetchStrategy.byRequest)
        return trace.lines
    }),

    ("hashing/demand-and-completion", { () -> [String] in
        let trace = Trace()
        let three = Subscribers.Demand.max(3)
        trace.note("demand equal \(three == Subscribers.Demand.max(3))")
        trace.note("demand hash equal \(three.hashValue == Subscribers.Demand.max(3).hashValue)")
        trace.note("demand hash stable \(three.hashValue == three.hashValue)")
        let finished = Subscribers.Completion<TestError>.finished
        trace.note("completion equal \(finished == Subscribers.Completion<TestError>.finished)")
        let sameFinished = Subscribers.Completion<TestError>.finished
        trace.note("completion hash equal "
                   + String(finished.hashValue == sameFinished.hashValue))
        trace.note("completion differs \(finished != Subscribers.Completion<TestError>.failure(.failed))")
        return trace.lines
    }),

    ("optional-and-result/publishers", { () -> [String] in
        let trace = Trace()
        let some: Optional<Int> = 7
        trace.sink(some.publisher.map { $0 * 2 })
        let none: Optional<Int> = nil
        trace.sink(none.publisher)
        trace.sink(Result<Int, TestError>.success(3).publisher)
        trace.sink(Result<Int, TestError>.failure(.failed).publisher)
        return trace.lines
    }),

    ("record/round-trips", { () -> [String] in
        let trace = Trace()
        var recording = Record<Int, TestError>.Recording()
        recording.receive(1)
        recording.receive(2)
        recording.receive(completion: .finished)
        let record = Record(recording: recording)
        trace.note("output \(record.recording.output)")
        trace.note("completion \(Trace.describe(record.recording.completion))")
        return trace.lines
    }),
]

/// A subscriber that asks for more from inside `receive(_:)`, so the demand it returns
/// has to reach the publisher.
final class GrowingSubscriber: Subscriber {
    typealias Input = Int
    typealias Failure = TestError

    private let trace: Trace
    private let growth: Int
    private let ceiling: Int
    private var subscription: Subscription?
    private var asked = 0

    init(trace: Trace, growth: Int, ceiling: Int) {
        self.trace = trace
        self.growth = growth
        self.ceiling = ceiling
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(.max(growth))
    }

    func receive(_ input: Int) -> Subscribers.Demand {
        trace.value(input)
        asked += 1
        guard asked < ceiling else { return .none }
        return .max(growth)
    }

    func receive(completion: Subscribers.Completion<TestError>) {
        trace.completion(completion)
    }
}

/// A place to write a value, for the `assign(to:on:)` case.
final class Box {
    var value: Int = 0
}
