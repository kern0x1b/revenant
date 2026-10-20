#import <Foundation/Foundation.h>
#import "RevenantCarPlay174.h"
#import "RevenantCarPlayLane.h"

@implementation CPLane (RevenantLaneAngles18)

- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    return [self initRevenantWithAngles:angles highlightedAngle:nil isPreferred:NO];
}

- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
             highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                   isPreferred:(BOOL)preferred
{
    return [self initRevenantWithAngles:angles highlightedAngle:highlightedAngle isPreferred:preferred];
}

- (NSMeasurement<NSUnitAngle *> *)highlightedAngle
{
    return [self revenant_highlightedAngle];
}

- (NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    return [self revenant_angles];
}

@end
