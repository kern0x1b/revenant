//
//  Publishers.Merge.swift
//
//  `Publishers.Merge` (two upstreams) through `Publishers.Merge8` (eight),
//  `Publishers.MergeMany` and the `merge(with:)` operators that build them. The
//  behaviour is in `MergeKit.swift`; this file is the shape: the stored upstreams,
//  the initializers, the chaining that grows one merged publisher into the next,
//  and the equality Apple declares for each of them.
//

extension Publishers {

    /// A publisher created by applying the `merge` function to two upstream publishers.
    public struct Merge<A: Publisher, B: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

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
            where B.Failure == Downstream.Failure, B.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 2)
            a.subscribe(inner)
            b.subscribe(inner)
        }

        public func merge<O1>(with o1: O1) -> Publishers.Merge3<A, B, O1>
            where O1: Publisher, B.Failure == O1.Failure, B.Output == O1.Output
        {
            return Publishers.Merge3<A, B, O1>(a, b, o1)
        }

        public func merge<O1, O2>(with o1: O1, _ o2: O2) -> Publishers.Merge4<A, B, O1, O2>
            where O1: Publisher, O2: Publisher, B.Failure == O1.Failure, B.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output
        {
            return Publishers.Merge4<A, B, O1, O2>(a, b, o1, o2)
        }

        public func merge<O1, O2, O3>(with o1: O1, _ o2: O2, _ o3: O3) -> Publishers.Merge5<A, B, O1, O2, O3>
            where O1: Publisher, O2: Publisher, O3: Publisher, B.Failure == O1.Failure, B.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output
        {
            return Publishers.Merge5<A, B, O1, O2, O3>(a, b, o1, o2, o3)
        }

        public func merge<O1, O2, O3, O4>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Publishers.Merge6<A, B, O1, O2, O3, O4>
            where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, B.Failure == O1.Failure, B.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output
        {
            return Publishers.Merge6<A, B, O1, O2, O3, O4>(a, b, o1, o2, o3, o4)
        }

        public func merge<O1, O2, O3, O4, O5>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Publishers.Merge7<A, B, O1, O2, O3, O4, O5>
            where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, O5: Publisher, B.Failure == O1.Failure, B.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output, O4.Failure == O5.Failure, O4.Output == O5.Output
        {
            return Publishers.Merge7<A, B, O1, O2, O3, O4, O5>(a, b, o1, o2, o3, o4, o5)
        }

        public func merge<O1, O2, O3, O4, O5, O6>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Publishers.Merge8<A, B, O1, O2, O3, O4, O5, O6>
            where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, O5: Publisher, O6: Publisher, B.Failure == O1.Failure, B.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output, O4.Failure == O5.Failure, O4.Output == O5.Output, O5.Failure == O6.Failure, O5.Output == O6.Output
        {
            return Publishers.Merge8<A, B, O1, O2, O3, O4, O5, O6>(a, b, o1, o2, o3, o4, o5, o6)
        }
    }

    /// A publisher created by applying the `merge` function to three upstream publishers.
    public struct Merge3<A: Publisher, B: Publisher, C: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output,
              B.Failure == C.Failure,
              B.Output == C.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

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
            where C.Failure == Downstream.Failure, C.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 3)
            a.subscribe(inner)
            b.subscribe(inner)
            c.subscribe(inner)
        }

        public func merge<O1>(with o1: O1) -> Publishers.Merge4<A, B, C, O1>
            where O1: Publisher, C.Failure == O1.Failure, C.Output == O1.Output
        {
            return Publishers.Merge4<A, B, C, O1>(a, b, c, o1)
        }

        public func merge<O1, O2>(with o1: O1, _ o2: O2) -> Publishers.Merge5<A, B, C, O1, O2>
            where O1: Publisher, O2: Publisher, C.Failure == O1.Failure, C.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output
        {
            return Publishers.Merge5<A, B, C, O1, O2>(a, b, c, o1, o2)
        }

        public func merge<O1, O2, O3>(with o1: O1, _ o2: O2, _ o3: O3) -> Publishers.Merge6<A, B, C, O1, O2, O3>
            where O1: Publisher, O2: Publisher, O3: Publisher, C.Failure == O1.Failure, C.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output
        {
            return Publishers.Merge6<A, B, C, O1, O2, O3>(a, b, c, o1, o2, o3)
        }

        public func merge<O1, O2, O3, O4>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Publishers.Merge7<A, B, C, O1, O2, O3, O4>
            where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, C.Failure == O1.Failure, C.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output
        {
            return Publishers.Merge7<A, B, C, O1, O2, O3, O4>(a, b, c, o1, o2, o3, o4)
        }

        public func merge<O1, O2, O3, O4, O5>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Publishers.Merge8<A, B, C, O1, O2, O3, O4, O5>
            where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, O5: Publisher, C.Failure == O1.Failure, C.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output, O4.Failure == O5.Failure, O4.Output == O5.Output
        {
            return Publishers.Merge8<A, B, C, O1, O2, O3, O4, O5>(a, b, c, o1, o2, o3, o4, o5)
        }
    }

    /// A publisher created by applying the `merge` function to four upstream publishers.
    public struct Merge4<A: Publisher, B: Publisher, C: Publisher, D: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output,
              B.Failure == C.Failure,
              B.Output == C.Output,
              C.Failure == D.Failure,
              C.Output == D.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

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
            where D.Failure == Downstream.Failure, D.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 4)
            a.subscribe(inner)
            b.subscribe(inner)
            c.subscribe(inner)
            d.subscribe(inner)
        }

        public func merge<O1>(with o1: O1) -> Publishers.Merge5<A, B, C, D, O1>
            where O1: Publisher, D.Failure == O1.Failure, D.Output == O1.Output
        {
            return Publishers.Merge5<A, B, C, D, O1>(a, b, c, d, o1)
        }

        public func merge<O1, O2>(with o1: O1, _ o2: O2) -> Publishers.Merge6<A, B, C, D, O1, O2>
            where O1: Publisher, O2: Publisher, D.Failure == O1.Failure, D.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output
        {
            return Publishers.Merge6<A, B, C, D, O1, O2>(a, b, c, d, o1, o2)
        }

        public func merge<O1, O2, O3>(with o1: O1, _ o2: O2, _ o3: O3) -> Publishers.Merge7<A, B, C, D, O1, O2, O3>
            where O1: Publisher, O2: Publisher, O3: Publisher, D.Failure == O1.Failure, D.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output
        {
            return Publishers.Merge7<A, B, C, D, O1, O2, O3>(a, b, c, d, o1, o2, o3)
        }

        public func merge<O1, O2, O3, O4>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Publishers.Merge8<A, B, C, D, O1, O2, O3, O4>
            where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, D.Failure == O1.Failure, D.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output
        {
            return Publishers.Merge8<A, B, C, D, O1, O2, O3, O4>(a, b, c, d, o1, o2, o3, o4)
        }
    }

    /// A publisher created by applying the `merge` function to five upstream publishers.
    public struct Merge5<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output,
              B.Failure == C.Failure,
              B.Output == C.Output,
              C.Failure == D.Failure,
              C.Output == D.Output,
              D.Failure == E.Failure,
              D.Output == E.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where E.Failure == Downstream.Failure, E.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 5)
            a.subscribe(inner)
            b.subscribe(inner)
            c.subscribe(inner)
            d.subscribe(inner)
            e.subscribe(inner)
        }

        public func merge<O1>(with o1: O1) -> Publishers.Merge6<A, B, C, D, E, O1>
            where O1: Publisher, E.Failure == O1.Failure, E.Output == O1.Output
        {
            return Publishers.Merge6<A, B, C, D, E, O1>(a, b, c, d, e, o1)
        }

        public func merge<O1, O2>(with o1: O1, _ o2: O2) -> Publishers.Merge7<A, B, C, D, E, O1, O2>
            where O1: Publisher, O2: Publisher, E.Failure == O1.Failure, E.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output
        {
            return Publishers.Merge7<A, B, C, D, E, O1, O2>(a, b, c, d, e, o1, o2)
        }

        public func merge<O1, O2, O3>(with o1: O1, _ o2: O2, _ o3: O3) -> Publishers.Merge8<A, B, C, D, E, O1, O2, O3>
            where O1: Publisher, O2: Publisher, O3: Publisher, E.Failure == O1.Failure, E.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output
        {
            return Publishers.Merge8<A, B, C, D, E, O1, O2, O3>(a, b, c, d, e, o1, o2, o3)
        }
    }

    /// A publisher created by applying the `merge` function to six upstream publishers.
    public struct Merge6<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output,
              B.Failure == C.Failure,
              B.Output == C.Output,
              C.Failure == D.Failure,
              C.Output == D.Output,
              D.Failure == E.Failure,
              D.Output == E.Output,
              E.Failure == F.Failure,
              E.Output == F.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where F.Failure == Downstream.Failure, F.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 6)
            a.subscribe(inner)
            b.subscribe(inner)
            c.subscribe(inner)
            d.subscribe(inner)
            e.subscribe(inner)
            f.subscribe(inner)
        }

        public func merge<O1>(with o1: O1) -> Publishers.Merge7<A, B, C, D, E, F, O1>
            where O1: Publisher, F.Failure == O1.Failure, F.Output == O1.Output
        {
            return Publishers.Merge7<A, B, C, D, E, F, O1>(a, b, c, d, e, f, o1)
        }

        public func merge<O1, O2>(with o1: O1, _ o2: O2) -> Publishers.Merge8<A, B, C, D, E, F, O1, O2>
            where O1: Publisher, O2: Publisher, F.Failure == O1.Failure, F.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output
        {
            return Publishers.Merge8<A, B, C, D, E, F, O1, O2>(a, b, c, d, e, f, o1, o2)
        }
    }

    /// A publisher created by applying the `merge` function to seven upstream publishers.
    public struct Merge7<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output,
              B.Failure == C.Failure,
              B.Output == C.Output,
              C.Failure == D.Failure,
              C.Output == D.Output,
              D.Failure == E.Failure,
              D.Output == E.Output,
              E.Failure == F.Failure,
              E.Output == F.Output,
              F.Failure == G.Failure,
              F.Output == G.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public let g: G

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where G.Failure == Downstream.Failure, G.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 7)
            a.subscribe(inner)
            b.subscribe(inner)
            c.subscribe(inner)
            d.subscribe(inner)
            e.subscribe(inner)
            f.subscribe(inner)
            g.subscribe(inner)
        }

        public func merge<O1>(with o1: O1) -> Publishers.Merge8<A, B, C, D, E, F, G, O1>
            where O1: Publisher, G.Failure == O1.Failure, G.Output == O1.Output
        {
            return Publishers.Merge8<A, B, C, D, E, F, G, O1>(a, b, c, d, e, f, g, o1)
        }
    }

    /// A publisher created by applying the `merge` function to eight upstream publishers.
    public struct Merge8<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher>: Publisher
        where A.Failure == B.Failure,
              A.Output == B.Output,
              B.Failure == C.Failure,
              B.Output == C.Output,
              C.Failure == D.Failure,
              C.Output == D.Output,
              D.Failure == E.Failure,
              D.Output == E.Output,
              E.Failure == F.Failure,
              E.Output == F.Output,
              F.Failure == G.Failure,
              F.Output == G.Output,
              G.Failure == H.Failure,
              G.Output == H.Output
    {
        /// The kind of values published by this publisher.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.

        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public let g: G

        public let h: H

        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
            self.h = h
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where H.Failure == Downstream.Failure, H.Output == Downstream.Input
        {
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber, upstreamCount: 8)
            a.subscribe(inner)
            b.subscribe(inner)
            c.subscribe(inner)
            d.subscribe(inner)
            e.subscribe(inner)
            f.subscribe(inner)
            g.subscribe(inner)
            h.subscribe(inner)
        }
    }

    /// A publisher created by applying the `merge` function to a sequence of publishers.
    public struct MergeMany<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        public let publishers: [Upstream]

        public init(_ upstream: Upstream...) {
            self.publishers = upstream
        }

        public init<S: Swift.Sequence>(_ upstream: S) where Upstream == S.Element {
            self.publishers = upstream.map { $0 }
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input
        {
            guard !publishers.isEmpty else {
                // Nothing upstream can ever finish or fail, so the merged publisher
                // finishes as soon as it is subscribed to.
                Empty<Upstream.Output, Upstream.Failure>(completeImmediately: true)
                    .receive(subscriber: subscriber)
                return
            }
            let inner = MergeInner<Output, Failure, Downstream>(downstream: subscriber,
                                                                upstreamCount: publishers.count)
            for publisher in publishers {
                publisher.subscribe(inner)
            }
        }

        public func merge(with other: Upstream) -> Publishers.MergeMany<Upstream> {
            return Publishers.MergeMany(publishers + [other])
        }
    }
}

