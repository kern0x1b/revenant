import Dispatch

extension DispatchTime {
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
