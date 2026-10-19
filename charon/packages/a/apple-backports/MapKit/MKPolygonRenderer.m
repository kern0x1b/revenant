// MKPolygonRenderer: a polygon drawn as a closed path through its own points, with the holes of a
// polygon that has them cut out of it the way MapKit documents (each interior ring drawn with the
// opposite winding, so one fill leaves them open), and the partial-stroke range iOS 14 added.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "CharonMapKit.h"

@implementation MKPolygonRenderer {
    CGFloat _strokeStart;
    CGFloat _strokeEnd;
}

@synthesize strokeStart = _strokeStart;
@synthesize strokeEnd = _strokeEnd;

- (instancetype)initWithPolygon:(MKPolygon *)polygon
{
    self = [super initWithOverlay:polygon];
    if (self) {
        _strokeStart = 0.0;
        _strokeEnd = 1.0;
    }
    return self;
}

- (MKPolygon *)polygon
{
    return (MKPolygon *)self.overlay;
}

- (void)setPolygon:(MKPolygon *)polygon
{
    self.overlay = polygon;
    [self invalidatePath];
}

// A ring drawn as a closed polyline, with the stroke taken from the fraction of the ring's points
// the caller asked for. Charon's own, so it carries no API.
- (void)charon_addRing:(const CLLocationCoordinate2D *)coordinates
                  count:(NSUInteger)count
              start:(double)start
                    end:(double)end
              reversed:(BOOL)reversed
                 toPath:(CGMutablePathRef)path
{
    if (count == 0) {
        return;
    }
    NSUInteger first = 0;
    NSUInteger last = count - 1;
    if (count > 1) {
        double from = start * (double)(count - 1);
        double to = end * (double)(count - 1);
        NSInteger low = (NSInteger)ceil(from - 1e-9);
        NSInteger high = (NSInteger)floor(to + 1e-9);
        if (low < 0) {
            low = 0;
        }
        if (high > (NSInteger)count - 1) {
            high = (NSInteger)count - 1;
        }
        first = (NSUInteger)low;
        last = (NSUInteger)high;
    }
    NSUInteger steps = reversed ? first + (last - first) : last - first;
    CGPoint previous = CGPointZero;
    for (NSUInteger index = 0; index <= steps; index++) {
        NSUInteger point = reversed ? (last - index) : (first + index);
        CGPoint mapped = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[point])];
        if (index == 0) {
            CGPathMoveToPoint(path, NULL, mapped.x, mapped.y);
        } else {
            CGPathAddLineToPoint(path, NULL, mapped.x, mapped.y);
        }
        previous = mapped;
    }
    if (steps == 0) {
        CGPathAddLineToPoint(path, NULL, previous.x, previous.y);
    } else {
        CGPathCloseSubpath(path);
    }
}

// The points of one ring, read out through the release's own -getCoordinates:range:.
- (void)charon_addRingOf:(MKPolygon *)polygon
                    count:(NSUInteger)count
                    start:(double)start
                      end:(double)end
                 reversed:(BOOL)reversed
                   toPath:(CGMutablePathRef)path
{
    if (count == 0) {
        return;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *)calloc(count, sizeof(CLLocationCoordinate2D));
    if (!coordinates) {
        return;
    }
    [polygon getCoordinates:coordinates range:NSMakeRange(0, count)];
    [self charon_addRing:coordinates count:count start:start end:end reversed:reversed toPath:path];
    free(coordinates);
}

- (void)createPath
{
    MKPolygon *polygon = self.polygon;
    if (!polygon || polygon.pointCount == 0) {
        return;
    }
    CGMutablePathRef path = CGPathCreateMutable();
    if (!path) {
        return;
    }
    double start = (double)self.strokeStart;
    double end = (double)self.strokeEnd;
    [self charon_addRingOf:polygon count:polygon.pointCount start:start end:end reversed:NO toPath:path];
    // The interior rings run the other way round, which is what makes one fill leave them open.
    for (NSUInteger index = 1; index < polygon.interiorPolygons.count; index++) {
        MKPolygon *hole = polygon.interiorPolygons[index];
        if (hole.pointCount > 0) {
            [self charon_addRingOf:hole count:hole.pointCount start:start end:end reversed:YES toPath:path];
        }
    }
    self.path = path;
    CGPathRelease(path);
}

@end
