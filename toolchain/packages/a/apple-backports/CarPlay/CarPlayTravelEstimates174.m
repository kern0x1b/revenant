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
