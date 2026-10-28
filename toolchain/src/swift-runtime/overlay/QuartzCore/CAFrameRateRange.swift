import QuartzCore

extension CAFrameRateRange: Equatable {
    public static func == (lhs: CAFrameRateRange, rhs: CAFrameRateRange) -> Bool {
        return lhs.minimum == rhs.minimum && lhs.maximum == rhs.maximum && lhs.preferred == rhs.preferred
    }
}
