#ifndef CHARON_CARPLAY_LANE_H
#define CHARON_CARPLAY_LANE_H

#import <Foundation/Foundation.h>
#import "CharonCarPlay174.h"

@interface CPLane (CharonLaneAngles)

- (NSMeasurement<NSUnitAngle *> *)charon_highlightedAngle;
- (void)charon_setHighlightedAngle:(NSMeasurement<NSUnitAngle *> *)angle;
- (NSArray<NSMeasurement<NSUnitAngle *> *> *)charon_angles;
- (void)charon_setAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles;

- (instancetype)initCharonWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
                    highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                          isPreferred:(BOOL)preferred;

@end

#endif
