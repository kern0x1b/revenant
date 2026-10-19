#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlay174.h"

#if !__has_include(<CarPlay/CPLane.h>)

@interface CPNavigationSession ()
@property (nullable, nonatomic, readwrite, copy) CPLaneGuidance *currentLaneGuidance;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *currentRoadNameVariants;
@property (nonatomic) CPManeuverState maneuverState;
@end

#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface CPMapTemplate (CharonNavigationSession)
- (id)charon_navigationSession;
- (void)charon_setNavigationSession:(id)session;
- (void)charon_showSessionGuidance;
- (UIView *)charon_mapView;
@end

@interface CharonSessionGuidance : UIView
@end

@implementation CharonSessionGuidance
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
    NSMutableArray<CPManeuver *> *_charonChronologicalManeuvers;
    NSMutableArray<CPLaneGuidance *> *_charonChronologicalLaneGuidances;
    CPLaneGuidance *_charonCurrentLaneGuidance;
    NSArray<NSString *> *_charonCurrentRoadNameVariants;
    CPManeuverState _charonManeuverState;
    NSArray<CPManeuver *> *_charonRouteManeuvers;
    NSArray<CPLaneGuidance *> *_charonRouteLaneGuidances;
    NSArray<CPManeuver *> *_charonRouteCurrentManeuvers;
    CPLaneGuidance *_charonRouteCurrentLaneGuidance;
    CPTravelEstimates *_charonRouteTripEstimates;
    CPTravelEstimates *_charonRouteManeuverEstimates;
}

@synthesize trip = _trip;
@synthesize upcomingManeuvers = _upcomingManeuvers;

@dynamic currentLaneGuidance;
@dynamic currentRoadNameVariants;
@dynamic maneuverState;

+ (instancetype)charon_sessionForTrip:(CPTrip *)trip mapTemplate:(CPMapTemplate *)mapTemplate
{
    CPNavigationSession *session = [[CPNavigationSession alloc] init];
    [session charon_takeTrip:trip mapTemplate:mapTemplate];
    return session;
}

- (void)charon_takeTrip:(CPTrip *)trip mapTemplate:(CPMapTemplate *)mapTemplate
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
    [self charon_tellTemplate];
}

- (void)updateTravelEstimates:(CPTravelEstimates *)estimates forManeuver:(CPManeuver *)maneuver
{
    if (estimates == nil) {
        return;
    }
    if (maneuver != nil) {
        _estimatesByManeuver[[self charon_keyForManeuver:maneuver]] = estimates;
    } else {
        _estimatesByManeuver[@"charon.last"] = estimates;
    }
    [self charon_tellTemplate];
}

- (void)pauseTripForReason:(CPTripPauseReason)reason description:(NSString *)description
{
    _pauseReason = (NSInteger)reason;
    _pauseDescription = [description copy];
    [self charon_tellTemplate];
}

- (void)charon_pauseWithReason:(CPTripPauseReason)reason
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
    [self charon_tellTemplate];
}

- (void)cancelTrip
{
    _cancelled = YES;
    _upcomingManeuvers = @[];
    [self charon_tellTemplate];
}

- (void)charon_addManeuvers:(NSArray<CPManeuver *> *)maneuvers
{
    if (maneuvers.count == 0) {
        return;
    }
    if (_charonChronologicalManeuvers == nil) {
        _charonChronologicalManeuvers = [NSMutableArray array];
    }
    [_charonChronologicalManeuvers addObjectsFromArray:maneuvers];
    [self charon_tellTemplate];
}

- (void)charon_addLaneGuidances:(NSArray<CPLaneGuidance *> *)laneGuidances
{
    if (laneGuidances.count == 0) {
        return;
    }
    if (_charonChronologicalLaneGuidances == nil) {
        _charonChronologicalLaneGuidances = [NSMutableArray array];
    }
    [_charonChronologicalLaneGuidances addObjectsFromArray:laneGuidances];
    [self charon_tellTemplate];
}

- (void)charon_setCurrentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
{
    _charonCurrentLaneGuidance = [currentLaneGuidance copy];
    [self charon_tellTemplate];
}

- (void)charon_setCurrentRoadNameVariants:(NSArray<NSString *> *)currentRoadNameVariants
{
    _charonCurrentRoadNameVariants = [currentRoadNameVariants copy];
    [self charon_tellTemplate];
}

- (void)charon_setManeuverState:(CPManeuverState)maneuverState
{
    _charonManeuverState = maneuverState;
    [self charon_tellTemplate];
}

