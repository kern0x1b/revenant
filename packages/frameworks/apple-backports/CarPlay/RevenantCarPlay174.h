#ifndef REVENANT_CARPLAY_174_H
#define REVENANT_CARPLAY_174_H

#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

#if __has_include(<CarPlay/CPLane.h>)

#import <CarPlay/CPLane.h>
#import <CarPlay/CPLaneGuidance.h>
#import <CarPlay/CPRouteInformation.h>

#else

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPLaneStatus) {
    CPLaneStatusNotGood = 0,
    CPLaneStatusGood,
    CPLaneStatusPreferred
};

@interface CPLane : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init;
- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles;
- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
             highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                   isPreferred:(BOOL)preferred;
@property (nonatomic, assign) CPLaneStatus status;
- (void)setStatus:(CPLaneStatus)status;
@property (nonatomic, strong) NSMeasurement<NSUnitAngle *> *primaryAngle;
@property (nonatomic, strong) NSArray<NSMeasurement<NSUnitAngle *> *> *secondaryAngles;
@property (nonatomic, strong, nullable, readonly) NSMeasurement<NSUnitAngle *> *highlightedAngle;
@property (nonatomic, copy, readonly) NSArray<NSMeasurement<NSUnitAngle *> *> *angles;
@end

@interface CPLaneGuidance : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, copy) NSArray<CPLane *> *lanes;
@property (nonatomic, copy) NSArray<NSString *> *instructionVariants;
@end

@interface CPRouteInformation : NSObject
- (instancetype)initWithManeuvers:(NSArray<CPManeuver *> *)maneuvers
                    laneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances
                currentManeuvers:(NSArray<CPManeuver *> *)currentManeuvers
           currentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
             tripTravelEstimates:(CPTravelEstimates *)tripTravelEstimates
        maneuverTravelEstimates:(CPTravelEstimates *)maneuverTravelEstimates;
@property (readonly, nonatomic, copy) NSArray<CPManeuver *> *maneuvers;
@property (readonly, nonatomic, copy) NSArray<CPLaneGuidance *> *laneGuidances;
@property (readonly, nonatomic, copy) NSArray<CPManeuver *> *currentManeuvers;
@property (readonly, nonatomic, copy) CPLaneGuidance *currentLaneGuidance;
@property (readonly, nonatomic, copy) CPTravelEstimates *tripTravelEstimates;
@property (readonly, nonatomic, copy) CPTravelEstimates *maneuverTravelEstimates;
@end

typedef NS_ENUM(NSUInteger, CPManeuverType) {
    CPManeuverTypeNoTurn                    =  0,
    CPManeuverTypeLeftTurn                  =  1,
    CPManeuverTypeRightTurn                 =  2,
    CPManeuverTypeStraightAhead             =  3,
    CPManeuverTypeUTurn                     =  4,
    CPManeuverTypeFollowRoad                =  5,
    CPManeuverTypeEnterRoundabout           =  6,
    CPManeuverTypeExitRoundabout            =  7,
    CPManeuverTypeOffRamp                   =  8,
    CPManeuverTypeOnRamp                    =  9,
    CPManeuverTypeArriveEndOfNavigation     = 10,
    CPManeuverTypeStartRoute                = 11,
    CPManeuverTypeArriveAtDestination       = 12,
    CPManeuverTypeKeepLeft                  = 13,
    CPManeuverTypeKeepRight                 = 14,
    CPManeuverTypeEnter_Ferry               = 15,
    CPManeuverTypeExitFerry                 = 16,
    CPManeuverTypeChangeFerry               = 17,
    CPManeuverTypeStartRouteWithUTurn       = 18,
    CPManeuverTypeUTurnAtRoundabout         = 19,
    CPManeuverTypeLeftTurnAtEnd             = 20,
    CPManeuverTypeRightTurnAtEnd            = 21,
    CPManeuverTypeHighwayOffRampLeft        = 22,
    CPManeuverTypeHighwayOffRampRight       = 23,
    CPManeuverTypeArriveAtDestinationLeft   = 24,
    CPManeuverTypeArriveAtDestinationRight  = 25,
    CPManeuverTypeUTurnWhenPossible         = 26,
    CPManeuverTypeArriveEndOfDirections     = 27,
    CPManeuverTypeRoundaboutExit1           = 28,
    CPManeuverTypeRoundaboutExit2           = 29,
    CPManeuverTypeRoundaboutExit3           = 30,
    CPManeuverTypeRoundaboutExit4           = 31,
    CPManeuverTypeRoundaboutExit5           = 32,
    CPManeuverTypeRoundaboutExit6           = 33,
    CPManeuverTypeRoundaboutExit7           = 34,
    CPManeuverTypeRoundaboutExit8           = 35,
    CPManeuverTypeRoundaboutExit9           = 36,
    CPManeuverTypeRoundaboutExit10          = 37,
    CPManeuverTypeRoundaboutExit11          = 38,
    CPManeuverTypeRoundaboutExit12          = 39,
    CPManeuverTypeRoundaboutExit13          = 40,
    CPManeuverTypeRoundaboutExit14          = 41,
    CPManeuverTypeRoundaboutExit15          = 42,
    CPManeuverTypeRoundaboutExit16          = 43,
    CPManeuverTypeRoundaboutExit17          = 44,
    CPManeuverTypeRoundaboutExit18          = 45,
    CPManeuverTypeRoundaboutExit19          = 46,
    CPManeuverTypeSharpLeftTurn             = 47,
    CPManeuverTypeSharpRightTurn            = 48,
    CPManeuverTypeSlightLeftTurn            = 49,
    CPManeuverTypeSlightRightTurn           = 50,
    CPManeuverTypeChangeHighway             = 51,
    CPManeuverTypeChangeHighwayLeft         = 52,
    CPManeuverTypeChangeHighwayRight        = 53
};

typedef NS_ENUM(NSUInteger, CPJunctionType) {
    CPJunctionTypeIntersection = 0,
    CPJunctionTypeRoundabout   = 1
};

typedef NS_ENUM(NSUInteger, CPTrafficSide) {
    CPTrafficSideRight = 0,
    CPTrafficSideLeft  = 1
};

typedef NS_ENUM(NSInteger, CPManeuverState) {
    CPManeuverStateInitial = 0,
    CPManeuverStatePrepare,
    CPManeuverStateExecute,
    CPManeuverStateContinue
};

NS_ASSUME_NONNULL_END

#endif

#endif
