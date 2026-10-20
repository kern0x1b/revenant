#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlay174.h"

#if !__has_include(<CarPlay/CPLane.h>)

@interface CPNavigationSession ()
@property (nullable, nonatomic, readwrite, copy) CPLaneGuidance *currentLaneGuidance;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *currentRoadNameVariants;
@property (nonatomic) CPManeuverState maneuverState;
@end

#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface CPMapTemplate (RevenantNavigationSession)
- (id)revenant_navigationSession;
- (void)revenant_setNavigationSession:(id)session;
- (void)revenant_showSessionGuidance;
- (UIView *)revenant_mapView;
@end

@interface RevenantSessionGuidance : UIView
@end

@implementation RevenantSessionGuidance
@end

@implementation CPNavigationSession {
    CPTrip *_trip;
    CPMapTemplate *_mapTemplate;
    NSArray<CPManeuver *> *_upcomingManeuvers;
    NSMutableDictionary *_estimatesByManeuver;
    NSString *_pauseDescription;
    NSInteger _pauseReason;
    UIColor *_turnCardColor;
    BOOL _finished;
    BOOL _cancelled;
    NSMutableArray<CPManeuver *> *_revenantChronologicalManeuvers;
    NSMutableArray<CPLaneGuidance *> *_revenantChronologicalLaneGuidances;
    CPLaneGuidance *_revenantCurrentLaneGuidance;
    NSArray<NSString *> *_revenantCurrentRoadNameVariants;
    CPManeuverState _revenantManeuverState;
    NSArray<CPManeuver *> *_revenantRouteManeuvers;
    NSArray<CPLaneGuidance *> *_revenantRouteLaneGuidances;
    NSArray<CPManeuver *> *_revenantRouteCurrentManeuvers;
    CPLaneGuidance *_revenantRouteCurrentLaneGuidance;
    CPTravelEstimates *_revenantRouteTripEstimates;
    CPTravelEstimates *_revenantRouteManeuverEstimates;
}

@synthesize trip = _trip;
@synthesize upcomingManeuvers = _upcomingManeuvers;

@dynamic currentLaneGuidance;
@dynamic currentRoadNameVariants;
@dynamic maneuverState;

+ (instancetype)revenant_sessionForTrip:(CPTrip *)trip mapTemplate:(CPMapTemplate *)mapTemplate
{
    CPNavigationSession *session = [[CPNavigationSession alloc] init];
    [session revenant_takeTrip:trip mapTemplate:mapTemplate];
    return session;
}

- (void)revenant_takeTrip:(CPTrip *)trip mapTemplate:(CPMapTemplate *)mapTemplate
{
    _trip = trip;
    _mapTemplate = mapTemplate;
    _upcomingManeuvers = @[];
    _estimatesByManeuver = [NSMutableDictionary dictionary];
    _pauseReason = 0;
}

- (void)setUpcomingManeuvers:(NSArray<CPManeuver *> *)upcomingManeuvers
{
    _upcomingManeuvers = [upcomingManeuvers copy] ?: @[];
    [self revenant_tellTemplate];
}

- (void)updateTravelEstimates:(CPTravelEstimates *)estimates forManeuver:(CPManeuver *)maneuver
{
    if (estimates == nil) {
        return;
    }
    if (maneuver != nil) {
        _estimatesByManeuver[[self revenant_keyForManeuver:maneuver]] = estimates;
    } else {
        _estimatesByManeuver[@"revenant.last"] = estimates;
    }
    [self revenant_tellTemplate];
}

- (void)pauseTripForReason:(CPTripPauseReason)reason description:(NSString *)description
{
    _pauseReason = (NSInteger)reason;
    _pauseDescription = [description copy];
    [self revenant_tellTemplate];
}

- (void)revenant_pauseWithReason:(CPTripPauseReason)reason
                   description:(NSString *)description
                   turnCardColor:(UIColor *)turnCardColor
{
    _turnCardColor = turnCardColor;
    [self pauseTripForReason:reason description:description];
}

- (void)finishTrip
{
    _finished = YES;
    _upcomingManeuvers = @[];
    [self revenant_tellTemplate];
}

- (void)cancelTrip
{
    _cancelled = YES;
    _upcomingManeuvers = @[];
    [self revenant_tellTemplate];
}