- (void)charon_resumeWithRouteInformation:(CPRouteInformation *)routeInformation
{
    if (routeInformation == nil) {
        return;
    }
    _charonRouteManeuvers = [routeInformation.maneuvers copy];
    _charonRouteLaneGuidances = [routeInformation.laneGuidances copy];
    _charonRouteCurrentManeuvers = [routeInformation.currentManeuvers copy];
    _charonRouteCurrentLaneGuidance = [routeInformation.currentLaneGuidance copy];
    _charonRouteTripEstimates = [routeInformation.tripTravelEstimates copy];
    _charonRouteManeuverEstimates = [routeInformation.maneuverTravelEstimates copy];
    if (_charonRouteManeuvers.count > 0) {
        self.upcomingManeuvers = _charonRouteManeuvers;
    }
    if (_charonRouteCurrentLaneGuidance != nil) {
        [self charon_setCurrentLaneGuidance:_charonRouteCurrentLaneGuidance];
    }
    if (_charonRouteManeuverEstimates != nil && _charonRouteCurrentManeuvers.count > 0) {
        [self updateTravelEstimates:_charonRouteManeuverEstimates
                      forManeuver:_charonRouteCurrentManeuvers.firstObject];
    }
    _pauseReason = 0;
    _pauseDescription = nil;
    _finished = NO;
    _cancelled = NO;
    [self charon_tellTemplate];
}

- (NSString *)charon_roadNameText
{
    for (NSString *variant in _charonCurrentRoadNameVariants) {
        if (variant.length > 0) {
            return variant;
        }
    }
    return nil;
}

- (NSArray<CPLaneGuidance *> *)charon_laneGuidances
{
    return _charonChronologicalLaneGuidances != nil ? [_charonChronologicalLaneGuidances copy] : nil;
}

- (CPLaneGuidance *)charon_currentLaneGuidance
{
    return _charonCurrentLaneGuidance;
}

- (NSArray<NSString *> *)charon_currentRoadNameVariants
{
    return _charonCurrentRoadNameVariants;
}

- (CPManeuverState)charon_maneuverStateValue
{
    return _charonManeuverState;
}

- (CPTravelEstimates *)charon_latestEstimates
{
    for (CPManeuver *maneuver in _charonRouteCurrentManeuvers) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self charon_keyForManeuver:maneuver]];
        if (estimates != nil) {
            return estimates;
        }
    }
    if (_charonRouteManeuverEstimates != nil) {
        return _charonRouteManeuverEstimates;
    }
    CPManeuver *current = _charonChronologicalManeuvers.lastObject;
    if (current != nil) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self charon_keyForManeuver:current]];
        if (estimates != nil) {
            return estimates;
        }
    }
    for (CPManeuver *maneuver in _upcomingManeuvers) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self charon_keyForManeuver:maneuver]];
        if (estimates != nil) {
            return estimates;
        }
    }
    if (_charonRouteTripEstimates != nil) {
        return _charonRouteTripEstimates;
    }
    return _estimatesByManeuver[@"charon.last"];
}

- (NSString *)charon_guidanceText
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
    NSString *road = [self charon_roadNameText];
    if (road != nil) {
        return road;
    }
    CPTravelEstimates *estimates = [self charon_latestEstimates];
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

- (UIColor *)charon_cardColorOnTemplate:(CPMapTemplate *)mapTemplate
{
    if (_turnCardColor != nil) {
        return _turnCardColor;
    }
    if (mapTemplate.guidanceBackgroundColor != nil) {
        return mapTemplate.guidanceBackgroundColor;
    }
    return [UIColor colorWithWhite:0.0 alpha:0.6];
}

- (NSString *)charon_keyForManeuver:(CPManeuver *)maneuver
{
    return [NSString stringWithFormat:@"charon.maneuver.%p", (void *)maneuver];
}

- (void)charon_tellTemplate
{
    [(CPMapTemplate *)_mapTemplate charon_showSessionGuidance];
}

@end

@implementation CPMapTemplate (CharonNavigationSession)

- (CPNavigationSession *)startNavigationSessionForTrip:(CPTrip *)trip
{
    CPNavigationSession *running = (CPNavigationSession *)[self charon_navigationSession];
    if (running != nil && trip != nil && running.trip == trip) {
        return running;
    }
    CPNavigationSession *session = [CPNavigationSession charon_sessionForTrip:trip mapTemplate:self];
    [self charon_setNavigationSession:session];
    [self charon_showSessionGuidance];
    return session;
}

- (void)charon_showSessionGuidance
{
    CPNavigationSession *session = (CPNavigationSession *)[self charon_navigationSession];
    if (session == nil) {
        return;
    }
    NSString *text = [session charon_guidanceText];
    UIView *map = [self charon_mapView];
    if (text == nil || map == nil) {
        return;
    }
    for (UIView *card in [map.subviews copy]) {
        if ([card isKindOfClass:[CharonSessionGuidance class]]) {
            [card removeFromSuperview];
        }
    }
    CGSize size = CGSizeMake(220.0, 56.0);
    CharonSessionGuidance *card = [[CharonSessionGuidance alloc] initWithFrame:CGRectMake(20.0, 20.0,
                                                                                          size.width, size.height)];
    card.backgroundColor = [(CPNavigationSession *)session charon_cardColorOnTemplate:self];
    card.layer.cornerRadius = 10.0;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(card.bounds, 12.0, 12.0)];
    label.text = text;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    [card addSubview:label];
    NSArray<CPLaneGuidance *> *laneGuidances = [session charon_laneGuidances];
    CPLaneGuidance *current = [session charon_currentLaneGuidance];
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
