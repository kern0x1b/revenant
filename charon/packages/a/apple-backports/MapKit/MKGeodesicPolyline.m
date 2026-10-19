// MKGeodesicPolyline: a polyline that follows the shortest path over the earth's surface rather than
// a straight line in the projected plane. The two differ by the great-circle flattening the header
// describes, and the release's own MKPolyline cannot do it, so the points are computed here: the
// great-circle interpolation between each pair of the caller's own points, sampled finely enough
// that the drawn line is the curve to within a pixel at any zoom scale the map view will use.
//
// The instance is a real MKPolyline -- the header's own superclass -- filled through the release's
// own -[MKMultiPoint setCoordinates:count:], which is in the armv7 dyld shared cache of 6.1.3
// (measured) and is how the release's own +[MKPolyline polylineWithCoordinates:count:] builds one.
// So the object is a subclass of MKPolyline in the runtime's own terms, and a caller that hands it
// to an MKPolylineRenderer or an MKMultiPolyline gets an MKPolyline.
#import <MapKit/MKGeodesicPolyline.h>
#import <CoreLocation/CoreLocation.h>
#import <math.h>
#import "CharonMapKit.h"

// The release's own mutating setter, measured present in the armv7 cache of 6.1.3. Declared here and
// not implemented: the class it names is the release's, and so is the method.
@interface MKMultiPoint (CharonCoordinates)
- (void)setCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
@end

@implementation MKGeodesicPolyline

// The angular distance between two coordinates on the sphere, in radians.
+ (double)charon_angleFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to
{
    static const double pi = 3.14159265358979323846;
    double lat1 = from.latitude * pi / 180.0;
    double lat2 = to.latitude * pi / 180.0;
    double deltaLat = (to.latitude - from.latitude) * pi / 180.0;
    double deltaLon = (to.longitude - from.longitude) * pi / 180.0;
    double a = sin(deltaLat / 2.0) * sin(deltaLat / 2.0) +
               cos(lat1) * cos(lat2) * sin(deltaLon / 2.0) * sin(deltaLon / 2.0);
    return 2.0 * asin(fmin(1.0, sqrt(a)));
}

// The point a fraction of the way along the great circle from one coordinate to another, by the
// spherical formula: the angle from the start, and the great-circle destination formula applied
// to the two endpoints with the weights sin of the two remaining angles.
+ (CLLocationCoordinate2D)charon_coordinateFromCoordinate:(CLLocationCoordinate2D)from
                                             toCoordinate:(CLLocationCoordinate2D)to
                                                fraction:(double)fraction
{
    static const double pi = 3.14159265358979323846;
    CLLocationCoordinate2D result = from;
    double delta = [self charon_angleFromCoordinate:from toCoordinate:to];
    if (delta < 1e-12) {
        return result;
    }
    double sinDelta = sin(delta);
    double a = sin((1.0 - fraction) * delta) / sinDelta;
    double b = sin(fraction * delta) / sinDelta;
    double lat1 = from.latitude * pi / 180.0;
    double lon1 = from.longitude * pi / 180.0;
    double lat2 = to.latitude * pi / 180.0;
    double lon2 = to.longitude * pi / 180.0;
    double x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2);
    double y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2);
    double z = a * sin(lat1) + b * sin(lat2);
    result.longitude = atan2(y, x) * 180.0 / pi;
    result.latitude = atan2(z, sqrt(x * x + y * y)) * 180.0 / pi;
    return result;
}

+ (instancetype)polylineWithPoints:(const MKMapPoint *)points count:(NSUInteger)count
{
    if (!points || count == 0) {
        return nil;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D *)calloc(count, sizeof(CLLocationCoordinate2D));
    if (!coordinates) {
        return nil;
    }
    for (NSUInteger index = 0; index < count; index++) {
        coordinates[index] = MKCoordinateForMapPoint(points[index]);
    }
    MKGeodesicPolyline *line = (MKGeodesicPolyline *)[self polylineWithCoordinates:coordinates count:count];
    free(coordinates);
    return line;
}

+ (instancetype)polylineWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count
{
    if (!coords || count == 0) {
        return nil;
    }
    // Sampled so the drawn curve stays within about a pixel of the true arc at any zoom scale the
    // map view reaches: two degrees of arc per sample, at least one per caller's own segment, and
    // never more than 2048 for one segment so a caller cannot make this unbounded.
    static const double pi = 3.14159265358979323846;
    NSUInteger capacity = count * 64 + 1;
    CLLocationCoordinate2D *flat = (CLLocationCoordinate2D *)malloc(capacity * sizeof(CLLocationCoordinate2D));
    if (!flat) {
        return nil;
    }
    NSUInteger sampled = 0;
    flat[sampled++] = coords[0];
    for (NSUInteger index = 1; index < count; index++) {
        CLLocationCoordinate2D from = sampled > 0 ? flat[sampled - 1] : coords[index - 1];
        CLLocationCoordinate2D to = coords[index];
        double degrees = [self charon_angleFromCoordinate:from toCoordinate:to] * 180.0 / pi;
        NSUInteger steps = (NSUInteger)fmin(fmax(ceil(degrees / 2.0), 1.0), 2048.0);
        if (sampled + steps > capacity) {
            break;
        }
        for (NSUInteger step = 1; step < steps; step++) {
            flat[sampled++] = [self charon_coordinateFromCoordinate:from toCoordinate:to
                                                            fraction:(double)step / (double)steps];
        }
        if (sampled + 1 <= capacity) {
            flat[sampled++] = to;
        }
    }
    MKGeodesicPolyline *line = [[self alloc] init];
    if (!line) {
        free(flat);
        return nil;
    }
    [line setCoordinates:flat count:sampled];
    free(flat);
    // The release's own setter is what filled the object; if it took the points the object is a
    // polyline of them, and if it did not there is no polyline to hand back and nil is the honest
    // answer rather than an object that draws nothing.
    if (!line || line.pointCount != sampled) {
        return nil;
    }
    return line;
}

@end
