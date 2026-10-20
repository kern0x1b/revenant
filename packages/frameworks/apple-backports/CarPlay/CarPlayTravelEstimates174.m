#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

@interface CPTravelEstimates (RevenantTravelEstimates174Storage)
- (NSMeasurement<NSUnitLength *> *)revenant_distanceRemainingToDisplay;
- (void)revenant_setDistanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distance;
@end

@implementation CPTravelEstimates (RevenantTravelEstimates174)

- (instancetype)initWithDistanceRemaining:(NSMeasurement<NSUnitLength *> *)distanceRemaining
               distanceRemainingToDisplay:(NSMeasurement<NSUnitLength *> *)distanceRemainingToDisplay
                            timeRemaining:(NSTimeInterval)timeRemaining
{
    self = [self initWithDistanceRemaining:distanceRemaining timeRemaining:timeRemaining];
    if (self) {
        [self revenant_setDistanceRemainingToDisplay:distanceRemainingToDisplay];
    }
    return self;
}

- (NSMeasurement<NSUnitLength *> *)distanceRemainingToDisplay
{
    return [self revenant_distanceRemainingToDisplay];
}

@end
