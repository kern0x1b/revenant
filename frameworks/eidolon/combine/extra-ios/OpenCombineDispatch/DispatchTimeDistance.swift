import Dispatch

extension DispatchTime {
    func distance(to other: DispatchTime) -> DispatchTimeInterval {
        fatalError("DispatchTime.distance(to:) is iOS 15 overlay API; OpenCombine takes its polyfill below iOS 15")
    }
}
