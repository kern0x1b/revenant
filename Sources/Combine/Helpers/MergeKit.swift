//
//  MergeKit.swift
//
//  The shared machinery of `Publishers.Merge`, `Publishers.CombineLatest` and
//  `Publishers.MergeMany`: the parts that do not depend on how many upstreams there are,
//  and so are written once for all three families. What does depend on the arity (the
//  stored properties, the `init`, and the tuple the combined publisher produces) is
//  written out per arity in `Publishers.Merge.swift` and `Publishers.CombineLatest.swift`.
//

import CombineHelpers

// MARK: - Publishers.Merge

/// The subscription a merged publisher hands downstream, and at the same time the
/// subscriber it hands to every upstream. Both the upstreams and the downstream speak
/// the same `Output` and `Failure`, so one object serves all of them.
internal final class MergeInner<Output, Failure: Error, Downstream: Subscriber>: Subscription, Subscriber
    where Downstream.Input == Output, Downstream.Failure == Failure
{
    typealias Input = Output

    private enum State {
        case awaitingSubscriptions
        case active
        case terminated
    }

    private let lock = UnfairLock.allocate()
    private let downstream: Downstream
    private let expectedUpstreamCount: Int

    private var state: State = .awaitingSubscriptions
    private var isDownstreamSubscribed = false
    private var upstreamSubscriptions: [Subscription] = []
    private var receivedUpstreamCount = 0
    private var remainingUpstreamCount: Int
    private var downstreamDemand: Subscribers.Demand = .none

    init(downstream: Downstream, upstreamCount: Int) {
        self.downstream = downstream
        self.expectedUpstreamCount = upstreamCount
        self.remainingUpstreamCount = upstreamCount
    }

    deinit {
        lock.deallocate()
    }

    // MARK: Subscription

    func request(_ demand: Subscribers.Demand) {
        lock.lock()
        guard case .active = state, demand > .none else {
            lock.unlock()
            return
        }
        downstreamDemand += demand
        let subscriptions = upstreamSubscriptions
        lock.unlock()

        // A merged publisher passes a request through to every upstream. This is the
        // host's own rule, measured: with a downstream that asked for one value the host
        // leaves each upstream having been asked for exactly one, and with a downstream
        // that asked for everything it leaves each upstream having been asked for
        // everything - so a publisher that sends at subscription time, which is what
        // `Just` does, is asked for what the downstream asked for and delivers it.
        for subscription in subscriptions {
            subscription.request(demand)
        }
    }

    /// Sends one value downstream, adds whatever demand it returned, and passes that
    /// demand on to every upstream, the same rule as `request(_:)`.
    private func deliver(_ value: Output) {
        let additionalDemand = downstream.receive(value)
        guard additionalDemand > .none else { return }
        lock.lock()
        downstreamDemand += additionalDemand
        let subscriptions = upstreamSubscriptions
        lock.unlock()
        for subscription in subscriptions {
            subscription.request(additionalDemand)
        }
    }

    func cancel() {
        lock.lock()
        isDownstreamSubscribed = false
        guard case .terminated = state else {
            state = .terminated
            let subscriptions = upstreamSubscriptions
            upstreamSubscriptions = []
            lock.unlock()
            for subscription in subscriptions {
                subscription.cancel()
            }
            return
        }
        lock.unlock()
    }

    // MARK: Subscriber

    func receive(subscription: Subscription) {
        lock.lock()
        guard case .awaitingSubscriptions = state else {
            lock.unlock()
            subscription.cancel()
            return
        }
        upstreamSubscriptions.append(subscription)
        receivedUpstreamCount += 1
        // No upstream is asked for anything as it arrives: the demand a merged publisher
        // passes on is the downstream's, and it arrives with the downstream's first
        // request. A publisher that sends at subscription time holds its value until it is
        // asked, which is what every publisher in this module does.
        let isTheLast = receivedUpstreamCount == expectedUpstreamCount
        if isTheLast {
            state = .active
            isDownstreamSubscribed = true
        }
        // Every upstream that has already finished by the time the last one arrives has
        // been counted, and the merged publisher is through before it has even been
        // subscribed to downstream.
        let isThrough = isTheLast && remainingUpstreamCount == 0
        lock.unlock()
        guard isTheLast else { return }
        // The downstream learns of the subscription only once every upstream has arrived.
        downstream.receive(subscription: self)
        if isThrough {
            lock.lock()
            state = .terminated
            lock.unlock()
            downstream.receive(completion: .finished)
        }
    }

    func receive(_ input: Output) -> Subscribers.Demand {
        lock.lock()
        guard case .active = state else {
            // Before every upstream has arrived the merged publisher is not yet
            // subscribed downstream and has asked for nothing; a publisher that sends
            // anyway is refused by its own contract.
            lock.unlock()
            return .none
        }
        guard downstreamDemand > .none else {
            // Demand asked for and spent: a value with none behind it is dropped, which is
            // what Apple's documentation for the operator says it does.
            lock.unlock()
            return .none
        }
        downstreamDemand -= 1
        lock.unlock()
        deliver(input)
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        switch completion {
        case .failure(let error):
            guard case .terminated = state else {
                state = .terminated
                let subscriptions = upstreamSubscriptions
                upstreamSubscriptions = []
                lock.unlock()
                for subscription in subscriptions {
                    subscription.cancel()
                }
                downstream.receive(completion: .failure(error))
                return
            }
            lock.unlock()
        case .finished:
            // One object is the subscriber of every upstream, so a completion does not
            // say which upstream sent it; the merged publisher only ever needs to know
            // that one more of them is done. A subscription that has already finished
            // stays in the list until cancellation, which is a no-op on it.
            remainingUpstreamCount -= 1
            // The downstream is told the stream finished only once every upstream has
            // finished *and* it has been told about the subscription: an upstream that
            // sends and finishes at subscription time is through before the others have
            // arrived, and the completion waits for the rest.
            guard case .active = state, remainingUpstreamCount == 0,
                  isDownstreamSubscribed else {
                lock.unlock()
                return
            }
            state = .terminated
            lock.unlock()
            downstream.receive(completion: .finished)
        }
    }
}

