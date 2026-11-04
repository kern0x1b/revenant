import UIKit

@available(tvOS, unavailable)
@available(watchOS, unavailable)
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

            fileprivate init(_ tick: __UISliderTick) {
                self.init(position: tick.position, title: tick.title, image: tick.image)
            }

            fileprivate var objectiveC: __UISliderTick {
                __UISliderTick.tick(position: position, title: title, image: image)
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
            let configuration = __UISliderTrackConfiguration.configuration(numberOfTicks: numberOfTicks)
            self.init(allowsTickValuesOnly: allowsTickValuesOnly, neutralValue: neutralValue, enabledRange: enabledRange,
                      ticks: configuration.ticks.map { Tick($0) })
        }

        fileprivate init(_ configuration: __UISliderTrackConfiguration) {
            self.init(allowsTickValuesOnly: configuration.allowsTickValuesOnly, neutralValue: configuration.neutralValue,
                      enabledRange: configuration.minimumEnabledValue...configuration.maximumEnabledValue,
                      ticks: configuration.ticks.map { Tick($0) })
        }

        fileprivate var objectiveC: __UISliderTrackConfiguration {
            let configuration = __UISliderTrackConfiguration.configuration(ticks: ticks.map { $0.objectiveC })
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
        get { __trackConfiguration.map { TrackConfiguration($0) } }
        set { __trackConfiguration = newValue?.objectiveC }
    }
}
