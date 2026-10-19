#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface revenantHost_CPTemplate : NSObject
@end

@implementation revenantHost_CPTemplate

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

@end

@interface revenantHost_CPTrip : NSObject
- (instancetype)initRevenantTrip;
@end

@implementation revenantHost_CPTrip

- (instancetype)initRevenantTrip
{
    return [super init];
}

@end

@interface revenantHost_CPManeuver : NSObject
- (instancetype)initRevenantManeuver;
@end

@implementation revenantHost_CPManeuver

- (instancetype)initRevenantManeuver
{
    return [super init];
}

@end

@interface revenantHost_CPTravelEstimates : NSObject
- (instancetype)initRevenantWithTimeRemaining:(NSTimeInterval)time;
@property (nonatomic, readonly) NSTimeInterval timeRemaining;
@end

@implementation revenantHost_CPTravelEstimates {
    NSTimeInterval _revenant_time;
}

@synthesize timeRemaining = _revenant_time;

- (instancetype)initRevenantWithTimeRemaining:(NSTimeInterval)time
{
    self = [super init];
    if (self) {
        _revenant_time = time;
    }
    return self;
}

@end

@interface revenantHost_CPMapTemplate : NSObject
@property (nonatomic, strong) UIColor *guidanceBackgroundColor;
- (id)revenant_navigationSession;
- (void)revenant_setNavigationSession:(id)session;
- (UIView *)revenant_mapView;
- (void)revenant_setMapView:(UIView *)view;
@end

@implementation revenantHost_CPMapTemplate {
    id _revenant_session;
    UIView *_revenant_view;
}

@synthesize guidanceBackgroundColor = _guidanceBackgroundColor;

- (id)revenant_navigationSession { return _revenant_session; }
- (void)revenant_setNavigationSession:(id)session { _revenant_session = session; }
- (UIView *)revenant_mapView { return _revenant_view; }
- (void)revenant_setMapView:(UIView *)view { _revenant_view = view; }

@end
