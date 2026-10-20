#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlay174.h"

@interface CPNavigationSession (RevenantRouteInformation174)
- (void)revenant_addManeuvers:(NSArray<CPManeuver *> *)maneuvers;
- (void)revenant_addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances;
- (CPLaneGuidance *)revenant_currentLaneGuidance;
- (void)revenant_setCurrentLaneGuidance:(CPLaneGuidance *)laneGuidance;
- (NSArray<NSString *> *)revenant_currentRoadNameVariants;
- (void)revenant_setCurrentRoadNameVariants:(NSArray<NSString *> *)variants;
- (CPManeuverState)revenant_maneuverStateValue;
- (void)revenant_setManeuverState:(CPManeuverState)state;
- (void)revenant_resumeWithRouteInformation:(CPRouteInformation *)routeInformation;
@end

@implementation CPNavigationSession (RevenantRouteInformation174)

- (void)addManeuvers:(NSArray<CPManeuver *> *)maneuvers
{
    [self revenant_addManeuvers:maneuvers];
}

- (void)addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances
{
    [self revenant_addLaneGuidances:laneGuidances];
}

- (CPLaneGuidance *)currentLaneGuidance
{
    return [self revenant_currentLaneGuidance];
}

- (NSArray<NSString *> *)currentRoadNameVariants
{
    return [self revenant_currentRoadNameVariants];
}

- (CPManeuverState)maneuverState
{
    return [self revenant_maneuverStateValue];
}

- (void)setCurrentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
{
    [self revenant_setCurrentLaneGuidance:currentLaneGuidance];
}

- (void)setCurrentRoadNameVariants:(NSArray<NSString *> *)currentRoadNameVariants
{
    [self revenant_setCurrentRoadNameVariants:currentRoadNameVariants];
}

- (void)setManeuverState:(CPManeuverState)maneuverState
{
    [self revenant_setManeuverState:maneuverState];
}

- (void)resumeTripWithUpdatedRouteInformation:(CPRouteInformation *)routeInformation
{
    [self revenant_resumeWithRouteInformation:routeInformation];
}

@end
