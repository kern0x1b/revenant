#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import "RevenantCarPlay174.h"

@interface CPManeuver (RevenantManeuver174Storage)
- (CPManeuverType)revenant_maneuverType;
- (void)revenant_setManeuverType:(CPManeuverType)type;
- (CPTrafficSide)revenant_trafficSide;
- (void)revenant_setTrafficSide:(CPTrafficSide)side;
- (CPJunctionType)revenant_junctionType;
- (void)revenant_setJunctionType:(CPJunctionType)type;
- (NSMeasurement<NSUnitAngle *> *)revenant_junctionExitAngle;
- (void)revenant_setJunctionExitAngle:(NSMeasurement<NSUnitAngle *> *)angle;
- (NSSet<NSMeasurement<NSUnitAngle *> *> *)revenant_junctionElementAngles;
- (void)revenant_setJunctionElementAngles:(NSSet<NSMeasurement<NSUnitAngle *> *> *)angles;
- (CPLaneGuidance *)revenant_linkedLaneGuidance;
- (void)revenant_setLinkedLaneGuidance:(CPLaneGuidance *)guidance;
- (NSArray<NSString *> *)revenant_roadFollowingManeuverVariants;
- (void)revenant_setRoadFollowingManeuverVariants:(NSArray<NSString *> *)variants;
- (NSString *)revenant_highwayExitLabel;
- (void)revenant_setHighwayExitLabel:(NSString *)label;
@end

@implementation CPManeuver (RevenantManeuver174)

- (CPManeuverType)maneuverType
{
    return [self revenant_maneuverType];
}

- (void)setManeuverType:(CPManeuverType)maneuverType
{
    [self revenant_setManeuverType:maneuverType];
}

- (CPTrafficSide)trafficSide
{
    return [self revenant_trafficSide];
}

- (void)setTrafficSide:(CPTrafficSide)trafficSide
{
    [self revenant_setTrafficSide:trafficSide];
}

- (CPJunctionType)junctionType
{
    return [self revenant_junctionType];
}

- (void)setJunctionType:(CPJunctionType)junctionType
{
    [self revenant_setJunctionType:junctionType];
}

- (NSMeasurement<NSUnitAngle *> *)junctionExitAngle
{
    return [self revenant_junctionExitAngle];
}

- (void)setJunctionExitAngle:(NSMeasurement<NSUnitAngle *> *)junctionExitAngle
{
    [self revenant_setJunctionExitAngle:junctionExitAngle];
}

- (NSSet<NSMeasurement<NSUnitAngle *> *> *)junctionElementAngles
{
    return [self revenant_junctionElementAngles];
}

- (void)setJunctionElementAngles:(NSSet<NSMeasurement<NSUnitAngle *> *> *)junctionElementAngles
{
    [self revenant_setJunctionElementAngles:junctionElementAngles];
}

- (CPLaneGuidance *)linkedLaneGuidance
{
    return [self revenant_linkedLaneGuidance];
}

- (void)setLinkedLaneGuidance:(CPLaneGuidance *)linkedLaneGuidance
{
    [self revenant_setLinkedLaneGuidance:linkedLaneGuidance];
}

- (NSArray<NSString *> *)roadFollowingManeuverVariants
{
    return [self revenant_roadFollowingManeuverVariants];
}

- (void)setRoadFollowingManeuverVariants:(NSArray<NSString *> *)roadFollowingManeuverVariants
{
    [self revenant_setRoadFollowingManeuverVariants:roadFollowingManeuverVariants];
}

- (NSString *)highwayExitLabel
{
    return [self revenant_highwayExitLabel];
}

- (void)setHighwayExitLabel:(NSString *)highwayExitLabel
{
    [self revenant_setHighwayExitLabel:highwayExitLabel];
}

@end