// MARK: - The `merge` operators

extension Publisher {

    /// Combines elements from this publisher with those from another publisher,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    public func merge<P>(with other: P) -> Publishers.Merge<Self, P>
        where P: Publisher, Self.Failure == P.Failure, Self.Output == P.Output
    {
        return Publishers.Merge(self, other)
    }

    /// Combines elements from this publisher with those from two other publishers, delivering
    /// an interleaved sequence of elements.
    public func merge<O1, O2>(with o1: O1, _ o2: O2) -> Publishers.Merge3<Self, O1, O2>
        where O1: Publisher, O2: Publisher, Self.Failure == O1.Failure, Self.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output
    {
        return Publishers.Merge3<Self, O1, O2>(self, o1, o2)
    }

    /// Combines elements from this publisher with those from three other publishers, delivering
    /// an interleaved sequence of elements.
    public func merge<O1, O2, O3>(with o1: O1, _ o2: O2, _ o3: O3) -> Publishers.Merge4<Self, O1, O2, O3>
        where O1: Publisher, O2: Publisher, O3: Publisher, Self.Failure == O1.Failure, Self.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output
    {
        return Publishers.Merge4<Self, O1, O2, O3>(self, o1, o2, o3)
    }

    /// Combines elements from this publisher with those from four other publishers, delivering
    /// an interleaved sequence of elements.
    public func merge<O1, O2, O3, O4>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Publishers.Merge5<Self, O1, O2, O3, O4>
        where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, Self.Failure == O1.Failure, Self.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output
    {
        return Publishers.Merge5<Self, O1, O2, O3, O4>(self, o1, o2, o3, o4)
    }

