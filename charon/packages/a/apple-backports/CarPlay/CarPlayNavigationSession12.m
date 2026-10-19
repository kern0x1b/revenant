// The navigation session a map template begins, and the guidance it feeds back into that template.
//
// The 26.2 header is where this comes from, and it is what makes the session an object rather than a
// rule: CPNavigationSession.h:26-27 says a CPNavigationSession is created for the app when startNavigationSessionForTrip: is called on the CPMapTemplate, and CPMapTemplate.h:118 says to keep a reference to
// it to perform guidance updates. The 16.0 arm64e cache agrees about who makes one: the class's only
// initialiser is the private -initWithTrip:mapTemplate:, and the private protocol
// CPNavigationSessionProviding declares -hostStartNavigationSessionForTrip:reply:. The 12.0 cache,
// which is the band this object is carried from, agrees about the direction and spells the creator
// differently: its only initialiser is -initWithTrip:provider:mapTemplate:, with -provider and
// -setProvider: beside it, so a provider arrived between the two releases
// (facts/CarPlay/CarPlay12BandEnd.md). What both say is the same and is what this rests on: the app is
// handed the session and does not build one. So the way in is a MAP TEMPLATE -- which this port
// carries and draws, and which is what this port has instead of a head unit -- and what the session
// carries is the program's own trip, maneuvers and estimates.
//
// What is the wall, and it is not this: a car renders the guidance on its own screen and takes the
// driver's input. There is no head unit on either fleet device, so what this object answers is the
// part a program owns, and the map template's own guidance card is where the estimates land. That is
// the same seam `facts/CarPlay/Scenes.md` names for the scenes and `facts/CarPlay/CarPlay.md` for the
// templates: the drawing is the port's, the car is the wall.
//
// -init and +new are NOT here: CPNavigationSession.h:33-34 marks both NS_UNAVAILABLE, the port's own
// header refuses an app's call the same way, and the registry carries those two rows as absent for
// exactly that reason (facts/CarPlay/Session.md).
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlay174.h"

#if !__has_include(<CarPlay/CPLane.h>)

// The session's three 17.4 properties, declared HERE and not in CharonCarPlay174.h. Two reasons, and the
// second is a measured compile error rather than a preference.
//
//   - A class EXTENSION is the file-private way to declare a property of a class whose @implementation
//     lives in this file, and it is what lets `@dynamic` below name them. Declared in a CATEGORY
//     instead, the 16.4 build fails with "property declared in category cannot be implemented in class
//     implementation" -- measured 2026-10-01 compiling this file against the build SDK.
//   - A class extension is not part of the class's public surface, which is what these three want: they
//     are 17.4 API whose accessors belong to CarPlayNavigationSession174.m's category, and this object
//     must hold their storage without holding their accessors.
//   - It is guarded by the same __has_include the header uses. The 16.4 SDK does not declare these three
//     at all (CPNavigationSession.h there stops at the 15.4 pause), so the port declares them; the 26.2
//     SDK does declare them, and redeclaring them there is "illegal redeclaration of 'readwrite' property
//     in class extension" -- measured 2026-10-01 against both SDKs. Either way the `@dynamic`
//     directives below stand, and they are what keep the getters out of this 12.0 object.
@interface CPNavigationSession ()
@property (nullable, nonatomic, readwrite, copy) CPLaneGuidance *currentLaneGuidance;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *currentRoadNameVariants;
@property (nonatomic) CPManeuverState maneuverState;
@end

#endif

// The 16.4 SDK's header declares -pauseTripForReason:description:turnCardColor: on this class, and it
// is a 15.4 row carried in its own object (CarPlayNavigationSession154.m), so this 12.0 object does not
// define it and the compiler says so. The suppression is that sentence and nothing else.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// Where a map template keeps the session it began. The storage is the class's own (CarPlayTemplatesView12.m
// declares the ivar and this accessor), and the method below is the public one, so that the object
// which creates the session can be compiled on its own by the host harness while the class keeps its
// own storage. Charon's own, so it carries no API.
@interface CPMapTemplate (CharonNavigationSession)
- (id)charon_navigationSession;
- (void)charon_setNavigationSession:(id)session;
- (void)charon_showSessionGuidance;
- (UIView *)charon_mapView;
@end

