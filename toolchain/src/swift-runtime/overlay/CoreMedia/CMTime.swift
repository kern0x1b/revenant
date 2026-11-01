@_exported import CoreMedia

extension CMTime {
    public init(seconds: Float64, preferredTimescale: CMTimeScale) {
        self = CMTimeMakeWithSeconds(seconds, preferredTimescale: preferredTimescale)
    }
}