// MARK: - Publishers.CombineLatest

/// What the combined publisher needs to know about one of its upstreams, whatever that
/// upstream's output type is: whether it holds a value, and the subscription it arrived
/// on. The value itself is read by the arity, which knows the type.
internal protocol CombineLatestChildProtocol: Subscriber {
    var hasValue: Bool { get }
    var upstream: Subscription? { get }
}

/// The subscriber handed to one upstream of a `combineLatest` publisher. It keeps that
/// upstream's most recent value and asks for one value at a time.
internal final class CombineLatestChild<ChildInput, CombinedOutput, CombinedFailure: Error,
                                      Downstream: Subscriber>: CombineLatestChildProtocol
    where Downstream.Input == CombinedOutput, Downstream.Failure == CombinedFailure
{
    typealias Input = ChildInput

    typealias Failure = CombinedFailure

    private let parent: CombineLatestInner<CombinedOutput, CombinedFailure, Downstream>
    private var value: ChildInput?
    private var subscription: Subscription?

    var hasValue: Bool { return value != nil }

    var upstream: Subscription? { return subscription }

    init(parent: CombineLatestInner<CombinedOutput, CombinedFailure, Downstream>) {
        self.parent = parent
    }

    /// The value this upstream has most recently sent. It stays: the next value from any
    /// upstream combines again with what the others sent last.
    func takeValue() -> ChildInput {
        guard let value = value else { fatalError("CombineLatestChild: no value to take") }
        return value
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
        parent.childDidSubscribe(subscription)
    }

    func receive(_ input: ChildInput) -> Subscribers.Demand {
        value = input
        parent.childDidReceiveValue(self)
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        parent.child(self, didReceive: completion)
    }
}