    /// Combines elements from this publisher with those from five other publishers, delivering
    /// an interleaved sequence of elements.
    public func merge<O1, O2, O3, O4, O5>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Publishers.Merge6<Self, O1, O2, O3, O4, O5>
        where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, O5: Publisher, Self.Failure == O1.Failure, Self.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output, O4.Failure == O5.Failure, O4.Output == O5.Output
    {
        return Publishers.Merge6<Self, O1, O2, O3, O4, O5>(self, o1, o2, o3, o4, o5)
    }

    /// Combines elements from this publisher with those from six other publishers, delivering
    /// an interleaved sequence of elements.
    public func merge<O1, O2, O3, O4, O5, O6>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Publishers.Merge7<Self, O1, O2, O3, O4, O5, O6>
        where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, O5: Publisher, O6: Publisher, Self.Failure == O1.Failure, Self.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output, O4.Failure == O5.Failure, O4.Output == O5.Output, O5.Failure == O6.Failure, O5.Output == O6.Output
    {
        return Publishers.Merge7<Self, O1, O2, O3, O4, O5, O6>(self, o1, o2, o3, o4, o5, o6)
    }

    /// Combines elements from this publisher with those from seven other publishers, delivering
    /// an interleaved sequence of elements.
    public func merge<O1, O2, O3, O4, O5, O6, O7>(with o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6, _ o7: O7) -> Publishers.Merge8<Self, O1, O2, O3, O4, O5, O6, O7>
        where O1: Publisher, O2: Publisher, O3: Publisher, O4: Publisher, O5: Publisher, O6: Publisher, O7: Publisher, Self.Failure == O1.Failure, Self.Output == O1.Output, O1.Failure == O2.Failure, O1.Output == O2.Output, O2.Failure == O3.Failure, O2.Output == O3.Output, O3.Failure == O4.Failure, O3.Output == O4.Output, O4.Failure == O5.Failure, O4.Output == O5.Output, O5.Failure == O6.Failure, O5.Output == O6.Output, O6.Failure == O7.Failure, O6.Output == O7.Output
    {
        return Publishers.Merge8<Self, O1, O2, O3, O4, O5, O6, O7>(self, o1, o2, o3, o4, o5, o6, o7)
    }

