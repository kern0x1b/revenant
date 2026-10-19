//
//  Publishers.CombineLatest.swift
//
//  `Publishers.CombineLatest` (two upstreams), `Publishers.CombineLatest3`,
//  `Publishers.CombineLatest4` and the `combineLatest` operators that build them. The
//  behaviour is in `MergeKit.swift`; this file is the shape: the stored upstreams,
//  the initializers, and the tuple each arity combines.
//

extension Publishers {

    /// A publisher created by applying the `combineLatest` function to two upstream publishers.
    public struct CombineLatest<A: Publisher, B: Publisher>: Publisher
        where A.Failure == B.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = (A.Output, B.Output)

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where B.Failure == Downstream.Failure, Downstream.Input == (A.Output, B.Output)
        {
            let inner = Inner(downstream: subscriber)
            inner.connect(a, b)
        }

        // The shared inner, declared inside the publisher so that it sees the arity's
        // generic parameters. The behaviour is in `MergeKit.swift`.
        private final class Inner<Downstream: Subscriber>: CombineLatestInner<Output, Failure, Downstream>
            where Downstream.Input == (A.Output, B.Output), Downstream.Failure == Failure
        {
            private var a: CombineLatestChild<A.Output, Output, Failure, Downstream>!
            private var b: CombineLatestChild<B.Output, Output, Failure, Downstream>!

            init(downstream: Downstream) {
                super.init(downstream: downstream, upstreamCount: 2)
            }

            func connect(_ a: A, _ b: B) {
                self.a = connectChild(a)
                self.b = connectChild(b)
            }

            override func combinedValue() -> Output {
                return (a.takeValue(), b.takeValue())
            }
        }
    }

    /// A publisher created by applying the `combineLatest` function to three upstream publishers.
    public struct CombineLatest3<A: Publisher, B: Publisher, C: Publisher>: Publisher
        where A.Failure == B.Failure,
              B.Failure == C.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = (A.Output, B.Output, C.Output)

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where C.Failure == Downstream.Failure, Downstream.Input == (A.Output, B.Output, C.Output)
        {
            let inner = Inner(downstream: subscriber)
            inner.connect(a, b, c)
        }

        // The shared inner, declared inside the publisher so that it sees the arity's
        // generic parameters. The behaviour is in `MergeKit.swift`.
        private final class Inner<Downstream: Subscriber>: CombineLatestInner<Output, Failure, Downstream>
            where Downstream.Input == (A.Output, B.Output, C.Output), Downstream.Failure == Failure
        {
            private var a: CombineLatestChild<A.Output, Output, Failure, Downstream>!
            private var b: CombineLatestChild<B.Output, Output, Failure, Downstream>!
            private var c: CombineLatestChild<C.Output, Output, Failure, Downstream>!

            init(downstream: Downstream) {
                super.init(downstream: downstream, upstreamCount: 3)
            }

            func connect(_ a: A, _ b: B, _ c: C) {
                self.a = connectChild(a)
                self.b = connectChild(b)
                self.c = connectChild(c)
            }

            override func combinedValue() -> Output {
                return (a.takeValue(), b.takeValue(), c.takeValue())
            }
        }
    }

    /// A publisher created by applying the `combineLatest` function to four upstream publishers.
    public struct CombineLatest4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
        where A.Failure == B.Failure,
              B.Failure == C.Failure,
              C.Failure == D.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output)

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where D.Failure == Downstream.Failure, Downstream.Input == (A.Output, B.Output, C.Output, D.Output)
        {
            let inner = Inner(downstream: subscriber)
            inner.connect(a, b, c, d)
        }

        // The shared inner, declared inside the publisher so that it sees the arity's
        // generic parameters. The behaviour is in `MergeKit.swift`.
        private final class Inner<Downstream: Subscriber>: CombineLatestInner<Output, Failure, Downstream>
            where Downstream.Input == (A.Output, B.Output, C.Output, D.Output), Downstream.Failure == Failure
        {
            private var a: CombineLatestChild<A.Output, Output, Failure, Downstream>!
            private var b: CombineLatestChild<B.Output, Output, Failure, Downstream>!
            private var c: CombineLatestChild<C.Output, Output, Failure, Downstream>!
            private var d: CombineLatestChild<D.Output, Output, Failure, Downstream>!

            init(downstream: Downstream) {
                super.init(downstream: downstream, upstreamCount: 4)
            }

            func connect(_ a: A, _ b: B, _ c: C, _ d: D) {
                self.a = connectChild(a)
                self.b = connectChild(b)
                self.c = connectChild(c)
                self.d = connectChild(d)
            }

            override func combinedValue() -> Output {
                return (a.takeValue(), b.takeValue(), c.takeValue(), d.takeValue())
            }
        }
    }

}

