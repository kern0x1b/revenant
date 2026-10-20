#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <math.h>
#import "RevenantMapKit.h"

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
        [(UIControl *)button addTarget:button action:@selector(revenant_faceNorth)
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

- (void)setCompassVisibility:(MKFeatureVisibility)compassVisibility
{
    _compassVisibility = compassVisibility;
    [self revenant_updateVisibility];
}

- (void)revenant_updateVisibility
{
    switch (_compassVisibility) {
        case MKFeatureVisibilityHidden:
            self.hidden = YES;
            break;
        case MKFeatureVisibilityVisible:
            self.hidden = NO;
            break;
        default:
            self.hidden = fabs((double)fmod((double)_compassHeading, 360.0)) < 0.5;
            break;
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGRect box = CGRectInset(self.bounds, 4.0, 4.0);
    CGPoint centre = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
    CGFloat radius = MIN(CGRectGetWidth(box), CGRectGetHeight(box)) / 2.0;
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

- (void)revenant_faceNorth
{
    MKMapView *mapView = self.mapView;
    SEL animate = NSSelectorFromString(@"setCamera:animated:");
    if (!mapView || ![mapView respondsToSelector:animate]) {
        return;
    }
    id (*send)(id, SEL, id, BOOL) = (id (*)(id, SEL, id, BOOL))objc_msgSend;
    send(mapView, animate, [self revenant_cameraFacingNorth], YES);
}

- (MKMapCamera *)revenant_cameraFacingNorth
{
    MKMapCamera *camera = [MKMapCamera camera];
    camera.centerCoordinate = self.mapView ? self.mapView.centerCoordinate : CLLocationCoordinate2DMake(0.0, 0.0);
    camera.heading = 0.0;
    camera.pitch = 0.0;
    return camera;
}

@end

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
        [(UIControl *)button addTarget:button action:@selector(revenant_toggle)
                     forControlEvents:UIControlEventTouchUpInside];
        [button revenant_update];
    }
    return button;
}

- (void)setMapView:(MKMapView *)mapView
{
    _mapView = mapView;
    [self revenant_update];
}

- (BOOL)revenant_tracking
{
    if (self.mapView) {
        return self.mapView.userTrackingMode == MKUserTrackingModeFollow;
    }
    return _trackingMode == MKUserTrackingModeFollow;
}

- (void)setTrackingMode:(MKUserTrackingMode)trackingMode animated:(BOOL)animated
{
    _trackingMode = trackingMode;
    MKMapView *mapView = self.mapView;
    if (mapView) {
        [mapView setUserTrackingMode:trackingMode animated:animated];
    }
    [self revenant_update];
}

- (void)revenant_toggle
{
    MKMapView *mapView = self.mapView;
    if (!mapView) {
        return;
    }
    BOOL following = [self revenant_tracking];
    [mapView setUserTrackingMode:following ? MKUserTrackingModeNone : MKUserTrackingModeFollow animated:YES];
    [self revenant_update];
}

- (void)revenant_update
{
    BOOL tracking = [self revenant_tracking];
    self.layer.borderWidth = tracking ? 2.0 : 0.0;
    self.layer.borderColor = [UIColor blueColor].CGColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (![self revenant_tracking]) {
        return;
    }
    CGRect box = CGRectInset(self.bounds, 10.0, 10.0);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:box];
    [[UIColor blueColor] setStroke];
    ring.lineWidth = 2.0;
    [ring stroke];
}

@end
