#import <MapKit/MKGradientPolylineRenderer.h>
#import <UIKit/UIKit.h>
#import "RevenantMapKit.h"

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

- (BOOL)revenant_gradientFromPoint:(CGPoint *)outFrom toPoint:(CGPoint *)outTo
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

- (void)revenant_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect
{
    CGPathRef path = self.path;
    CGPoint from, to;
    if (!path || _colors.count == 0 || ![self revenant_gradientFromPoint:&from toPoint:&to]) {
        return;
    }
    if (CGPointEqualToPoint(from, to)) {
        [[self revenant_colorAtIndex:0] setStroke];
        CGContextBeginPath(context);
        CGContextAddPath(context, path);
        CGContextSetLineWidth(context, [(MKOverlayPathRenderer *)self revenant_lineWidthAtZoomScale:zoomScale]);
        CGContextStrokePath(context);
        return;
    }
    NSUInteger count = _colors.count;
    NSMutableArray *tinted = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        [tinted addObject:(__bridge id)[[self revenant_colorAtIndex:index] CGColor]];
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
    CGContextSetLineWidth(context, [(MKOverlayPathRenderer *)self revenant_lineWidthAtZoomScale:zoomScale]);
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

- (UIColor *)revenant_colorAtIndex:(NSUInteger)index
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
