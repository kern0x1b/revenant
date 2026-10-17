// The 17.4 members of the navigation session: the chronological additions and the three stored values.
//
// CPNavigationSession.h:53-58 declares -resumeTripWithUpdatedRouteInformation: `API_AVAILABLE(ios(17.4))`,
// :80 currentLaneGuidance, :87 -addManeuvers:, :93 -addLaneGuidances:, :98 currentRoadNameVariants and
// :103 maneuverState, all five `API_AVAILABLE(ios(17.4))`. These are the six rows the registry carried
// as `owed`, which is not a landing state: the release carries the names, the port could carry them,
// and nobody had written them.
//
// WHY THEY ARE NOT A WALL, measured rather than argued. A CarPlay row is often a value the connected
// car writes, and those are the ones the port carries as `inert`. These six are the opposite: they are
// the program's own values on the session the program already holds. Three measurements, all on
// Apple's own CarPlay on this machine with no head unit attached
// (tests/backports/host/carplay/headunit-probe.m, section 8):
//
//   ok  a session with nothing added answers no maneuvers at all   nil
//   ok  currentRoadNameVariants answers nil before anything is set nil
//   ok  currentLaneGuidance answers nil before anything is set     nil
//   ok  maneuverState answers 0 before anything is set             0
//        [CPNavigationSession addManeuvers:] present
//        [CPNavigationSession addLaneGuidances:] present
//        [CPNavigationSession resumeTripWithUpdatedRouteInformation:] present
//        [CPNavigationSession setCurrentRoadNameVariants:] present
//        [CPNavigationSession setManeuverState:] present
//
// A car is attached to none of that. And the release's own cache says the same from the other side,
// per class with tools/corpus/objc-inventory.lua over the arm64e dyld shared caches: at 16.0 the class
// carries trip, upcomingManeuvers, cancelTrip, finishTrip, pauseTripForReason:description:,
// pauseTripForReason:description:turnCardColor: and updateTravelEstimates:forManeuver: and NONE of these
// six; at 18.0 it carries all six together with the private storage accessors -setCurrentLaneGuidance:,
// -setCurrentRoadNameVariants:, -setManeuverState:, -setLaneGuidances:, -setManeuvers: and the two
// private index builders -_updateLaneGuidanceIndiciesWithStartIndex:laneGuidances: and
// -_updateManeuverIndiciesWithStartIndex:maneuvers:. The private setters are what settles the
// disposition: a value whose writer is a setter on the object is the object's own state, and a
// message to a car would have no setter here at all. `xmake l tools/cache-index/first-rung.lua
// CPLaneGuidance CPRouteInformation` answers 16.0 and 18.0 -- presence on the held ladder, which has no
// 13.x/14.x/15.x rung -- so the classes themselves are not 18.0-only even though the ladder has no rung
// that says 17.4.
//
// WHY A SEPARATE OBJECT, and this is the obstacle the port's own shape forces. Each of these members
// stores into an ivar of CPNavigationSession, and the class's @implementation is in
// CarPlayNavigationSession12.m -- a file for 12.0 that this series did not write. A category cannot
// add an ivar, so a 17.4 member written as a category here has nowhere to keep its value. The port
// already has the answer to that and uses it twice: CarPlayNavigationSession154.m is a category on the
// same class that keeps nothing of its own and reaches the storage through a Charon-prefixed accessor
// the 12.0 object declares, and CarPlayTemplatesView12.m keeps its storage on the class whose
// implementation it is. So the storage for these six lives with the class's own ivars in
// CarPlayNavigationSession12.m, behind Charon accessors, and this file carries only the 17.4 selectors.
//
// What the header says each one does, and what this follows:
//   :83-86 -addManeuvers: adds CPManeuvers in chronological order, and every maneuver set in
//           upcomingManeuvers has to be added first through this method -- so it appends to an ordered
//           list and tells the template, because the guidance card is what shows them.
//   :90-91 -addLaneGuidances: adds CPLaneGuidances in chronological order, each as soon as it
//           is ready -- the same accumulation for lane guidance.
//   :78    currentLaneGuidance is nil until a guidance is given; the header says a guidance set on it has to be added first with addLaneGuidances:,
//           so the value is nil until it is given and nil is a real answer, not a missing one.
//   :96-97 currentRoadNameVariants holds the wording options for the present road name, from the wordiest to the least.
//   :101-102 maneuverState is a reading of how close the maneuver is.
//   :54-57 -resumeTripWithUpdatedRouteInformation: resumes the active trip, refreshed with new route
//           information, so the information replaces what the session holds for the current route.
//
// The class's own rule about which release owns what is the reason this file exists separately and
// carries one release: an object may hold API of exactly one release (modules/apple/backports.lua's
// releases_in, read by `tools/release-split.lua`), so the 12.0 object stays 12.0 and the 15.4 and 17.4
// members are objects of their own.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlay174.h"

// What this object asks of the session's own storage. Every name is Charon-prefixed, so it carries no
// API and stays out of the library's exports -- the same rule the 15.4 object's category follows.
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

// The three GETTERS belong here as well as the three setters, and that is not tidiness. A property's
// accessor is its getter, so `-currentLaneGuidance` is a 17.4 selector exactly as much as
// `-setCurrentLaneGuidance:` is -- the 18.0 cache carries both, -currentLaneGuidance and
// -setCurrentLaneGuidance: -- and they belong to the object that owns the release. The 12.0 object says
// `@dynamic` for all three, which means NOBODY generates them: with only the setters in this file the
// differential died with
//     -[charonHost_CPNavigationSession currentRoadNameVariants]: unrecognized selector
// so the fix is the getter, not the @dynamic.

// :80 `@property (nullable, nonatomic, readwrite, copy) CPLaneGuidance *currentLaneGuidance`, with :78's requirement
// that nil is set when there is no current lane guidance -- so nil is an answer here too, and it is
// the value the setter stored rather than a defaulted one.
- (CPLaneGuidance *)currentLaneGuidance
{
    return [self charon_currentLaneGuidance];
}

// :96-97 gives currentRoadNameVariants as the variants of the current road name, ordered from the wordiest to the least wordy. The array is copied on the way
// in, so the getter hands back the session's own copy.
- (NSArray<NSString *> *)currentRoadNameVariants
{
    return [self charon_currentRoadNameVariants];
}

// :101-102 gives maneuverState as a reading of how close the maneuver is. A plain value, and 0 is what
// a session with nothing set answers -- measured on Apple's own object.
- (CPManeuverState)maneuverState
{
    return [self charon_maneuverStateValue];
}

// The header's `nullable, readwrite, copy` (:80) and its own rule that nil means "there is no current
// lane guidance", so nil is stored as nil and answered as nil rather than being defaulted to an empty
// value that would read as a lane.
- (void)setCurrentLaneGuidance:(CPLaneGuidance *)currentLaneGuidance
{
    [self charon_setCurrentLaneGuidance:currentLaneGuidance];
}

// The header's `copy` (:98) and "From most to least verbose" -- the order is the program's and is kept
// as given, so the card can read the first that fits.
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