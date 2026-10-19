#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlay174.h"

@interface CPNavigationSession (CharonRouteInformation174)
- (void)charon_addManeuvers:(NSArray<CPManeuver *> *)maneuvers;
- (void)charon_addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances;
- (CPLaneGuidance *)charon_currentLaneGuidance;
- (void)charon_setCurrentLaneGuidance:(CPLaneGuidance *)laneGuidance;
- (NSArray<NSString *> *)charon_currentRoadNameVariants;
- (void)charon_setCurrentRoadNameVariants:(NSArray<NSString *> *)variants;
- (CPManeuverState)charon_maneuverStateValue;
- (void)charon_setManeuverState:(CPManeuverState)state;
- (void)charon_resumeWithRouteInformation:(CPRouteInformation *)routeInformation;
@end

@implementation CPNavigationSession (CharonRouteInformation174)

- (void)addManeuvers:(NSArray<CPManeuver *> *)maneuvers
{
    [self charon_addManeuvers:maneuvers];
}

- (void)addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances
{
    [self charon_addLaneGuidances:laneGuidances];
}

- (CPLaneGuidance *)currentLaneGuidance
{
    return [self charon_currentLaneGuidance];
}

- (NSArray<NSString *> *)currentRoadNameVariants
{
    return [self charon_currentRoadNameVariants];
}

- (CPManeuverState)maneuverState
{
    return [self charon_maneuverStateValue];
}

- (void)setCurrentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
{
    [self charon_setCurrentLaneGuidance:currentLaneGuidance];
}

- (void)setCurrentRoadNameVariants:(NSArray<NSString *> *)currentRoadNameVariants
{
    [self charon_setCurrentRoadNameVariants:currentRoadNameVariants];
}

- (void)setManeuverState:(CPManeuverState)maneuverState
{
    [self charon_setManeuverState:maneuverState];
}

- (void)resumeTripWithUpdatedRouteInformation:(CPRouteInformation *)routeInformation
{
    [self charon_resumeWithRouteInformation:routeInformation];
}

@end
