// CarPlayTravelEstimates174.m - the 17.4 member of CPTravelEstimates and the 17.4 initialiser that fills
// it, in a 17.4 object of their own beside the 12.0 one that defines the class.
//
// CPTravelEstimates.h:44 declares
//     @property (nonatomic, readonly, copy) NSMeasurement<NSUnitLength *> *distanceRemainingToDisplay
//         API_AVAILABLE(ios(17.4))
// and :34 declares
//     - (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distanceRemaining
//                        distanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distanceRemainingToDisplay
//                                     timeRemaining:(NSTimeInterval)time
//         NS_DESIGNATED_INITIALIZER  API_AVAILABLE(ios(17.4))
// Those two are the whole of the 17.4 API of the class. Neither is in the build SDK, which is 16.4, so
// the 17.4 initialiser is declared nowhere in the headers this package compiles against and the object
// does not declare it either: the header's line above is Apple's, read here, and the implementation
// follows it.
//
// What the two are is what the header's own words say: the 12.0 property at :49 is how far is left and the
// 17.4 one at :44 is how much of that to display, which is a display rounding the route applies and the
// caller is the one that knows it. So both are kept as given and neither is computed from the other.

#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

@interface CPTravelEstimates (CharonTravelEstimates174Storage)
- (NSMeasurement<NSUnitLength *> *)charon_distanceRemainingToDisplay;
- (void)charon_setDistanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distance;
@end

@implementation CPTravelEstimates (CharonTravelEstimates174)

- (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distanceRemaining
               distanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distanceRemainingToDisplay
                            timeRemaining:(NSTimeInterval)timeRemaining
{
    // The 12.0 initialiser for the two values it already had, then the 17.4 one through the class's own
    // storage. Both distances are the port's own NSMeasurement of a length in a length unit -
    // libFoundationBackports carries NSUnitLength and NSMeasurement precisely because the release has
    // neither - and both are kept as given, because an NSMeasurement is immutable and the header's own
    // `copy` is the measurement's own.
    self = [self initWithDistanceRemaining:distanceRemaining timeRemaining:timeRemaining];
    if (self) {
        [self charon_setDistanceRemainingToDisplay:distanceRemainingToDisplay];
    }
    return self;
}

- (NSMeasurement<NSUnitLength *> *)distanceRemainingToDisplay
{
    return [self charon_distanceRemainingToDisplay];
}

@end