- (void)revenant_addManeuvers:(NSArray<CPManeuver *> *)maneuvers
{
    if (maneuvers.count == 0) {
        return;
    }
    if (_revenantChronologicalManeuvers == nil) {
        _revenantChronologicalManeuvers = [NSMutableArray array];
    }
    [_revenantChronologicalManeuvers addObjectsFromArray:maneuvers];
    [self revenant_tellTemplate];
}

- (void)revenant_addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances
{
    if (laneGuidances.count == 0) {
        return;
    }
    if (_revenantChronologicalLaneGuidances == nil) {
        _revenantChronologicalLaneGuidances = [NSMutableArray array];
    }
    [_revenantChronologicalLaneGuidances addObjectsFromArray:laneGuidances];
    [self revenant_tellTemplate];
}

- (void)revenant_setCurrentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
{
    _revenantCurrentLaneGuidance = [currentLaneGuidance copy];
    [self revenant_tellTemplate];
}

- (void)revenant_setCurrentRoadNameVariants:(NSArray<NSString *> *)currentRoadNameVariants
{
    _revenantCurrentRoadNameVariants = [currentRoadNameVariants copy];
    [self revenant_tellTemplate];
}

- (void)revenant_setManeuverState:(CPManeuverState)maneuverState
{
    _revenantManeuverState = maneuverState;
    [self revenant_tellTemplate];
}

- (void)revenant_resumeWithRouteInformation:(CPRouteInformation *)routeInformation
{
    if (routeInformation == nil) {
        return;
    }
    _revenantRouteManeuvers = [routeInformation.maneuvers copy];
    _revenantRouteLaneGuidances = [routeInformation.laneGuidances copy];
    _revenantRouteCurrentManeuvers = [routeInformation.currentManeuvers copy];
    _revenantRouteCurrentLaneGuidance = [routeInformation.currentLaneGuidance copy];
    _revenantRouteTripEstimates = [routeInformation.tripTravelEstimates copy];
    _revenantRouteManeuverEstimates = [routeInformation.maneuverTravelEstimates copy];
    if (_revenantRouteManeuvers.count > 0) {
        self.upcomingManeuvers = _revenantRouteManeuvers;
    }
    if (_revenantRouteCurrentLaneGuidance != nil) {
        [self revenant_setCurrentLaneGuidance:_revenantRouteCurrentLaneGuidance];
    }
    if (_revenantRouteManeuverEstimates != nil && _revenantRouteCurrentManeuvers.count > 0) {
        [self updateTravelEstimates:_revenantRouteManeuverEstimates
                      forManeuver:_revenantRouteCurrentManeuvers.firstObject];
    }
    _pauseReason = 0;
    _pauseDescription = nil;
    _finished = NO;
    _cancelled = NO;
    [self revenant_tellTemplate];
}

- (NSString *)revenant_roadNameText
{
    for (NSString *variant in _revenantCurrentRoadNameVariants) {
        if (variant.length > 0) {
            return variant;
        }
    }
    return nil;
}

- (NSArray<CPLaneGuidance *> *)revenant_laneGuidances
{
    return _revenantChronologicalLaneGuidances != nil ? [_revenantChronologicalLaneGuidances copy] : nil;
}

- (CPLaneGuidance *)revenant_currentLaneGuidance
{
    return _revenantCurrentLaneGuidance;
}

- (NSArray<NSString *> *)revenant_currentRoadNameVariants
{
    return _revenantCurrentRoadNameVariants;
}

- (CPManeuverState)revenant_maneuverStateValue
{
    return _revenantManeuverState;
}

- (CPTravelEstimates *)revenant_latestEstimates
{
    for (CPManeuver *maneuver in _revenantRouteCurrentManeuvers) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self revenant_keyForManeuver:maneuver]];
        if (estimates != nil) {
            return estimates;
        }
    }
    if (_revenantRouteManeuverEstimates != nil) {
        return _revenantRouteManeuverEstimates;
    }
    CPManeuver *current = _revenantChronologicalManeuvers.lastObject;
    if (current != nil) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self revenant_keyForManeuver:current]];
        if (estimates != nil) {
            return estimates;
        }
    }
    for (CPManeuver *maneuver in _upcomingManeuvers) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self revenant_keyForManeuver:maneuver]];
        if (estimates != nil) {
            return estimates;
        }
    }
    if (_revenantRouteTripEstimates != nil) {
        return _revenantRouteTripEstimates;
    }
    return _estimatesByManeuver[@"revenant.last"];
}

