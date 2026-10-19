// MKGradientPolylineRenderer: a polyline whose colour changes along its length, which the iOS 14
// header adds to the polyline renderer. The gradient is drawn for real: the line's own path is
// clipped to, and a linear gradient with the caller's own colours at the caller's own fractions runs
// along the line from its first point to its last, so a two-colour gradient on a two-point polyline
// is that polyline's two ends in those two colours.
#import <MapKit/MKGradientPolylineRenderer.h>
#import <UIKit/UIKit.h>
#import "CharonMapKit.h"

@implementation MKGradientPolylineRenderer

@synthesize colors = _colors;
@synthesize locations = _locations;

- (instancetype)initWithPolyline:(MKPolyline *)polyline
{
    self = [super initWithPolyline:polyline];
    if (self) {
        _colors = @[[UIColor redColor], [UIColor blueColor]];
        _locations = nil;
    }
    return self;
}

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        return [self initWithPolyline:(MKPolyline *)overlay];
    }
    return [super initWithOverlay:overlay];
}

- (void)setColors:(NSArray<UIColor *> *)colors
{
    _colors = [colors copy];
    [self setNeedsDisplay];
}

- (void)setColors:(NSArray<UIColor *> *)colors atLocations:(NSArray<NSNumber *> *)locations
{
    _colors = [colors copy];
    _locations = [locations copy];
    [self setNeedsDisplay];
}

- (void)setLocations:(NSArray<NSNumber *> *)locations
{
    _locations = [locations copy];
    [self setNeedsDisplay];
}

// The first and the last point of the line, which is the run the gradient follows. Charon's own,
// so it carries no API.
- (BOOL)charon_gradientFromPoint:(CGPoint *)outFrom toPoint:(CGPoint *)outTo
{
    MKPolyline *polyline = self.polyline;
    if (!polyline || polyline.pointCount < 2) {
        return NO;
    }
    NSUInteger count = polyline.pointCount;
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *)calloc(count, sizeof(CLLocationCoordinate2D));
    if (!coordinates) {
        return NO;
    }
    [polyline getCoordinates:coordinates range:NSMakeRange(0, count)];
    *outFrom = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[0])];
    *outTo = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[count - 1])];
    free(coordinates);
    return YES;
}

- (void)charon_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect
{
    CGPathRef path = self.path;
    CGPoint from, to;
    if (!path || _colors.count == 0 || ![self charon_gradientFromPoint:&from toPoint:&to]) {
        return;
    }
    if (CGPointEqualToPoint(from, to)) {
        // A line whose two ends are at the same point has no direction to run the gradient along,
        // so the first colour is drawn along it, which is what a gradient of zero length collapses to.
        [[self charon_colorAtIndex:0] setStroke];
        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        CGContextSetLineWidth(context, [(MKOverlayPathRenderer *)self charon_lineWidthAtZoomScale:zoomScale]);
        CGContextStrokePath(context);
        return;
    }
    NSUInteger count = _colors.count;
    NSMutableArray *tinted = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        [tinted addObject:(__bridge id)[[self charon_colorAtIndex:index] CGColor]];
    }
    CGFloat *stops = NULL;
    if (_locations.count == count) {
        stops = (CGFloat *)calloc(count, sizeof(CGFloat));
        if (stops) {
            for (NSUInteger index = 0; index < count; index++) {
                stops[index] = (CGFloat)[_locations[index] doubleValue];
            }
        }
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = space && count > 0 ? CGGradientCreateWithColors(space, (__bridge CFArrayRef)tinted, stops) : NULL;
    CGContextSaveGState(context);
    [self applyStrokePropertiesToContext:context atZoomScale:zoomScale];
    CGContextSetLineWidth(context, [(MKOverlayPathRenderer *)self charon_lineWidthAtZoomScale:zoomScale]);
    CGContextAddPath(context, path);
    CGContextReplacePathWithStrokedPath(context);
    CGContextClip(context);
    if (gradient) {
        CGContextDrawLinearGradient(context, gradient, from, to, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    }
    CGContextRestoreGState(context);
    if (gradient) {
        CGGradientRelease(gradient);
    }
    if (space) {
        CGColorSpaceRelease(space);
    }
    free(stops);
}

// The colour of one end of the gradient, with the linear fall-off the header describes: with no
// locations given, the colours run evenly along the line. Charon's own, so it carries no API.
- (UIColor *)charon_colorAtIndex:(NSUInteger)index
{
    NSUInteger count = _colors.count;
    if (count == 0) {
        return [UIColor blackColor];
    }
    if (index >= count) {
        return _colors[count - 1];
    }
    return _colors[index];
}

@end
