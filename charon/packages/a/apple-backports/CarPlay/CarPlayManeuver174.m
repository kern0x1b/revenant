// CarPlayManeuver174.m - the eight 17.4 members of CPManeuver, in a 17.4 object of their own.
//
// CPManeuver.h:209-245 declares all eight `API_AVAILABLE(ios(17.4))` and they are the whole of the
// 17.4 API of the class. The class itself is 12.0 and its @implementation is CarPlayTemplates12.m, so
// this is the split CarPlayLane174.m and CarPlayLane18.m make for CPLane: an object holds API of exactly
// one release (modules/apple/backports.lua's releases_in, read by tools/release-split.lua).
//
// The three enumerations the members are typed with are declared in CharonCarPlay174.h, because the build
// SDK is 16.4 and its CPManeuver.h stops at the 15.4 members. The shapes below are Apple's own
// declarations from that header, declarations only - no body comes from there and no Apple's byte is
// copied.
//
// What each member means is what the header says it is, and it is a value the route gave the maneuver:
// the turn it describes (maneuverType), the side of the road the traffic runs on (trafficSide), the kind
// of junction it is at (junctionType) with the angle the exit leaves at and the angles of the junction
// elements themselves, the lane guidance it is linked to, the phrases a road-following maneuver is
// written in, and the label a highway exit carries. A caller sets them from the route it was given and
// reads them back; nothing here derives one from another, because the header does not say one is derived.

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

// :209 `nonatomic, assign`. The zero is CPManeuverTypeNoTurn, which is what Apple's own numbering at
// CPManeuver.h:15 puts at 0, so a maneuver nobody gave a type to is a maneuver with no turn.
- (CPManeuverType)maneuverType
{
    return [self charon_maneuverType];
}

- (void)setManeuverType:(CPManeuverType)maneuverType
{
    [self charon_setManeuverType:maneuverType];
}

// :220 `nonatomic, assign`. The zero is CPTrafficSideRight, which is CPManeuver.h:76's own numbering,
// and a maneuver with no side set is on the right, which is the side this port's own map draws first.
- (CPTrafficSide)trafficSide
{
    return [self charon_trafficSide];
}

- (void)setTrafficSide:(CPTrafficSide)trafficSide
{
    [self charon_setTrafficSide:trafficSide];
}

// :225 `nonatomic, assign`. The zero is CPJunctionTypeIntersection (CPManeuver.h:72).
- (CPJunctionType)junctionType
{
    return [self charon_junctionType];
}

- (void)setJunctionType:(CPJunctionType)junctionType
{
    [self charon_setJunctionType:junctionType];
}

// :230 `copy, nullable` over an angle, so the measurement is kept as given: an NSMeasurement is itself
// immutable, and the copy the header asks for is the one its own unit carries.
- (NSMeasurement<NSUnitAngle *> *)junctionExitAngle
{
    return [self charon_junctionExitAngle];
}

- (void)setJunctionExitAngle:(NSMeasurement<NSUnitAngle *> *)junctionExitAngle
{
    [self charon_setJunctionExitAngle:junctionExitAngle];
}

// :235 `copy, nullable` over a set of angles. The angles are measurements, which are immutable, so the
// set is taken as given: a later change to the caller's set is the header's own business to have made
// unnecessary, and nothing here mutates it.
- (NSSet<NSMeasurement<NSUnitAngle *> *> *)junctionElementAngles
{
    return [self charon_junctionElementAngles];
}

- (void)setJunctionElementAngles:(NSSet<NSMeasurement<NSUnitAngle *> *> *)junctionElementAngles
{
    [self charon_setJunctionElementAngles:junctionElementAngles];
}

// :240 `nonatomic, assign` over a CPLaneGuidance. Assign is the header's own spelling and it is kept: a
// guidance is a value the maneuver points at, not something it owns, and the port holds it the same way
// the header says - without retaining. That is a deliberate reading of `assign`, not an oversight, and a
// caller that wants the guidance to outlive the route holds it itself.
- (CPLaneGuidance *)linkedLaneGuidance
{
    return [self charon_linkedLaneGuidance];
}

- (void)setLinkedLaneGuidance:(CPLaneGuidance *)linkedLaneGuidance
{
    [self charon_setLinkedLaneGuidance:linkedLaneGuidance];
}

// :215 `copy, nullable` over the phrases, so the array is copied on the way in and a later change to the
// caller's array does not change the maneuver's. A nil in is a nil out, which is what `nullable` means.
- (NSArray<NSString *> *)roadFollowingManeuverVariants
{
    return [self charon_roadFollowingManeuverVariants];
}

- (void)setRoadFollowingManeuverVariants:(NSArray<NSString *> *)roadFollowingManeuverVariants
{
    [self charon_setRoadFollowingManeuverVariants:roadFollowingManeuverVariants];
}

// :245 `copy` over the exit's label, copied on the way in for the same reason, and a nil in is a nil out.
- (NSString *)highwayExitLabel
{
    return [self charon_highwayExitLabel];
}

- (void)setHighwayExitLabel:(NSString *)highwayExitLabel
{
    [self charon_setHighwayExitLabel:highwayExitLabel];
}

@end