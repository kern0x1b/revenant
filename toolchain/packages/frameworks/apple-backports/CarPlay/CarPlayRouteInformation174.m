#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>
#import "RevenantCarPlay174.h"

@implementation CPRouteInformation {
    NSArray<CPManeuver *> *_maneuvers;
    NSArray<CPLaneGuidance *> *_laneGuidances;
    NSArray<CPManeuver *> *_currentManeuvers;
    CPLaneGuidance *_currentLaneGuidance;
    CPTravelEstimates *_tripTravelEstimates;
    CPTravelEstimates *_maneuverTravelEstimates;
}

- (instancetype)initWithManeuvers:(NSArray<CPManeuver *> *)maneuvers
                    laneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances
                currentManeuvers:(NSArray<CPManeuver *> *)currentManeuvers
           currentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
             tripTravelEstimates:(CPTravelEstimates *)tripTravelEstimates
        maneuverTravelEstimates:(CPTravelEstimates *)maneuverTravelEstimates
{
    self = [super init];
    if (self) {
        _maneuvers = [maneuvers copy];
        _laneGuidances = [laneGuidances copy];
        _currentManeuvers = [currentManeuvers copy];
        _currentLaneGuidance = [currentLaneGuidance copy];
        _tripTravelEstimates = [tripTravelEstimates copy];
        _maneuverTravelEstimates = [maneuverTravelEstimates copy];
    }
    return self;
}

- (NSArray<CPManeuver *> *)maneuvers
{
    return _maneuvers;
}

- (NSArray<CPLaneGuidance *> *)laneGuidances
{
    return _laneGuidances;
}

- (NSArray<CPManeuver *> *)currentManeuvers
{
    return _currentManeuvers;
}

- (CPLaneGuidance *)currentLaneGuidance
{
    return _currentLaneGuidance;
}

- (CPTravelEstimates *)tripTravelEstimates
{
    return _tripTravelEstimates;
}

- (CPTravelEstimates *)maneuverTravelEstimates
{
    return _maneuverTravelEstimates;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CPRouteInformation: %p, %lu maneuvers, %lu lane guidances, "
                                      @"%lu current maneuvers, trip %@, maneuver %@>",
            self, (unsigned long)_maneuvers.count, (unsigned long)_laneGuidances.count,
            (unsigned long)_currentManeuvers.count, _tripTravelEstimates.description ?: @"nil",
            _maneuverTravelEstimates.description ?: @"nil"];
}

@end
