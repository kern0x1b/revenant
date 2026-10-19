// MKCompassButton and MKUserTrackingButton: the two buttons iOS 11 put on a map, each one doing
// what its name says on a map the release's own MKMapView draws.
//
// The compass is a rose bound to the map view's heading: it points at north as the map turns, and
// tapping it turns the map back to north, which on this port is the transform being animated back to
// the zero rotation. The tracking button is bound to the release's own -userTrackingMode and
// -setUserTrackingMode:animated:, which is in the armv7 cache of 6.1.3 (measured), so following the
// user and this button are the release's own mechanism and not a copy of it.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>
#import "CharonMapKit.h"

// The heading the rose is drawn at, and the map view it drives. Both are this port's own: the
// header's MKCompassButton has a read-only mapView and nothing else, and a rose needs to know how
// far the map has turned.
@interface MKCompassButton ()
@property (nonatomic) CLLocationDirection compassHeading;
@end

@implementation MKCompassButton

@synthesize mapView = _mapView;
@synthesize compassHeading = _compassHeading;
@synthesize compassVisibility = _compassVisibility;

+ (instancetype)compassButtonWithMapView:(MKMapView *)mapView
{
    MKCompassButton *button = [[self alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];
    if (button) {
        button.mapView = mapView;
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        button.layer.cornerRadius = 22.0;
        button.accessibilityLabel = @" compass";
        [(UIControl *)button addTarget:button action:@selector(charon_faceNorth)
                     forControlEvents:UIControlEventTouchUpInside];
    }
    return button;
}

- (void)setMapView:(MKMapView *)mapView
{
    _mapView = mapView;
    [self setNeedsDisplay];
}

- (void)setCompassHeading:(CLLocationDirection)heading
{
    _compassHeading = heading;
    [self setNeedsDisplay];
}

// The header's own visibility: visible always, never, or when the map is not facing north, which is
// the one case where a compass has anything to say.
- (void)setCompassVisibility:(MKFeatureVisibility)compassVisibility
{
    _compassVisibility = compassVisibility;
    [self charon_updateVisibility];
}

- (void)charon_updateVisibility
{
    switch (_compassVisibility) {
        case MKFeatureVisibilityHidden:
            self.hidden = YES;
            break;
        case MKFeatureVisibilityVisible:
            self.hidden = NO;
            break;
        default:
            // Adaptive: a compass on a map that is already facing north has nothing to point at.
            self.hidden = fabs((double)fmod((double)_compassHeading, 360.0)) < 0.5;
            break;
    }
}

// The rose: an arrow that points at the map's own north, so it turns as the map does.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGRect box = CGRectInset(self.bounds, 4.0, 4.0);
    CGPoint centre = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
    CGFloat radius = MIN(CGRectGetWidth(box), CGRectGetHeight(box)) / 2.0;
    // The arrow is drawn pointing north and then turned by the heading, which is the map's own turn,
    // so the arrow points at the map's north and not at the screen's.
    CGFloat radians = (CGFloat)((double)_compassHeading * M_PI / 180.0);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, centre.x, centre.y);
    CGContextRotateCTM(context, -radians);
    UIBezierPath *needle = [UIBezierPath bezierPath];
    [needle moveToPoint:CGPointMake(0.0, -radius)];
    [needle addLineToPoint:CGPointMake(radius / 3.0, radius / 2.0)];
    [needle addLineToPoint:CGPointMake(0.0, radius / 4.0)];
    [needle addLineToPoint:CGPointMake(-radius / 3.0, radius / 2.0)];
    [needle closePath];
    [[UIColor redColor] setFill];
    [needle fill];
    CGContextRestoreGState(context);
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:9.0],
                                 NSForegroundColorAttributeName: [UIColor blackColor]};
    [@"N" drawAtPoint:CGPointMake(CGRectGetMidX(box) - 3.0, CGRectGetMinY(box)) withAttributes:attributes];
}

