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
