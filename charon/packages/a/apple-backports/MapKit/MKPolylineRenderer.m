// MKPolylineRenderer: a polyline drawn through its own points, and the partial-stroke range iOS 14
// added (strokeStart and strokeEnd, each a fraction of the line's points from its start, 0 to 1).
// The fraction is taken over the line's own point count, so a stroke that starts half way through
// a ten-point polyline starts at its sixth point.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "CharonMapKit.h"

@implementation MKPolylineRenderer {
    CGFloat _strokeStart;
    CGFloat _strokeEnd;
}

@synthesize strokeStart = _strokeStart;
@synthesize strokeEnd = _strokeEnd;

- (instancetype)initWithPolyline:(MKPolyline *)polyline
{
    self = [super initWithOverlay:polyline];
    if (self) {
        _strokeStart = 0.0;
        _strokeEnd = 1.0;
    }
    return self;
}

- (MKPolyline *)polyline
{
    return (MKPolyline *)self.overlay;
}

- (void)setPolyline:(MKPolyline *)polyline
{
    self.overlay = polyline;
    [self invalidatePath];
}

// The indices of the points a stroke from start to end of the line covers, for MKPolyline and for
// the sub-polylines of an MKMultiPolyline. Charon's own, so it carries no API.
- (void)charon_indicesForStrokeStart:(double)start end:(double)end
                                count:(NSUInteger)count
                                first:(NSUInteger *)outFirst
                                 last:(NSUInteger *)outLast
{
    *outFirst = 0;
    *outLast = count > 0 ? count - 1 : 0;
    if (count < 2) {
        return;
    }
    double from = start * (double)(count - 1);
    double to = end * (double)(count - 1);
    NSInteger first = (NSInteger)ceil(from - 1e-9);
    NSInteger last = (NSInteger)floor(to + 1e-9);
    if (first < 0) {
        first = 0;
    }
    if (last > (NSInteger)count - 1) {
        last = (NSInteger)count - 1;
    }
    if (last < first) {
        *outFirst = (NSUInteger)first;
        *outLast = *outFirst;
        return;
    }
    *outFirst = (NSUInteger)first;
    *outLast = (NSUInteger)last;
}

- (void)charon_addPolyline:(MKPolyline *)polyline toPath:(CGMutablePathRef)path
{
    NSUInteger count = polyline.pointCount;
    if (count == 0) {
        return;
    }
    NSUInteger first, last;
    [self charon_indicesForStrokeStart:(double)self.strokeStart end:(double)self.strokeEnd
                                 count:count first:&first last:&last];
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *)calloc(count, sizeof(CLLocationCoordinate2D));
    if (!coordinates) {
        return;
    }
    [polyline getCoordinates:coordinates range:NSMakeRange(0, count)];
    MKMapPoint from = MKMapPointForCoordinate(coordinates[first]);
    CGPoint point = [self pointForMapPoint:from];
    CGPathMoveToPoint(path, NULL, point.x, point.y);
    for (NSUInteger index = first + 1; index <= last; index++) {
        point = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[index])];
        CGPathAddLineToPoint(path, NULL, point.x, point.y);
    }
    if (first == last) {
        // A stroke of no length is a point: MapKit draws the cap there, so the path says so too.
        CGPathAddLineToPoint(path, NULL, point.x, point.y);
    }
    free(coordinates);
}

- (void)createPath
{
    MKPolyline *polyline = self.polyline;
    if (!polyline || polyline.pointCount == 0) {
        return;
    }
    CGMutablePathRef path = CGPathCreateMutable();
    if (!path) {
        return;
    }
    [self charon_addPolyline:polyline toPath:path];
    self.path = path;
    CGPathRelease(path);
}

@end