/// The subscription a `combineLatest` publisher hands downstream. It holds the most
/// recent value of each upstream and combines them as soon as every upstream has sent
/// one.
internal class CombineLatestInner<Output, Failure: Error, Downstream: Subscriber>: Subscription
    where Downstream.Input == Output, Downstream.Failure == Failure
{
    private let lock = UnfairLock.allocate()
    private let downstream: Downstream
    private var children: [any CombineLatestChildProtocol] = []
    private var expectedUpstreamCount: Int
    private var receivedUpstreamCount = 0
    private var remainingUpstreamCount: Int
    private var isDownstreamSubscribed = false
    private var downstreamDemand: Subscribers.Demand = .none
    private var isTerminated = false

    init(downstream: Downstream, upstreamCount: Int) {
        self.downstream = downstream
        self.expectedUpstreamCount = upstreamCount
        self.remainingUpstreamCount = upstreamCount
    }

    /// Subscribes to one upstream through a child of its own, and returns the child so
    /// that the arity can read the value it holds when it combines.
    internal func connectChild<Upstream: Publisher>(_ upstream: Upstream)
        -> CombineLatestChild<Upstream.Output, Output, Failure, Downstream>
        where Upstream.Failure == Failure
    {
        let child = CombineLatestChild<Upstream.Output, Output, Failure, Downstream>(parent: self)
        children.append(child)
        upstream.subscribe(child)
        return child
    }

    deinit {
        lock.deallocate()
    }

    /// The combined value. Written out per arity, because the tuple is what the
    /// publisher's `Output` is.
    func combinedValue() -> Output {
        abstractMethod()
    }

    // MARK: Subscription

    func request(_ demand: Subscribers.Demand) {
        lock.lock()
        guard !isTerminated, demand > .none else {
            lock.unlock()
            return
        }
        downstreamDemand += demand
        let isSendable = isDownstreamSubscribed && hasCombinedValue
        lock.unlock()
        // Each upstream is asked for one value each time the downstream asks, and not
        // again after a combination is sent. Measured against the host's own Combine: a
        // downstream that asked for one value leaves each upstream having been asked for
        // one, not two.
        for child in children {
            child.upstream?.request(.max(1))
        }
        // A combination can only be sent once the downstream has asked for one. The
        // upstreams each hold a single value meanwhile, which is the buffer of one the
        // operator's documentation describes; nothing is lost while it waits.
        if isSendable {
            sendCombinedValueIfPossible()
        }
    }

    func cancel() {
        lock.lock()
        guard !isTerminated else {
            lock.unlock()
            return
        }
        isTerminated = true
        let subscriptions = children.compactMap { $0.upstream }
        lock.unlock()
        for subscription in subscriptions {
            subscription.cancel()
        }
    }

    // MARK: The children

    fileprivate func childDidSubscribe(_ subscription: Subscription) {
        lock.lock()
        guard !isTerminated else {
            lock.unlock()
            subscription.cancel()
            return
        }
        receivedUpstreamCount += 1
        guard receivedUpstreamCount == expectedUpstreamCount else {
            lock.unlock()
            return
        }
        isDownstreamSubscribed = true
        lock.unlock()
        downstream.receive(subscription: self)
    }

    fileprivate func childDidReceiveValue(_ child: any CombineLatestChildProtocol) {
        lock.lock()
        guard !isTerminated, isDownstreamSubscribed, hasCombinedValue, downstreamDemand > .none else {
            lock.unlock()
            return
        }
        lock.unlock()
        sendCombinedValueIfPossible()
    }

    fileprivate func child(_ child: any CombineLatestChildProtocol,
                           didReceive completion: Subscribers.Completion<Failure>) {
        lock.lock()
        switch completion {
        case .failure(let error):
            guard !isTerminated else {
                lock.unlock()
                return
            }
            isTerminated = true
            let subscriptions = children.compactMap { $0.upstream }
            lock.unlock()
            for subscription in subscriptions {
                subscription.cancel()
            }
            downstream.receive(completion: .failure(error))
        case .finished:
            remainingUpstreamCount -= 1
            guard !isTerminated, remainingUpstreamCount > 0 else {
                isTerminated = true
                lock.unlock()
                downstream.receive(completion: .finished)
                return
            }
            lock.unlock()
        }
    }

    private var hasCombinedValue: Bool {
        return children.allSatisfy { $0.hasValue }
    }

    private func sendCombinedValueIfPossible() {
        lock.lock()
        guard !isTerminated, isDownstreamSubscribed,
              downstreamDemand > .none, hasCombinedValue else {
            lock.unlock()
            return
        }
        let value = combinedValue()
        downstreamDemand -= 1
        // The values stay: the next value from any upstream combines again with what the
        // others sent last. Each upstream is asked for one more, and only while the
        // downstream still wants values - measured against the host, a downstream that
        // asked for one value leaves each upstream having been asked for exactly one.
        let isWantedAgain = downstreamDemand > .none
        let children = self.children
        lock.unlock()
        let additionalDemand = downstream.receive(value)
        lock.lock()
        downstreamDemand += additionalDemand
        let isStillWanted = downstreamDemand > .none
        lock.unlock()
        if isWantedAgain || isStillWanted {
            for child in children {
                child.upstream?.request(.max(1))
            }
        }
    }
}