- (NSString *)revenant_guidanceText
{
    if (_cancelled) {
        return @"Trip cancelled";
    }
    if (_finished) {
        return @"Trip finished";
    }
    if (_pauseReason != 0) {
        return _pauseDescription.length > 0 ? _pauseDescription : @"Trip paused";
    }
    NSString *road = [self revenant_roadNameText];
    if (road != nil) {
        return road;
    }
    CPTravelEstimates *estimates = [self revenant_latestEstimates];
    if (estimates == nil) {
        return nil;
    }
    NSTimeInterval remaining = estimates.timeRemaining;
    if (remaining < 0.0) {
        return @"--";
    }
    NSInteger minutes = (NSInteger)(remaining / 60.0);
    NSInteger seconds = (NSInteger)remaining - minutes * 60;
    return [NSString stringWithFormat:@"%ld min %02ld sec", (long)minutes, (long)seconds];
}

- (UIColor *)revenant_cardColorOnTemplate:(CPMapTemplate *)mapTemplate
{
    if (_turnCardColor != nil) {
        return _turnCardColor;
    }
    if (mapTemplate.guidanceBackgroundColor != nil) {
        return mapTemplate.guidanceBackgroundColor;
    }
    return [UIColor colorWithWhite:0.0 alpha:0.6];
}

- (NSString *)revenant_keyForManeuver:(CPManeuver *)maneuver
{
    return [NSString stringWithFormat:@"revenant.maneuver.%p", (void *)maneuver];
}

- (void)revenant_tellTemplate
{
    [(CPMapTemplate *)_mapTemplate revenant_showSessionGuidance];
}

@end

@implementation CPMapTemplate (RevenantNavigationSession)

- (CPNavigationSession *)startNavigationSessionForTrip:(CPTrip *)trip
{
    CPNavigationSession *running = (CPNavigationSession *)[self revenant_navigationSession];
    if (running != nil && trip != nil && running.trip == trip) {
        return running;
    }
    CPNavigationSession *session = [CPNavigationSession revenant_sessionForTrip:trip mapTemplate:self];
    [self revenant_setNavigationSession:session];
    [self revenant_showSessionGuidance];
    return session;
}

- (void)revenant_showSessionGuidance
{
    CPNavigationSession *session = (CPNavigationSession *)[self revenant_navigationSession];
    if (session == nil) {
        return;
    }
    NSString *text = [session revenant_guidanceText];
    UIView *map = [self revenant_mapView];
    if (text == nil || map == nil) {
        return;
    }
    for (UIView *card in [map.subviews copy]) {
        if ([card isKindOfClass:[RevenantSessionGuidance class]]) {
            [card removeFromSuperview];
        }
    }
    CGSize size = CGSizeMake(220.0, 56.0);
    RevenantSessionGuidance *card = [[RevenantSessionGuidance alloc] initWithFrame:CGRectMake(20.0, 20.0,
                                                                                          size.width, size.height)];
    card.backgroundColor = [(CPNavigationSession *)session revenant_cardColorOnTemplate:self];
    card.layer.cornerRadius = 10.0;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(card.bounds, 12.0, 12.0)];
    label.text = text;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    [card addSubview:label];
    NSArray<CPLaneGuidance *> *laneGuidances = [session revenant_laneGuidances];
    CPLaneGuidance *current = [session revenant_currentLaneGuidance];
    CGFloat plateY = 8.0;
    for (CPLaneGuidance *guidance in laneGuidances) {
        for (CPLane *lane in guidance.lanes) {
            UIView *plate = [[UIView alloc] initWithFrame:CGRectMake(plateY, 12.0, 24.0, 16.0)];
            plate.backgroundColor = lane.status == CPLaneStatusNotGood
                ? [UIColor colorWithWhite:0.4 alpha:1.0]
                : [UIColor whiteColor];
            plate.layer.cornerRadius = 3.0;
            if (guidance == current) {
                plate.layer.borderWidth = 2.0;
                plate.layer.borderColor = [UIColor whiteColor].CGColor;
            }
            [card addSubview:plate];
            plateY += 28.0;
        }
    }
    if (plateY > 8.0) {
        card.frame = CGRectMake(card.frame.origin.x, card.frame.origin.y, size.width, plateY + 24.0);
        label.frame = CGRectMake(12.0, 12.0, size.width - 24.0, 32.0);
    }
    [map addSubview:card];
}

@end
#pragma clang diagnostic pop