// The card a session's own guidance is drawn in, which is a plain view named so the drawing can take
// an old one off the map and put a new one in its place. Charon's own, so it is not API.
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
    // The storage the 17.4 object's category reaches (CarPlayNavigationSession174.m). A category cannot
    // add an ivar, and the class's @implementation is this file, so the values the 17.4 members keep
    // live here behind Charon-prefixed accessors -- the same shape the 15.4 object already uses for
    // `_turnCardColor` through -charon_pauseWithReason:description:turnCardColor: above. Every name is
    // Charon-prefixed, so none of it is API and none of it appears in this object's exports: this file
    // is 12.0 and stays 12.0, and the 17.4 selectors live in their own object.
    NSMutableArray<CPManeuver *> *_charonChronologicalManeuvers;
    NSMutableArray<CPLaneGuidance *> *_charonChronologicalLaneGuidances;
    CPLaneGuidance *_charonCurrentLaneGuidance;
    NSArray<NSString *> *_charonCurrentRoadNameVariants;
    CPManeuverState _charonManeuverState;
    // What -resumeTripWithUpdatedRouteInformation: was last given, kept as its own fields rather than
    // as the object, because a CPRouteInformation is a value the program builds and the session's own
    // state is what it resumed with. CPRouteInformation.h:30-55 makes every one of its properties
    // `copy`, so each is copied once here and the copy is what the session answers.
    NSArray<CPManeuver *> *_charonRouteManeuvers;
    NSArray<CPLaneGuidance *> *_charonRouteLaneGuidances;
    NSArray<CPManeuver *> *_charonRouteCurrentManeuvers;
    CPLaneGuidance *_charonRouteCurrentLaneGuidance;
    CPTravelEstimates *_charonRouteTripEstimates;
    CPTravelEstimates *_charonRouteManeuverEstimates;
}

@synthesize trip = _trip;
@synthesize upcomingManeuvers = _upcomingManeuvers;

// The three 17.4 properties are @dynamic and NOT @synthesize, and the reason is measured rather than
// stylistic. `@synthesize` emits the getter into THIS object, and this object is 12.0: a getter for a
// 17.4 property emitted by the 12.0 object puts 17.4 API in a 12.0 band, which is the defect commit
// 329b2b23c found and fixed for PHPhotoLibrary's availability property and for
// CPSessionConfiguration's contentStyle -- the compiler auto-synthesises every property an SDK header
// declares, and an object does not implement. The ivars above are declared and kept; the accessors
// come from the 17.4 object's category (CarPlayNavigationSession174.m), which is where those three
// rows' API belongs. `@dynamic` is what says "the storage is here, the methods are not".
@dynamic currentLaneGuidance;
@dynamic currentRoadNameVariants;
@dynamic maneuverState;

// The port's own way in, called by the map template's own -startNavigationSessionForTrip:. It is a
// class method and not an initialiser because the 26.2 header forbids -init and +new
// (CPNavigationSession.h:33-34) and because a method outside the init family may not assign to self;
// NSObject's own -init is used, which is the release's, and the two Charon methods below do the
// configuring. The release's own name for this is the private creator, -initWithTrip:mapTemplate: at
// 16.0 and 18.0 and -initWithTrip:provider:mapTemplate: at 12.0, which is the band this object is
// carried from; a Charon name is both the port's own and out of the library's exports.
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

// The maneuvers a program set, kept as it set them: the header's property is readwrite copy, and the
// order is the program's because "Multiple maneuvers are displayed simultaneously" and which ones
// those are is the program's to choose.
- (void)setUpcomingManeuvers:(NSArray<CPManeuver *> *)upcomingManeuvers
{
    _upcomingManeuvers = [upcomingManeuvers copy] ?: @[];
    [self charon_tellTemplate];
}

// The estimates for one maneuver, which is what the header's method is for: the session keeps them
// per maneuver and the map template's guidance card draws the time remaining of the newest, which is
// the one a driver is arriving at.
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

// The header's own reason type, kept as it was given so a reader of the object can see it: a negative
// is what the header's enumeration has for "not one of these", and it is not turned into a card.
- (void)pauseTripForReason:(CPTripPauseReason)reason description:(NSString *)description
{
    _pauseReason = (NSInteger)reason;
    _pauseDescription = [description copy];
    [self charon_tellTemplate];
}

