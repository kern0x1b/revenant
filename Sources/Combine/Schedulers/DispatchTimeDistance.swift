//
//  DispatchTimeDistance.swift
//
//  `DispatchTime.distance(to:)` is an iOS 15 addition to the Dispatch overlay. The
//  scheduler's polyfill calls it on the releases that have it, so the call has to resolve
//  on the releases that do not: this is the same arithmetic, in the largest unit that fits
//  an `Int`. It is marked `@_disfavoredOverload`, so a Dispatch that declares the method
//  itself keeps its own and this one is only chosen where nothing else answers.
//

import Dispatch

extension DispatchTime {

    @_disfavoredOverload
    func distance(to other: DispatchTime) -> DispatchTimeInterval {
        let from = uptimeNanoseconds, to = other.uptimeNanoseconds
        let magnitude = to >= from ? to - from : from - to
        let sign = to >= from ? 1 : -1
        if magnitude <= UInt64(Int.max) { return .nanoseconds(sign * Int(magnitude)) }
        if magnitude / 1_000 <= UInt64(Int.max) { return .microseconds(sign * Int(magnitude / 1_000)) }
        if magnitude / 1_000_000 <= UInt64(Int.max) { return .milliseconds(sign * Int(magnitude / 1_000_000)) }
        return .seconds(sign * Int(min(magnitude / 1_000_000_000, UInt64(Int.max))))
    }
}