    /// Combines elements from this publisher with those from another publisher of the
    /// same type, delivering an interleaved sequence of elements.
    public func merge(with other: Self) -> Publishers.MergeMany<Self> {
        return Publishers.MergeMany(self, other)
    }
}

// MARK: - Equality
//
// Apple's declarations constrain the comparison by every upstream, and the tuple of
// upstreams is what the merged publisher is: two merged publishers are equal when
// they merge the same publishers.

extension Publishers.Merge: Equatable where A: Equatable, B: Equatable {

    public static func == (lhs: Publishers.Merge<A, B>, rhs: Publishers.Merge<A, B>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Publishers.Merge3: Equatable where A: Equatable, B: Equatable, C: Equatable {

    public static func == (lhs: Publishers.Merge3<A, B, C>, rhs: Publishers.Merge3<A, B, C>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

extension Publishers.Merge4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {

    public static func == (lhs: Publishers.Merge4<A, B, C, D>, rhs: Publishers.Merge4<A, B, C, D>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}

extension Publishers.Merge5: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable {

    public static func == (lhs: Publishers.Merge5<A, B, C, D, E>, rhs: Publishers.Merge5<A, B, C, D, E>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e
    }
}

extension Publishers.Merge6: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable {

    public static func == (lhs: Publishers.Merge6<A, B, C, D, E, F>, rhs: Publishers.Merge6<A, B, C, D, E, F>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f
    }
}

extension Publishers.Merge7: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable {

    public static func == (lhs: Publishers.Merge7<A, B, C, D, E, F, G>, rhs: Publishers.Merge7<A, B, C, D, E, F, G>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g
    }
}

extension Publishers.Merge8: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable, H: Equatable {

    public static func == (lhs: Publishers.Merge8<A, B, C, D, E, F, G, H>, rhs: Publishers.Merge8<A, B, C, D, E, F, G, H>) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g && lhs.h == rhs.h
    }
}

extension Publishers.MergeMany: Equatable where Upstream: Equatable {

    public static func == (lhs: Publishers.MergeMany<Upstream>,
                           rhs: Publishers.MergeMany<Upstream>) -> Bool
    {
        return lhs.publishers == rhs.publishers
    }
}