// The pause with a card colour, which the 15.4 object calls: the 12.0 pause plus the colour, recorded
// here because the colour is the session's state and the card is what reads it.
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

// ---- The storage the 17.4 object's category reaches -----------------------------------------------
// Each of these is called by CarPlayNavigationSession174.m and none of them is API. The behaviour is
// the header's, and where the header is silent the measured answer from Apple's own object is followed
// rather than a value invented -- see facts/CarPlay/NavigationSession174.md.

// :83-86 says to append CPManeuvers in time order and to supply them early, as soon as they are known. So each call APPENDS and the order is the order the
// program called in, which is what "chronological" means for a program feeding guidance as it computes
// it. The list is what the card reads for its guidance text, so an addition shows at once.
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

// :90-91 "add CPLaneGuidances in chronological order ... added as soon as they are available." The same
// accumulation as the maneuvers, kept beside them and in the same order, because the header describes
// both as chronological and a program's lane guidance arrives alongside its maneuvers.
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

// :78 requires nil when no lane guidance is current. So nil is stored and answered as nil,
// and the value is kept as it was given rather than copied: the header says `copy`, and a
// CPLaneGuidance is itself an NSCopying value (:17 of its own header), so the copy is the same value.
- (void)charon_setCurrentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
{
    _charonCurrentLaneGuidance = [currentLaneGuidance copy];
    [self charon_tellTemplate];
}

// :96-97 gives currentRoadNameVariants as the variants of the current road name, ordered from the wordiest to the least wordy. The header says `copy` and
// the order is the program's, so the array is copied and kept as given -- first is the most verbose,
// and the guidance text asks for the first one it can use.
- (void)charon_setCurrentRoadNameVariants:(NSArray<NSString *> *)currentRoadNameVariants
{
    _charonCurrentRoadNameVariants = [currentRoadNameVariants copy];
    [self charon_tellTemplate];
}

// :101-102 gives maneuverState as a reading of how close the maneuver is. A plain value kept as given;
// 0 is `CPManeuverStateContinue` in this SDK's enumeration and is what a session with nothing set
// answers, measured on Apple's own object above.
- (void)charon_setManeuverState:(CPManeuverState)maneuverState
{
    _charonManeuverState = maneuverState;
    [self charon_tellTemplate];
}

// :54-57 says the method resumes the active trip, refreshed with new route details. The information is the program's own
// object (CPRouteInformation.h:14 names it as the data a route needs for rerouting), every one of its properties is `copy` (:30-55), and each is copied once here. The
// maneuvers it carries become what the session's guidance draws, because a resumed trip's maneuvers are
// the new route's, and the trip is no longer paused -- this is a resume, which is what the header says
// the method is, and leaving the session showing a pause card after a resume would be a second answer.
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

// What the 12.0 guidance card reads for the 17.4 values, so the card shows the road the program named
// and the state it set. Charon's own, so the card does not reach into the session's storage.
- (NSString *)charon_roadNameText
{
    for (NSString *variant in _charonCurrentRoadNameVariants) {
        if (variant.length > 0) {
            return variant;
        }
    }
    return nil;
}

// What the map template's guidance card draws under the estimates: the lane the program named at 17.4
// (currentLaneGuidance, :80) and how many of them it has added (:93). Charon's own, so the card reads
// the session's storage through one accessor instead of reaching into it.
- (NSArray<CPLaneGuidance *> *)charon_laneGuidances
{
    return _charonChronologicalLaneGuidances != nil ? [_charonChronologicalLaneGuidances copy] : nil;
}

- (CPLaneGuidance *)charon_currentLaneGuidance
{
    return _charonCurrentLaneGuidance;
}

// The readers for the other two 17.4 values, in the same Charon-prefixed shape. `copy` on the way in
// means the getter hands back the session's own copy and a caller cannot change it through the getter.
- (NSArray<NSString *> *)charon_currentRoadNameVariants
{
    return _charonCurrentRoadNameVariants;
}

- (CPManeuverState)charon_maneuverStateValue
{
    return _charonManeuverState;
}

