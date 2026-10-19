-- Publisher+Concurrency.swift.gyb as a Lua generator: the template's text, with the loop of its %-lines written as Lua.
-- The output is GENERATED-Publisher+Concurrency.swift, which the Combine target compiles.
local support = import("support", {rootdir = os.scriptdir(), anonymous = true})

local OUT = path.join(os.scriptdir(), "..", "..", "Sources", "Combine", "Concurrency", "GENERATED-Publisher+Concurrency.swift")

local out, env = {}, {}

local function emit(text)
    out[#out + 1] = support.fill(text, env)
end

env.template_header = support.header()

emit([==[
${template_header}
//
//  Publisher+Concurrency.swift
// 
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
]==])
local instantiations = {{"AsyncPublisher", false}, {"AsyncThrowingPublisher", true}}
for _, variant in ipairs(instantiations) do
    local instantiation, throwing = variant[1], variant[2]
    env.instantiation = instantiation
    env.where_clause = throwing and "" or "where Failure == Never "
    env.article = throwing and "a throwing" or "an"
    env.throws_keyword = throwing and "throws " or ""
    env.try_keyword = throwing and "try " or ""
    env.terminal_error = throwing and "(Error?)" or ""
    env.failure = throwing and "Error" or "Never"
    env.terminal_nil = throwing and "(nil)" or ""
    env.throwing_infix = throwing and "Throwing" or ""

    emit([==[
extension Publisher ${where_clause}{

    /// The elements produced by the publisher, as ${article} asynchronous sequence.
    ///
    /// This property provides an `${instantiation}`, which allows you to use
    /// the Swift `async`-`await` syntax to receive the publisher's elements.
    /// Because `AsyncPublisher` conforms to `AsyncSequence`, you iterate over its
    /// elements with a `for`-`await`-`in` loop, rather than attaching a subscriber.
]==])
    if throwing then
        emit([==[
    /// If the publisher terminates with an error, the awaiting caller receives the error
    /// as a `throw`.
]==])
    end
    emit([==[
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var values: ${instantiation}<Self> {
        return .init(self)
    }
}

/// A publisher that exposes its elements as ${article} asynchronous sequence.
///
/// `${instantiation}` conforms to `AsyncSequence`, which allows callers to receive
/// values with the `for`-`await`-`in` syntax, rather than attaching a `Subscriber`.
]==])
    if throwing then
        emit([==[
/// If the upstream publisher terminates with an error, `${instantiation}` throws
/// the error to the awaiting caller.
]==])
    end
    emit([==[
///
/// Use the `values` property of the `Publisher` protocol to wrap an existing publisher
/// with an instance of this type.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct ${instantiation}<Upstream: Publisher>: AsyncSequence
]==])
    if not throwing then
        emit([==[
    where Upstream.Failure == Never
]==])
    end
    emit([==[
{

    public typealias Element = Upstream.Output

    /// The iterator that produces elements of the asynchronous publisher sequence.
    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        /// Produces the next element in the prefix sequence.
        ///
        /// - Returns: The next published element, or `nil` if the publisher finishes
        ///   normally.
]==])
    if throwing then
        emit([==[
        ///   If the publisher terminates with an error, the call point receives
        ///   the error as a `throw`.
]==])
    end
    emit([==[
        public mutating func next() async ${throws_keyword}-> Element? {
            return ${try_keyword}await withTaskCancellationHandler(
                operation: { [inner] in ${try_keyword}await inner.next() },
                onCancel: { [inner] in inner.cancel() }
            )
        }
    }

    /// The type of asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    /// Creates a publisher that exposes elements received from an upstream publisher as
]==])
    if throwing then
        emit([==[
    /// an asynchronous sequence.
]==])
    else
        emit([==[
    /// a throwing asynchronous sequence.
]==])
    end
    emit([==[
    ///
    /// - Parameter publisher: An upstream publisher. The asynchronous publisher converts
    ///   elements received from this publisher into an asynchronous sequence.
    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    /// Creates the asynchronous iterator that produces elements of this asynchronous
    /// sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce elements of
    ///   the asynchronous sequence.
    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension ${instantiation}.Iterator {

    fileprivate final class Inner: Subscriber, Cancellable {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private enum State {
            case awaitingSubscription
            case subscribed(Subscription)
            case terminal${terminal_error}
        }

        private let lock = UnfairLock.allocate()
        private var pending: [UnsafeContinuation<Input?, ${failure}>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none

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
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            lock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                let pending = self.pending.take()
                lock.unlock()
                pending.resumeAllWithNil()
                return .none
            }
            precondition(!pending.isEmpty, "Received an output without requesting demand")
            let continuation = pending.removeFirst()
            lock.unlock()
            continuation.resume(returning: input)
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
]==])
    if throwing then
        emit([==[
            switch state {
            case .awaitingSubscription, .subscribed:
                if let continuation = pending.first {
                    state = .terminal(nil)
                    let remaining = pending.take().dropFirst()
                    lock.unlock()
                    switch completion {
                    case .finished:
                        continuation.resume(returning: nil)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    remaining.resumeAllWithNil()
                } else {
                    state = .terminal(completion.failure)
                    lock.unlock()
                }
            case .terminal:
                let pending = self.pending.take()
                lock.unlock()
                pending.resumeAllWithNil()
            }
]==])
    else
        emit([==[
            state = .terminal
            let pending = self.pending.take()
            lock.unlock()
            pending.resumeAllWithNil()
]==])
    end
    emit([==[
        }

        func cancel() {
            lock.lock()
            let pending = self.pending.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal${terminal_nil}
                lock.unlock()
                pending.resumeAllWithNil()
                return
            }
            state = .terminal${terminal_nil}
            lock.unlock()
            subscription.cancel()
            pending.resumeAllWithNil()
        }

        fileprivate func next() async ${throws_keyword}-> Input? {
            return ${try_keyword}await withUnsafe${throwing_infix}Continuation { continuation in
                lock.lock()
                switch state {
                case .awaitingSubscription:
                    pending.append(continuation)
                    pendingDemand += 1
                    lock.unlock()
                case .subscribed(let subscription):
                    pending.append(continuation)
                    lock.unlock()
                    subscription.request(.max(1))
                case .terminal${terminal_nil}:
                    lock.unlock()
                    continuation.resume(returning: nil)
]==])
    if throwing then
        emit([==[
                case .terminal(let error?):
                    state = .terminal(nil)
                    lock.unlock()
                    continuation.resume(throwing: error)
]==])
    end
    emit([==[
                }
            }
        }
    }
}
]==])
end
emit([==[

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Sequence {
    fileprivate func resumeAllWithNil<Output, Failure: Error>()
        where Element == UnsafeContinuation<Output?, Failure>
    {
        for continuation in self {
            continuation.resume(returning: nil)
        }
    }
}
#endif
]==])

support.write(OUT, table.concat(out))