// MARK: - Equality
//
// Apple's declarations constrain the comparison by every upstream, and the tuple of
// upstreams is what the combined publisher is.

extension Publishers.CombineLatest: Equatable where A: Equatable, B: Equatable {

    public static func == (lhs: Publishers.CombineLatest<A, B>, rhs: Publishers.CombineLatest<A, B>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Publishers.CombineLatest3: Equatable where A: Equatable, B: Equatable, C: Equatable {

    public static func == (lhs: Publishers.CombineLatest3<A, B, C>, rhs: Publishers.CombineLatest3<A, B, C>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

extension Publishers.CombineLatest4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {

    public static func == (lhs: Publishers.CombineLatest4<A, B, C, D>, rhs: Publishers.CombineLatest4<A, B, C, D>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}

// MARK: - The `combineLatest` operators

extension Publisher {

    /// Subscribes to 1 additional publisher and publishes a tuple upon receiving
    /// output from either publisher.
    ///
    /// The combined publisher holds the most recent value of each upstream and sends a
    /// tuple as soon as every one of them has sent one, so nothing is lost while the
    /// downstream has not asked for the next combination.
    public func combineLatest<P>(_ p: P) -> Publishers.CombineLatest<Self, P>
        where P: Publisher, Self.Failure == P.Failure
    {
        return Publishers.CombineLatest<Self, P>(self, p)
    }

    /// Subscribes to 1 additional publisher and invokes a closure upon receiving
    /// output from either publisher.
    public func combineLatest<P, Result>(_ p: P, _ transform: @escaping (Self.Output, P.Output) -> Result) -> Publishers.Map<Publishers.CombineLatest<Self, P>, Result>
        where P: Publisher, Self.Failure == P.Failure
    {
        return Publishers.Map(upstream: Publishers.CombineLatest<Self, P>(self, p), transform: transform)
    }

    /// Subscribes to 2 additional publishers and publishes a tuple upon receiving
    /// output from any of the publishers.
    ///
    /// The combined publisher holds the most recent value of each upstream and sends a
    /// tuple as soon as every one of them has sent one, so nothing is lost while the
    /// downstream has not asked for the next combination.
    public func combineLatest<P, Q>(_ p: P, _ q: Q) -> Publishers.CombineLatest3<Self, P, Q>
        where P: Publisher, Self.Failure == P.Failure, Q: Publisher, Self.Failure == Q.Failure
    {
        return Publishers.CombineLatest3<Self, P, Q>(self, p, q)
    }

    /// Subscribes to 2 additional publishers and invokes a closure upon receiving
    /// output from any of the publishers.
    public func combineLatest<P, Q, Result>(_ p: P, _ q: Q, _ transform: @escaping (Self.Output, P.Output, Q.Output) -> Result) -> Publishers.Map<Publishers.CombineLatest3<Self, P, Q>, Result>
        where P: Publisher, Self.Failure == P.Failure, Q: Publisher, Self.Failure == Q.Failure
    {
        return Publishers.Map(upstream: Publishers.CombineLatest3<Self, P, Q>(self, p, q), transform: transform)
    }

    /// Subscribes to 3 additional publishers and publishes a tuple upon receiving
    /// output from any of the publishers.
    ///
    /// The combined publisher holds the most recent value of each upstream and sends a
    /// tuple as soon as every one of them has sent one, so nothing is lost while the
    /// downstream has not asked for the next combination.
    public func combineLatest<P, Q, R>(_ p: P, _ q: Q, _ r: R) -> Publishers.CombineLatest4<Self, P, Q, R>
        where P: Publisher, Self.Failure == P.Failure, Q: Publisher, Self.Failure == Q.Failure, R: Publisher, Self.Failure == R.Failure
    {
        return Publishers.CombineLatest4<Self, P, Q, R>(self, p, q, r)
    }

    /// Subscribes to 3 additional publishers and invokes a closure upon receiving
    /// output from any of the publishers.
    public func combineLatest<P, Q, R, Result>(_ p: P, _ q: Q, _ r: R, _ transform: @escaping (Self.Output, P.Output, Q.Output, R.Output) -> Result) -> Publishers.Map<Publishers.CombineLatest4<Self, P, Q, R>, Result>
        where P: Publisher, Self.Failure == P.Failure, Q: Publisher, Self.Failure == Q.Failure, R: Publisher, Self.Failure == R.Failure
    {
        return Publishers.Map(upstream: Publishers.CombineLatest4<Self, P, Q, R>(self, p, q, r), transform: transform)
    }
}
