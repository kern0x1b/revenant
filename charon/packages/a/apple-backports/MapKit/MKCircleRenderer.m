// MKCircleRenderer: a circle drawn as the ellipse inscribed in the circle's own bounding map rect,
// and the partial-stroke range iOS 14 added (strokeStart and strokeEnd, each a fraction of the
// circle's sweep, 0 to 1, defaulting to the whole circle).
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "CharonMapKit.h"

@implementation MKCircleRenderer {
    CGFloat _strokeStart;
    CGFloat _strokeEnd;
}

@synthesize strokeStart = _strokeStart;
@synthesize strokeEnd = _strokeEnd;

- (instancetype)initWithCircle:(MKCircle *)circle
{
    self = [super initWithOverlay:circle];
    if (self) {
        _strokeStart = 0.0;
        _strokeEnd = 1.0;
    }
    return self;
}

- (MKCircle *)circle
{
    return (MKCircle *)self.overlay;
}

- (void)setCircle:(MKCircle *)circle
{
    self.overlay = circle;
    [self invalidatePath];
}

- (void)createPath
{
    MKCircle *circle = self.circle;
    if (!circle) {
        return;
    }
    MKMapRect bounds = circle.boundingMapRect;
    CGRect rect = [self rectForMapRect:MKMapRectIntersection(bounds, MKMapRectWorld)];
    if (CGRectIsNull(rect)) {
        return;
    }
    CGRect box = CGRectStandardize(rect);
    if (CGRectGetWidth(box) <= 0.0 || CGRectGetHeight(box) <= 0.0) {
        return;
    }
    CGFloat start = (CGFloat)self.strokeStart;
    CGFloat end = (CGFloat)self.strokeEnd;
    CGMutablePathRef path = CGPathCreateMutable();
    if (!path) {
        return;
    }
    // A whole circle: the ellipse, which is what the release's own MKCircleView drew. A part of
    // one: the same ellipse's arc from the start fraction round to the end fraction, with the
    // fractions taken over the sweep from due south, so 0.25 is east and 0.5 is north. The arc is
    // built as a polyline, which is how the release's own path flattening draws one too: the
    // release's CoreGraphics has CGPathAddArc for circles only, and no way to add an elliptical
    // arc with independent radii to a path while a transform is in force.
    if (start <= 0.0 && end >= 1.0) {
        CGPathAddEllipseInRect(path, NULL, box);
    } else {
        CGPoint centre = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
        double radiusX = CGRectGetWidth(box) / 2.0;
        double radiusY = CGRectGetHeight(box) / 2.0;
        double from = end * 2.0 * M_PI - M_PI / 2.0;
        double sweep = (start - end) * 2.0 * M_PI;
        if (fabs(sweep) < 1e-9) {
            sweep = 2.0 * M_PI;
        }
        NSUInteger steps = (NSUInteger)MIN(MAX(fabs(sweep) * MAX(radiusX, radiusY) / 2.0, 16.0), 720.0);
        for (NSUInteger index = 0; index <= steps; index++) {
            double angle = from + sweep * (double)index / (double)steps;
            CGPoint point = CGPointMake((CGFloat)(centre.x + radiusX * cos(angle)),
                                        (CGFloat)(centre.y + radiusY * sin(angle)));
            if (index == 0) {
                CGPathMoveToPoint(path, NULL, point.x, point.y);
            } else {
                CGPathAddLineToPoint(path, NULL, point.x, point.y);
            }
        }
    }
    self.path = path;
    CGPathRelease(path);
}

@end