// The map back to north, which on this port is the rotation being animated back to zero. The
// animation is the map view's own -setRegion:animated:, so the tiles and the annotations move
// together. Charon's own, so it carries no API.
- (void)charon_faceNorth
{
    MKMapView *mapView = self.mapView;
    SEL animate = NSSelectorFromString(@"setCamera:animated:");
    if (!mapView || ![mapView respondsToSelector:animate]) {
        return;
    }
    id (*send)(id, SEL, id, BOOL) = (id (*)(id, SEL, id, BOOL))objc_msgSend;
    send(mapView, animate, [self charon_cameraFacingNorth], YES);
}

- (MKMapCamera *)charon_cameraFacingNorth
{
    MKMapCamera *camera = [MKMapCamera camera];
    camera.centerCoordinate = self.mapView ? self.mapView.centerCoordinate : CLLocationCoordinate2DMake(0.0, 0.0);
    camera.heading = 0.0;
    camera.pitch = 0.0;
    return camera;
}

@end

// The tracking mode the button last carried, which the header's own -setTrackingMode:animated: takes
// and -charon_tracking reads, and which the map view's own -userTrackingMode overwrites whenever
// there is a map view to answer it.
@interface MKUserTrackingButton ()
@property (nonatomic) MKUserTrackingMode trackingMode;
@end

@implementation MKUserTrackingButton

@synthesize mapView = _mapView;
@synthesize trackingMode = _trackingMode;

+ (instancetype)userTrackingButtonWithMapView:(MKMapView *)mapView
{
    MKUserTrackingButton *button = [[self alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];
    if (button) {
        button.mapView = mapView;
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        button.layer.cornerRadius = 22.0;
        button.accessibilityLabel = @" tracking";
        [(UIControl *)button addTarget:button action:@selector(charon_toggle)
                     forControlEvents:UIControlEventTouchUpInside];
        [button charon_update];
    }
    return button;
}

- (void)setMapView:(MKMapView *)mapView
{
    _mapView = mapView;
    [self charon_update];
}

// The button's own mode, which is the map view's own -userTrackingMode when there is a map view and
// what the caller last set through -setTrackingMode:animated: when there is not, so the two spellings
// of the same question -- the header's own on the button and the release's own on the map view --
// never disagree.
- (BOOL)charon_tracking
{
    if (self.mapView) {
        return self.mapView.userTrackingMode == MKUserTrackingModeFollow;
    }
    return _trackingMode == MKUserTrackingModeFollow;
}

// The header's own member: put a map into following, or out of it, with the caller's own animated
// flag -- through the release's own -setUserTrackingMode:animated:, which is what the tap uses too,
// so there is one mechanism and not two.
- (void)setTrackingMode:(MKUserTrackingMode)trackingMode animated:(BOOL)animated
{
    _trackingMode = trackingMode;
    MKMapView *mapView = self.mapView;
    if (mapView) {
        [mapView setUserTrackingMode:trackingMode animated:animated];
    }
    [self charon_update];
}

// Following the user is the release's own -setUserTrackingMode:animated:, which is in the armv7
// cache of 6.1.3, so the button drives the release's mechanism and the release's own user location
// view does the rest. Charon's own, so it carries no API.
- (void)charon_toggle
{
    MKMapView *mapView = self.mapView;
    if (!mapView) {
        return;
    }
    BOOL following = [self charon_tracking];
    [mapView setUserTrackingMode:following ? MKUserTrackingModeNone : MKUserTrackingModeFollow animated:YES];
    [self charon_update];
}

- (void)charon_update
{
    BOOL tracking = [self charon_tracking];
    self.layer.borderWidth = tracking ? 2.0 : 0.0;
    self.layer.borderColor = [UIColor blueColor].CGColor;
    [self setNeedsDisplay];
}

// The crosshair: the release's own user location view is the blue dot, and this is the ring that says
// the map is following it.
- (void)drawRect:(CGRect)rect
{
    if (![self charon_tracking]) {
        return;
    }
    CGRect box = CGRectInset(self.bounds, 10.0, 10.0);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:box];
    [[UIColor blueColor] setStroke];
    ring.lineWidth = 2.0;
    [ring stroke];
}

@end
