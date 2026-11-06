import UIKit
import _SwiftRevenantUIKitOverlayShims

extension UISlider {
    public struct TrackConfiguration: Hashable {
        public struct Tick: Hashable {
            public let position: Float
            public var title: String?
            public var image: UIImage?

            public init(position: Float, title: String? = nil, image: UIImage? = nil) {
                self.position = position
                self.title = title
                self.image = image
            }

            fileprivate init(_ tick: Any) {
                self.init(position: revenantSliderTickPosition(tick), title: revenantSliderTickTitle(tick), image: revenantSliderTickImage(tick))
            }

            fileprivate var objectiveC: AnyObject {
                guard let tick = revenantSliderTick(position: position, title: title, image: image) else {
                    sliderTrackUnavailable()
                }
                return tick
            }
        }

        public var allowsTickValuesOnly: Bool
        public var neutralValue: Float
        public var enabledRange: ClosedRange<Float>
        public let ticks: [Tick]

        public init(allowsTickValuesOnly: Bool = true, neutralValue: Float = 0, enabledRange: ClosedRange<Float> = 0...1, ticks: [Tick]) {
            self.allowsTickValuesOnly = allowsTickValuesOnly
            self.neutralValue = neutralValue
            self.enabledRange = enabledRange
            self.ticks = ticks
        }

        public init(allowsTickValuesOnly: Bool = true, neutralValue: Float = 0, enabledRange: ClosedRange<Float> = 0...1, numberOfTicks: Int) {
            guard let configuration = revenantSliderTrackConfiguration(numberOfTicks: numberOfTicks) else {
                sliderTrackUnavailable()
            }
            self.init(allowsTickValuesOnly: allowsTickValuesOnly, neutralValue: neutralValue, enabledRange: enabledRange,
                      ticks: revenantSliderTicks(of: configuration).map { Tick($0) })
        }

        fileprivate init(_ configuration: __UISliderTrackConfiguration) {
            self.init(allowsTickValuesOnly: configuration.allowsTickValuesOnly, neutralValue: configuration.neutralValue,
                      enabledRange: configuration.minimumEnabledValue...configuration.maximumEnabledValue,
                      ticks: revenantSliderTicks(of: configuration).map { Tick($0) })
        }

        fileprivate var objectiveC: __UISliderTrackConfiguration {
            guard let configuration = revenantSliderTrackConfiguration(ticks: ticks.map { $0.objectiveC }) else {
                sliderTrackUnavailable()
            }
            configuration.allowsTickValuesOnly = allowsTickValuesOnly
            configuration.neutralValue = neutralValue
            if enabledRange.lowerBound > configuration.maximumEnabledValue {
                configuration.maximumEnabledValue = enabledRange.upperBound
                configuration.minimumEnabledValue = enabledRange.lowerBound
            } else {
                configuration.minimumEnabledValue = enabledRange.lowerBound
                configuration.maximumEnabledValue = enabledRange.upperBound
            }
            return configuration
        }
    }

    public var trackConfiguration: TrackConfiguration? {
        get {
            guard let configuration = __trackConfiguration else {
                return nil
            }
            return TrackConfiguration(configuration)
        }
        set { __trackConfiguration = newValue?.objectiveC }
    }
}

fileprivate func sliderTrackUnavailable() -> Never {
    preconditionFailure("UISlider.TrackConfiguration is not on this iOS, and the Backports that provide it are not linked")
}
