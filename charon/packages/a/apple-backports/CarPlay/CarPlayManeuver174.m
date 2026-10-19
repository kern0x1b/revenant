#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import "CharonCarPlay174.h"

@interface CPManeuver (CharonManeuver174Storage)
- (CPManeuverType)charon_maneuverType;
- (void)charon_setManeuverType:(CPManeuverType)type;
- (CPTrafficSide)charon_trafficSide;
- (void)charon_setTrafficSide:(CPTrafficSide)side;
- (CPJunctionType)charon_junctionType;
- (void)charon_setJunctionType:(CPJunctionType)type;
- (NSMeasurement<NSUnitAngle *> *)charon_junctionExitAngle;
- (void)charon_setJunctionExitAngle:(NSMeasurement<NSUnitAngle *> *)angle;
- (NSSet<NSMeasurement<NSUnitAngle *> *> *)charon_junctionElementAngles;
- (void)charon_setJunctionElementAngles:(NSSet<NSMeasurement<NSUnitAngle *> *> *)angles;
- (CPLaneGuidance *)charon_linkedLaneGuidance;
- (void)charon_setLinkedLaneGuidance:(CPLaneGuidance *)guidance;
- (NSArray<NSString *> *)charon_roadFollowingManeuverVariants;
- (void)charon_setRoadFollowingManeuverVariants:(NSArray<NSString *> *)variants;
- (NSString *)charon_highwayExitLabel;
- (void)charon_setHighwayExitLabel:(NSString *)label;
@end

@implementation CPManeuver (CharonManeuver174)

- (CPManeuverType)maneuverType
{
    return [self charon_maneuverType];
}

- (void)setManeuverType:(CPManeuverType)maneuverType
{
    [self charon_setManeuverType:maneuverType];
}

- (CPTrafficSide)trafficSide
{
    return [self charon_trafficSide];
}

- (void)setTrafficSide:(CPTrafficSide)trafficSide
{
    [self charon_setTrafficSide:trafficSide];
}

- (CPJunctionType)junctionType
{
    return [self charon_junctionType];
}

- (void)setJunctionType:(CPJunctionType)junctionType
{
    [self charon_setJunctionType:junctionType];
}

- (NSMeasurement<NSUnitAngle *> *)junctionExitAngle
{
    return [self charon_junctionExitAngle];
}

- (void)setJunctionExitAngle:(NSMeasurement<NSUnitAngle *> *)junctionExitAngle
{
    [self charon_setJunctionExitAngle:junctionExitAngle];
}

- (NSSet<NSMeasurement<NSUnitAngle *> *> *)junctionElementAngles
{
    return [self charon_junctionElementAngles];
}

- (void)setJunctionElementAngles:(NSSet<NSMeasurement<NSUnitAngle *> *> *)junctionElementAngles
{
    [self charon_setJunctionElementAngles:junctionElementAngles];
}

- (CPLaneGuidance *)linkedLaneGuidance
{
    return [self charon_linkedLaneGuidance];
}

- (void)setLinkedLaneGuidance:(CPLaneGuidance *)linkedLaneGuidance
{
    [self charon_setLinkedLaneGuidance:linkedLaneGuidance];
}

- (NSArray<NSString *> *)roadFollowingManeuverVariants
{
    return [self charon_roadFollowingManeuverVariants];
}

- (void)setRoadFollowingManeuverVariants:(NSArray<NSString *> *)roadFollowingManeuverVariants
{
    [self charon_setRoadFollowingManeuverVariants:roadFollowingManeuverVariants];
}

- (NSString *)highwayExitLabel
{
    return [self charon_highwayExitLabel];
}

- (void)setHighwayExitLabel:(NSString *)highwayExitLabel
{
    [self charon_setHighwayExitLabel:highwayExitLabel];
}

@end
