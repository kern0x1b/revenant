//
//  EquatableHashableAndCodable.swift
//
//  The equality and hashing that Apple's `Combine` declares out in the open, and that a
//  compiler would otherwise derive: the interface of a framework prints a derived `==`,
//  `hash(into:)` and `hashValue` under their public names, so they are written here with
//  the labels, the constraints and the comparison Apple's own declarations use.
//
//  One rule decides what each `==` compares, and it comes from Apple's declarations: the
//  constraints in the signature are Apple's, and so is the set of stored properties the
//  comparison looks at. Where Apple compares only the upstream of a publisher that holds
//  more - `Drop`'s count, `CollectByCount`'s count, `Retry`'s retries, `Output`'s range,
//  `SetFailureType`'s failure, `Contains`'s output - this does the same, so that code
//  written against Apple gets Apple's answer. Each of those is named in
//  `facts/Combine/CombineKit.md`.
//

import CombineHelpers

// MARK: - The types that carry a hash of their own

extension Subscribers.Completion {

    public static func == (a: Subscribers.Completion<Failure>, b: Subscribers.Completion<Failure>) -> Bool
        where Failure: Equatable
    {
        switch (a, b) {
        case (.finished, .finished):
            return true
        case let (.failure(lhs), .failure(rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) where Failure: Hashable {
        switch self {
        case .finished:
            hasher.combine(0)
        case .failure(let error):
            hasher.combine(1)
            hasher.combine(error)
        }
    }
}

extension Subscribers.Completion where Failure: Hashable {

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

// `Publishers.PrefetchStrategy` holds no payload, so its two cases are told apart by
// which one they are. The fork already declares the `Equatable` and `Hashable`
// conformances; only the printed names were missing.
extension Publishers.PrefetchStrategy {

    public static func == (a: Publishers.PrefetchStrategy, b: Publishers.PrefetchStrategy) -> Bool {
        switch (a, b) {
        case (.keepFull, .keepFull), (.byRequest, .byRequest):
            return true
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .keepFull:
            hasher.combine(0)
        case .byRequest:
            hasher.combine(1)
        }
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}


// MARK: - The publishers
//
// The fork already declares the `Equatable` conformance of every one of these, so only
// the operator is written here, under the constraints Apple's own declarations give it.

extension Empty {

    public static func == (lhs: Empty<Output, Failure>, rhs: Empty<Output, Failure>) -> Bool
    {
        return true
    }
}

extension Fail {

    public static func == (lhs: Fail<Output, Failure>, rhs: Fail<Output, Failure>) -> Bool
        where Failure: Equatable
    {
        return lhs.error == rhs.error
    }
}

extension Just {

    public static func == (lhs: Just<Output>, rhs: Just<Output>) -> Bool
        where Output: Equatable
    {
        return lhs.output == rhs.output
    }
}

extension Publishers.Collect {

    public static func == (lhs: Publishers.Collect<Upstream>, rhs: Publishers.Collect<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.CollectByCount {

    public static func == (lhs: Publishers.CollectByCount<Upstream>, rhs: Publishers.CollectByCount<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream && lhs.count == rhs.count
    }
}

extension Publishers.Concatenate {

    public static func == (lhs: Publishers.Concatenate<Prefix, Suffix>, rhs: Publishers.Concatenate<Prefix, Suffix>) -> Bool
        where Prefix: Equatable, Suffix: Equatable
    {
        return lhs.prefix == rhs.prefix && lhs.suffix == rhs.suffix
    }
}

extension Publishers.Contains {

    public static func == (lhs: Publishers.Contains<Upstream>, rhs: Publishers.Contains<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.Count {

    public static func == (lhs: Publishers.Count<Upstream>, rhs: Publishers.Count<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.Drop {

    public static func == (lhs: Publishers.Drop<Upstream>, rhs: Publishers.Drop<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream && lhs.count == rhs.count
    }
}

extension Publishers.DropUntilOutput {

    public static func == (lhs: Publishers.DropUntilOutput<Upstream, Other>, rhs: Publishers.DropUntilOutput<Upstream, Other>) -> Bool
        where Upstream: Equatable, Other: Equatable
    {
        return lhs.upstream == rhs.upstream && lhs.other == rhs.other
    }
}

extension Publishers.First {

    public static func == (lhs: Publishers.First<Upstream>, rhs: Publishers.First<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.IgnoreOutput {

    public static func == (lhs: Publishers.IgnoreOutput<Upstream>, rhs: Publishers.IgnoreOutput<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.Last {

    public static func == (lhs: Publishers.Last<Upstream>, rhs: Publishers.Last<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.Output {

    public static func == (lhs: Publishers.Output<Upstream>, rhs: Publishers.Output<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
            && lhs.range.lowerBound == rhs.range.lowerBound
            && lhs.range.upperBound == rhs.range.upperBound
    }
}

extension Publishers.ReplaceEmpty {

    public static func == (lhs: Publishers.ReplaceEmpty<Upstream>, rhs: Publishers.ReplaceEmpty<Upstream>) -> Bool
        where Upstream: Equatable, Upstream.Output: Equatable
    {
        return lhs.upstream == rhs.upstream && lhs.output == rhs.output
    }
}

extension Publishers.ReplaceError {

    public static func == (lhs: Publishers.ReplaceError<Upstream>, rhs: Publishers.ReplaceError<Upstream>) -> Bool
        where Upstream: Equatable, Upstream.Output: Equatable
    {
        return lhs.upstream == rhs.upstream && lhs.output == rhs.output
    }
}

extension Publishers.Retry {

    public static func == (lhs: Publishers.Retry<Upstream>, rhs: Publishers.Retry<Upstream>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream && lhs.retries == rhs.retries
    }
}

extension Publishers.Sequence {

    public static func == (lhs: Publishers.Sequence<Elements, Failure>, rhs: Publishers.Sequence<Elements, Failure>) -> Bool
        where Elements: Equatable
    {
        return lhs.sequence == rhs.sequence
    }
}

extension Publishers.SetFailureType {

    public static func == (lhs: Publishers.SetFailureType<Upstream, Failure>, rhs: Publishers.SetFailureType<Upstream, Failure>) -> Bool
        where Upstream: Equatable
    {
        return lhs.upstream == rhs.upstream
    }
}

extension Publishers.Zip {

    public static func == (lhs: Publishers.Zip<UpstreamA, UpstreamB>, rhs: Publishers.Zip<UpstreamA, UpstreamB>) -> Bool
        where UpstreamA: Equatable, UpstreamB: Equatable
    {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Publishers.Zip3 {

    public static func == (lhs: Publishers.Zip3<UpstreamA, UpstreamB, UpstreamC>, rhs: Publishers.Zip3<UpstreamA, UpstreamB, UpstreamC>) -> Bool
        where UpstreamA: Equatable, UpstreamB: Equatable, UpstreamC: Equatable
    {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

extension Publishers.Zip4 {

    public static func == (lhs: Publishers.Zip4<UpstreamA, UpstreamB, UpstreamC, UpstreamD>, rhs: Publishers.Zip4<UpstreamA, UpstreamB, UpstreamC, UpstreamD>) -> Bool
        where UpstreamA: Equatable, UpstreamB: Equatable, UpstreamC: Equatable, UpstreamD: Equatable
    {
        return lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}

// `Publishers.Zip`, `Publishers.Zip3` and `Publishers.Zip4` are the three publishers the
// fork leaves without an `Equatable` conformance, so the conformance is declared here
// beside the operator.
extension Publishers.Zip3: Equatable where UpstreamA: Equatable,
                                      UpstreamB: Equatable,
                                      UpstreamC: Equatable {}

extension Publishers.Zip4: Equatable where UpstreamA: Equatable,
                                      UpstreamB: Equatable,
                                      UpstreamC: Equatable,
                                      UpstreamD: Equatable {}

extension Publishers.Zip: Equatable where UpstreamA: Equatable, UpstreamB: Equatable {}
