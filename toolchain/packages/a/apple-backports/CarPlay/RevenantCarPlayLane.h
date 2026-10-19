#ifndef REVENANT_CARPLAY_LANE_H
#define REVENANT_CARPLAY_LANE_H

#import <Foundation/Foundation.h>
#import "RevenantCarPlay174.h"

@interface CPLane (RevenantLaneAngles)

- (NSMeasurement<NSUnitAngle *> *)revenant_highlightedAngle;
- (void)revenant_setHighlightedAngle:(NSMeasurement<NSUnitAngle *> *)angle;
- (NSArray<NSMeasurement<NSUnitAngle *> *> *)revenant_angles;
- (void)revenant_setAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles;

- (instancetype)initRevenantWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
                    highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                          isPreferred:(BOOL)preferred;

@end

#endif
