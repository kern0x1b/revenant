// MKMultiPolygon and MKMultiPolyline: several shapes under one overlay, so that a caller can add
// and remove them as one, and the renderers that draw them. The bounding map rect is the union of
// the members' own, through the release's own MKMapRectUnion, so a map view that adds one of these
// asks it where it is and gets the whole group.
#import <MapKit/MKMultiPolygon.h>
#import <MapKit/MKMultiPolygonRenderer.h>
#import <MapKit/MKMultiPolyline.h>
#import <MapKit/MKMultiPolylineRenderer.h>
#import "CharonMapKit.h"

@implementation MKMultiPolygon {
    NSArray<MKPolygon *> *_polygons;
}

@synthesize polygons = _polygons;

- (instancetype)initWithPolygons:(NSArray<MKPolygon *> *)polygons
{
    self = [super init];
    if (self) {
        _polygons = [polygons copy] ?: @[];
    }
    return self;
}

- (MKMapRect)boundingMapRect
{
    MKMapRect bounds = MKMapRectNull;
    for (MKPolygon *polygon in _polygons) {
        bounds = MKMapRectUnion(bounds, polygon.boundingMapRect);
    }
    return MKMapRectIsNull(bounds) ? MKMapRectWorld : bounds;
}

- (BOOL)canReplaceMapContent
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPolygons:_polygons];
}

@end

@implementation MKMultiPolygonRenderer

// The points of a shape, read out through the release's own -getCoordinates:range:. Charon's own,
// so it carries no API.
- (CLLocationCoordinate2D *)charon_coordinatesOf:(MKMultiPoint *)shape
{
    NSUInteger count = shape.pointCount;
    if (count == 0) {
        return NULL;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *)calloc(count, sizeof(CLLocationCoordinate2D));
    if (coordinates) {
        [shape getCoordinates:coordinates range:NSMakeRange(0, count)];
    }
    return coordinates;
}

- (instancetype)initWithMultiPolygon:(MKMultiPolygon *)multiPolygon
{
    self = [super initWithOverlay:multiPolygon];
    if (self) {
        self.fillColor = [[UIColor redColor] colorWithAlphaComponent:0.25];
        self.strokeColor = [UIColor redColor];
    }
    return self;
}

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    // Only a multi polygon is drawn this way; the header's own initialiser is the way in.
    if ([overlay isKindOfClass:[MKMultiPolygon class]]) {
        return [self initWithMultiPolygon:(MKMultiPolygon *)overlay];
    }
    return [super initWithOverlay:overlay];
}

- (MKMultiPolygon *)multiPolygon
{
    return (MKMultiPolygon *)self.overlay;
}

- (void)createPath
{
    MKMultiPolygon *multi = self.multiPolygon;
    if (!multi) {
        return;
    }
    CGMutablePathRef path = CGPathCreateMutable();
    if (!path) {
        return;
    }
    for (MKPolygon *polygon in multi.polygons) {
        if (polygon.pointCount == 0) {
            continue;
        }
        CLLocationCoordinate2D *coordinates = [self charon_coordinatesOf:polygon];
        if (coordinates) {
            CGPoint point = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[0])];
            CGPathMoveToPoint(path, NULL, point.x, point.y);
            for (NSUInteger index = 1; index < polygon.pointCount; index++) {
                point = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[index])];
                CGPathAddLineToPoint(path, NULL, point.x, point.y);
            }
            CGPathCloseSubpath(path);
            free(coordinates);
        }
        for (NSUInteger index = 1; index < polygon.interiorPolygons.count; index++) {
            MKPolygon *hole = polygon.interiorPolygons[index];
            CLLocationCoordinate2D *holeCoordinates = [self charon_coordinatesOf:hole];
            if (!holeCoordinates) {
                continue;
            }
            CGPoint point = [self pointForMapPoint:MKMapPointForCoordinate(holeCoordinates[hole.pointCount - 1])];
            CGPathMoveToPoint(path, NULL, point.x, point.y);
            for (NSUInteger step = hole.pointCount - 1; step > 0; step--) {
                point = [self pointForMapPoint:MKMapPointForCoordinate(holeCoordinates[step - 1])];
                CGPathAddLineToPoint(path, NULL, point.x, point.y);
            }
            CGPathCloseSubpath(path);
            free(holeCoordinates);
        }
    }
    self.path = path;
    CGPathRelease(path);
}

@end

@implementation MKMultiPolyline {
    NSArray<MKPolyline *> *_polylines;
}

@synthesize polylines = _polylines;

- (instancetype)initWithPolylines:(NSArray<MKPolyline *> *)polylines
{
    self = [super init];
    if (self) {
        _polylines = [polylines copy] ?: @[];
    }
    return self;
}

- (MKMapRect)boundingMapRect
{
    MKMapRect bounds = MKMapRectNull;
    for (MKPolyline *polyline in _polylines) {
        bounds = MKMapRectUnion(bounds, polyline.boundingMapRect);
    }
    return MKMapRectIsNull(bounds) ? MKMapRectWorld : bounds;
}

- (BOOL)canReplaceMapContent
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPolylines:_polylines];
}

@end

@implementation MKMultiPolylineRenderer

- (instancetype)initWithMultiPolyline:(MKMultiPolyline *)multiPolyline
{
    self = [super initWithOverlay:multiPolyline];
    if (self) {
        self.strokeColor = [UIColor blueColor];
    }
    return self;
}

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKMultiPolyline class]]) {
        return [self initWithMultiPolyline:(MKMultiPolyline *)overlay];
    }
    return [super initWithOverlay:overlay];
}

- (MKMultiPolyline *)multiPolyline
{
    return (MKMultiPolyline *)self.overlay;
}

- (void)createPath
{
    MKMultiPolyline *multi = self.multiPolyline;
    if (!multi) {
        return;
    }
    CGMutablePathRef path = CGPathCreateMutable();
    if (!path) {
        return;
    }
    for (MKPolyline *polyline in multi.polylines) {
        if (polyline.pointCount == 0) {
            continue;
        }
        CLLocationCoordinate2D *coordinates = [(MKMultiPolygonRenderer *)self charon_coordinatesOf:polyline];
        if (!coordinates) {
            continue;
        }
        CGPoint point = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[0])];
        CGPathMoveToPoint(path, NULL, point.x, point.y);
        for (NSUInteger index = 1; index < polyline.pointCount; index++) {
            point = [self pointForMapPoint:MKMapPointForCoordinate(coordinates[index])];
            CGPathAddLineToPoint(path, NULL, point.x, point.y);
        }
        free(coordinates);
    }
    self.path = path;
    CGPathRelease(path);
}

@end
