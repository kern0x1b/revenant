// The one class the port's voice control needs and the harness cannot bring: its superclass.
//
// Apple's own CarPlay is in this binary (the differential links it), so the port's own `CPTemplate`
// is renamed onto `charonHost_CPTemplate` when the port's sources are compiled -- the renames move
// the PORT's references and this file's whole job is to declare what they moved onto. It is the same
// arrangement `tests/backports/host/passkit/port-classes.m` uses for the four PassKit classes, and for
// the same reason: two classes of one name cannot be in one process.
//
// What it has to answer is the two coder calls the port's template makes on its superclass, because
// `CPTemplate` conforms to NSSecureCoding in the SDK and NSObject's own superclass does not declare
// a coder at all.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface charonHost_CPTemplate : NSObject
@end

@implementation charonHost_CPTemplate

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

@end

// The three value classes the session holds, and the map template it belongs to, are Apple's own in
// this binary (the differential links CarPlay), so the port's references to them are renamed onto
// charonHost_ names and these four declare what they moved onto. The trip, the maneuver and the
// estimates are values: the session keeps them, reads timeRemaining off the estimates and draws the
// rest, so a stand-in that holds what it was given answers every question the harness asks of them.
//
// The map template is the one that stores the session, which is the class's own storage in the port
// (a category cannot add an ivar), and its guidance card needs a view to draw over -- the card is
// refused when there is none, which is itself one of the checks.
// The SDK marks -init NS_UNAVAILABLE on the trip and on the maneuver, which is Apple's own rule and the
// same one the port keeps, so the harness makes its two values through Charon factories rather than
// through a call Apple's headers forbid.
@interface charonHost_CPTrip : NSObject
- (instancetype)initCharonTrip;
@end

@implementation charonHost_CPTrip

- (instancetype)initCharonTrip
{
    return [super init];
}

@end

@interface charonHost_CPManeuver : NSObject
- (instancetype)initCharonManeuver;
@end

@implementation charonHost_CPManeuver

- (instancetype)initCharonManeuver
{
    return [super init];
}

@end

@interface charonHost_CPTravelEstimates : NSObject
- (instancetype)initCharonWithTimeRemaining:(NSTimeInterval)time;
@property (nonatomic, readonly) NSTimeInterval timeRemaining;
@end

@implementation charonHost_CPTravelEstimates {
    NSTimeInterval _charon_time;
}

@synthesize timeRemaining = _charon_time;

- (instancetype)initCharonWithTimeRemaining:(NSTimeInterval)time
{
    self = [super init];
    if (self) {
        _charon_time = time;
    }
    return self;
}

@end

@interface charonHost_CPMapTemplate : NSObject
@property (nonatomic, strong) UIColor *guidanceBackgroundColor;
- (id)charon_navigationSession;
- (void)charon_setNavigationSession:(id)session;
- (UIView *)charon_mapView;
- (void)charon_setMapView:(UIView *)view;
@end

@implementation charonHost_CPMapTemplate {
    id _charon_session;
    UIView *_charon_view;
}

@synthesize guidanceBackgroundColor = _guidanceBackgroundColor;

- (id)charon_navigationSession { return _charon_session; }
- (void)charon_setNavigationSession:(id)session { _charon_session = session; }
- (UIView *)charon_mapView { return _charon_view; }
- (void)charon_setMapView:(UIView *)view { _charon_view = view; }

@end
