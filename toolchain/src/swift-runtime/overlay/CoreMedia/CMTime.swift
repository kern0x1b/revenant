@_exported import CoreMedia

extension CMTime {
    public init(seconds: Float64, preferredTimescale: CMTimeScale) {
        self = CMTimeMakeWithSeconds(seconds, preferredTimescale: preferredTimescale)
    }
}

extension CMTime: Equatable, Comparable, Hashable {
    public static func == (time1: CMTime, time2: CMTime) -> Bool {
        CMTimeCompare(time1, time2) == 0
    }

    public static func < (time1: CMTime, time2: CMTime) -> Bool {
        CMTimeCompare(time1, time2) < 0
    }

    public func hash(into hasher: inout Hasher) {
        guard flags.contains(.valid), flags.intersection(.impliedValueFlagsMask).isEmpty, timescale != 0 else {
            hasher.combine(0)
            return
        }
        let magnitude = value.magnitude
        let scale = UInt64(timescale.magnitude)
        var a = magnitude
        var b = scale
        while b != 0 {
            (a, b) = (b, a % b)
        }
        hasher.combine(epoch)
        hasher.combine(magnitude != 0 && ((value < 0) != (timescale < 0)))
        hasher.combine(magnitude / a)
        hasher.combine(scale / a)
    }
}

extension CMTimeRange: Equatable, Hashable {
    public static func == (range1: CMTimeRange, range2: CMTimeRange) -> Bool {
        CMTimeRangeEqual(range1, range2)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(duration)
    }
}
