#import <Foundation/Foundation.h>
#import "CharonCarPlay174.h"
#import "CharonCarPlayLane.h"

@implementation CPLane (CharonLaneAngles18)

- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    return [self initCharonWithAngles:angles highlightedAngle:nil isPreferred:NO];
}

- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
             highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                   isPreferred:(BOOL)preferred
{
    return [self initCharonWithAngles:angles highlightedAngle:highlightedAngle isPreferred:preferred];
}

- (NSMeasurement<NSUnitAngle *> *)highlightedAngle
{
    return [self charon_highlightedAngle];
}

- (NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    return [self charon_angles];
}

@end