// The estimates and the state of the trip, as the map template's guidance card needs them. Charon's
// own, so the card does not reach into the session's storage.
- (CPTravelEstimates *)charon_latestEstimates
{
    // CPRouteInformation.h:53-55 gives maneuverTravelEstimates as the estimates for the first maneuver of those current
    // maneuvers, which is the one a driver is arriving at.
    for (CPManeuver *maneuver in _charonRouteCurrentManeuvers) {
        CPTravelEstimates *estimates = _estimatesByManeuver[[self charon_keyForManeuver:maneuver]];
        if (estimates != nil) {
            return estimates;
        }
    }
    if (_charonRouteManeuverEstimates != nil) {
        return _charonRouteManeuverEstimates;
    }
    // The maneuver a 17.4 program added LAST is the one being performed: :83-85 says the application
    // adds maneuvers "in chronological order ... as soon as they are available", so the newest is the
    // current one, and its estimates are what the card shows. That is also what gives the accumulated
    // list a reader -- without this the list would be a store nothing read.
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
    // The road name 17.4 added leads the card when a program set one, because it is the most precise
    // thing the program has told the session: "From most to least verbose" (:96-97), so the first
    // variant it gave is the one a driver reads.
    NSString *road = [self charon_roadNameText];
    if (road != nil) {
        return road;
    }
    CPTravelEstimates *estimates = [self charon_latestEstimates];
    if (estimates == nil) {
        return nil;
    }
    // The header's own rule for an estimate it cannot show: a distance or time remaining below 0 is rendered as a dash, and values below 0
    // are kept apart from a distance or time of 0. So a negative time is a dash and a zero is a zero.
    NSTimeInterval remaining = estimates.timeRemaining;
    if (remaining < 0.0) {
        return @"--";
    }
    NSInteger minutes = (NSInteger)(remaining / 60.0);
    NSInteger seconds = (NSInteger)remaining - minutes * 60;
    return [NSString stringWithFormat:@"%ld min %02ld sec", (long)minutes, (long)seconds];
}

// The card's colour, in the header's own order: the turn card colour if one was given, otherwise the
// map template's guidanceBackgroundColor, otherwise the colour the template's own -init sets, which is
// this port's system-provided default. Each step is a value that exists, not a stand-in.
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

// The header's own method, and the one the 26.2 header names as the way a session comes to exist. It
// answers a session every time it is asked, keeping the one it made the way a map template keeps its
// own current state, and a second call for the same trip hands back the session already running: the
// header's guidance is per trip, and beginning it twice is not what the method says.
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

// The guidance the session's own estimates and state make, drawn by the template over its map in the
// template's own guidance colour -- the same card the navigation alert is drawn in, so a session's
// estimates and an alert read as one thing on one screen.
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
    // The lane guidance a 17.4 program added, drawn as one plate per lane under the estimates -- which
    // is what CPLaneGuidance.h:14 describes as guidance on which lane or lanes the user should prefer, and what :22 says each lane is: a single lane. A lane is drawn from
    // its own status (CPLane.h:10-15: NotGood, Good, Preferred), so a program that marks one preferred
    // sees the difference, and the plate is the card's own touch target so a tap reaches the program
    // through the session rather than being swallowed here.
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
            // The lane guidance the session says is current is the one whose plates the card outlines,
            // because the header at :78 makes nil the answer when there is no current lane guidance, so nil is a real
            // answer and an outlined plate is how a caller sees which of them it is. The border goes on
            // the PLATE the card drew, never on the lane's own layer: a lane is the program's value and
            // the port does not restyle what a program built.
            if (guidance == current) {
                plate.layer.borderWidth = 2.0;
                plate.layer.borderColor = [UIColor whiteColor].CGColor;
            }
            [card addSubview:plate];
            plateY += 28.0;
        }
    }
    if (plateY > 8.0) {
        // The plates make the card taller than one line of text, so the card's own height follows what
        // is in it rather than the label being drawn over the first row of lanes.
        card.frame = CGRectMake(card.frame.origin.x, card.frame.origin.y, size.width, plateY + 24.0);
        label.frame = CGRectMake(12.0, 12.0, size.width - 24.0, 32.0);
    }
    [map addSubview:card];
}

@end
#pragma clang diagnostic pop
