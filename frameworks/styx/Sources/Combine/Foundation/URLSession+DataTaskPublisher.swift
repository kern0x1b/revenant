//
//  URLSession+DataTaskPublisher.swift
//
//  `URLSession.dataTaskPublisher(for:)` and `URLSession.DataTaskPublisher`: a publisher
//  that runs one data task when it is first asked for a value, and sends the task's one
//  result to its subscriber. The URLSession declarations come from the SDK's Foundation
//  (iOS 7); on iOS 6.1.3 they are supplied at runtime by charon's apple-backports, the same
//  way every application sees them.
//

import Foundation

// The SDK declares URLSession from iOS 7, and so does this file: the publishers exist where
// URLSession does, and a 6.1.3 build sees them through charon's backport.
@available(iOS 7.0, *)
extension URLSession {

    /// Returns a publisher that wraps a URL session data task for a given URL.
    ///
    /// The publisher creates the task when a subscriber first requests a value, and sends
    /// the task's result: its data and response, or the error that ended it.
    ///
    /// - Parameter url: The URL for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL.
    public func dataTaskPublisher(for url: URL) -> DataTaskPublisher {
        return DataTaskPublisher(request: URLRequest(url: url), session: self)
    }

    /// Returns a publisher that wraps a URL session data task for a given URL request.
    ///
    /// - Parameter request: The URL request for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL request.
    public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher {
        return DataTaskPublisher(request: request, session: self)
    }

    /// A publisher that wraps a URL session data task for a given URL request.
    public struct DataTaskPublisher: Publisher {

        /// The kind of values published by this publisher: the data and the response
        /// of the task.
        public typealias Output = (data: Data, response: URLResponse)

        /// The kind of errors this publisher might publish.
        public typealias Failure = URLError

        /// The URL request this publisher runs.
        public let request: URLRequest

        /// The session the data task is created in.
        public let session: URLSession

        /// Creates a publisher that wraps a URL session data task for a given URL request.
        ///
        /// - Parameters:
        ///   - request: The URL request for which to create a data task.
        ///   - session: The session that creates the data task.
        public init(request: URLRequest, session: URLSession) {
            self.request = request
            self.session = session
        }

        public func receive<S: Subscriber>(subscriber: S)
            where S.Input == Output, S.Failure == Failure
        {
            let subscription = Inner(request: request, session: session, downstream: subscriber)
            subscriber.receive(subscription: subscription)
        }
    }
}

@available(iOS 7.0, *)
extension URLSession.DataTaskPublisher {

    /// The subscription a data task publisher hands to its subscriber. It creates and
    /// resumes the task on the first request for a value, sends the task's single result
    /// and finishes, or drops it when cancelled.
    fileprivate final class Inner<Downstream: Subscriber>: Subscription
        where Downstream.Input == Output, Downstream.Failure == Failure
    {
        private let lock = UnfairLock.allocate()
        private let urlRequest: URLRequest
        private let session: URLSession
        private var downstream: Downstream?
        private var task: URLSessionDataTask?
        private var isStarted = false

        init(request: URLRequest, session: URLSession, downstream: Downstream) {
            self.urlRequest = request
            self.session = session
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard !isStarted, demand > .none, downstream != nil else {
                lock.unlock()
                return
            }
            isStarted = true
            let task = session.dataTask(with: urlRequest) { [self] data, response, error in
                deliver(data: data, response: response, error: error)
            }
            self.task = task
            lock.unlock()
            task.resume()
        }

        func cancel() {
            lock.lock()
            downstream = nil
            let task = self.task
            self.task = nil
            lock.unlock()
            task?.cancel()
        }

        /// Sends the task's result downstream, once. A task that was cancelled has no
        /// subscriber left, and its result is dropped.
        private func deliver(data: Data?, response: URLResponse?, error: Error?) {
            lock.lock()
            guard let downstream = downstream else {
                lock.unlock()
                return
            }
            self.downstream = nil
            self.task = nil
            lock.unlock()

            if let error = error {
                downstream.receive(completion: .failure(URLError(_nsError: error as NSError)))
            } else if let response = response {
                // The completion handler may pass a response with nil data. This publisher
                // takes that as an empty body; the choice is not measured against Apple's.
                _ = downstream.receive((data: data ?? Data(), response: response))
                downstream.receive(completion: .finished)
            } else {
                // The handler is documented to pass either an error or a response. Neither
                // is here, so the publisher reports a bad response rather than guessing. This
                // branch is not measured against Apple's behaviour.
                downstream.receive(completion: .failure(URLError(.badServerResponse)))
            }
        }
    }
}
