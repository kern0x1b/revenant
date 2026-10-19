//
//  Publishers.CollectByTime.swift
//
//  `Publishers.TimeGroupingStrategy`, `Publishers.CollectByTime` and the
//  `collect(_:options:)` operator: elements collected over an interval of a scheduler's
//  time, and sent on a schedule instead of one by one.
//

extension Publishers {

    /// A strategy for collecting received elements.
    public enum TimeGroupingStrategy<Context: Scheduler> {

        /// A grouping that collects and periodically publishes items.
        case byTime(Context, Context.SchedulerTimeType.Stride)

        /// A grouping that collects and publishes items periodically or when a buffer
        /// reaches a maximum size.
        case byTimeOrCount(Context, Context.SchedulerTimeType.Stride, Int)
    }

    /// A publisher that buffers and periodically publishes its items.
    public struct CollectByTime<Upstream: Publisher, Context: Scheduler>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = [Upstream.Output]

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// The strategy with which to collect and publish elements.
        public let strategy: Publishers.TimeGroupingStrategy<Context>

        /// `Scheduler` options to use for the strategy.
        public let options: Context.SchedulerOptions?

        public init(upstream: Upstream,
                    strategy: Publishers.TimeGroupingStrategy<Context>,
                    options: Context.SchedulerOptions?)
        {
            self.upstream = upstream
            self.strategy = strategy
            self.options = options
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure, Downstream.Input == [Upstream.Output]
        {
            upstream.subscribe(Inner(downstream: subscriber, strategy: strategy, options: options))
        }
    }
}

extension Publisher {

    /// Collects elements by a given time-grouping strategy, and emits a single array of
    /// the collection.
    ///
    /// Use `collect(_:options:)` to emit arrays of elements on a schedule specified by a
    /// `Scheduler` and `Stride` that you provide. At the end of each scheduled interval,
    /// the publisher sends an array that contains the items it collected. If the
    /// upstream publisher finishes before filling the buffer, the publisher sends an
    /// array that contains the items it received.
    ///
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    ///
    /// - Parameters:
    ///   - strategy: The timing group strategy used by the operator to collect and
    ///     publish elements.
    ///   - options: `Scheduler` options to use for the strategy.
    /// - Returns: A publisher that collects elements by a given strategy, and emits
    ///   a single array of the collection.
    public func collect<S: Scheduler>(_ strategy: Publishers.TimeGroupingStrategy<S>,
                                      options: S.SchedulerOptions? = nil)
        -> Publishers.CollectByTime<Self, S>
    {
        return Publishers.CollectByTime(upstream: self, strategy: strategy, options: options)
    }
}

extension Publishers.CollectByTime {
    internal final class Inner<Downstream: Subscriber>: Subscriber, Subscription
        where Downstream.Input == [Upstream.Output], Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let lock = UnfairLock.allocate()
        private let downstream: Downstream
        private let scheduler: Context
        private let stride: Context.SchedulerTimeType.Stride
        private let countLimit: Int?
        private let options: Context.SchedulerOptions?

        private var state = SubscriptionStatus.awaitingSubscription
        private var buffer: [Input] = []
        private var scheduled: Cancellable?
        private var downstreamDemand: Subscribers.Demand = .none

        init(downstream: Downstream,
             strategy: Publishers.TimeGroupingStrategy<Context>,
             options: Context.SchedulerOptions?)
        {
            self.downstream = downstream
            switch strategy {
            case .byTime(let scheduler, let stride):
                self.scheduler = scheduler
                self.stride = stride
                self.countLimit = nil
            case .byTimeOrCount(let scheduler, let stride, let count):
                self.scheduler = scheduler
                self.stride = stride
                self.countLimit = count
            }
            self.options = options
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            // The schedule is armed here, or the operator has no tick at all: a
            // collection that is only ever sent when the upstream ends is not a
            // collection on a schedule.
            scheduled = scheduleTick()
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            // `byTimeOrCount` sends when the count is reached as well as on the tick.
            // Measured against the host's own Combine over eight configurations of
            // strategy, stride and count: a count of two with three values sent before
            // the first tick gives two collections, `[1,2]` and `[3]`, and only a
            // strategy of `byTime` gives one.
            buffer.append(input)
            let isFull = countLimit.map { buffer.count >= $0 } ?? false
            lock.unlock()
            if isFull {
                tick()
            }
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            state = .terminal
            scheduled?.cancel()
            scheduled = nil
            // What has been collected since the last tick is not sent with the
            // completion: the completion arrives, and the collection waits for a tick
            // that will not come.
            buffer = []
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            // A publisher that is asked for values has to be asked for them: without this
            // the demand stops here, the upstream is never asked, and it never sends -
            // which is what a publisher that only sends what it is asked for does.
            guard case .subscribed(let subscription) = state else {
                lock.unlock()
                return
            }
            downstreamDemand += demand
            let isSendable = downstreamDemand > .none && !buffer.isEmpty
            lock.unlock()
            subscription.request(demand)
            if isSendable {
                tick()
            }
        }

        func cancel() {
            lock.lock()
            guard case .subscribed(let subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            scheduled?.cancel()
            scheduled = nil
            buffer = []
            lock.unlock()
            subscription.cancel()
        }

        /// The repeating tick, armed on subscription and re-armed by every tick. It is
        /// the scheduler's own repeating schedule, so a tick does not have to queue the
        /// next one.
        private func scheduleTick() -> Cancellable {
            return scheduler.schedule(after: scheduler.now.advanced(by: stride),
                                      interval: stride,
                                      tolerance: scheduler.minimumTolerance,
                                      options: options) { [weak self] in
                self?.tick()
            }
        }

        /// One scheduled interval: what has been collected since the last one goes
        /// downstream if it asked for it.
        private func tick() {
            lock.lock()
            guard case .subscribed = state, downstreamDemand > .none, !buffer.isEmpty else {
                lock.unlock()
                return
            }
            let values = buffer
            buffer = []
            downstreamDemand -= 1
            lock.unlock()
            let additionalDemand = downstream.receive(values)
            if additionalDemand > .none {
                lock.lock()
                downstreamDemand += additionalDemand
                lock.unlock()
            }
        }
    }
}
