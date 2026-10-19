#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "RevenantMapKit.h"

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

- (void)revenant_indicesForStrokeStart:(double)start end:(double)end
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

- (void)revenant_addPolyline:(MKPolyline *)polyline toPath:(CGMutablePathRef)path
{
    NSUInteger count = polyline.pointCount;
    if (count == 0) {
        return;
    }
    NSUInteger first, last;
    [self revenant_indicesForStrokeStart:(double)self.strokeStart end:(double)self.strokeEnd
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
    [self revenant_addPolyline:polyline toPath:path];
    self.path = path;
    CGPathRelease(path);
}

@end
