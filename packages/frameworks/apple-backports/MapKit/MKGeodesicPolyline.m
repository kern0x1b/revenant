#import <MapKit/MKGeodesicPolyline.h>
#import <CoreLocation/CoreLocation.h>
#import <math.h>
#import "RevenantMapKit.h"

@interface MKMultiPoint (RevenantCoordinates)
- (void)setCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
@end

@implementation MKGeodesicPolyline

+ (double)revenant_angleFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to
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

+ (CLLocationCoordinate2D)revenant_coordinateFromCoordinate:(CLLocationCoordinate2D)from
                                             toCoordinate:(CLLocationCoordinate2D)to
                                                fraction:(double)fraction
{
    static const double pi = 3.14159265358979323846;
    CLLocationCoordinate2D result = from;
    double delta = [self revenant_angleFromCoordinate:from toCoordinate:to];
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
        double degrees = [self revenant_angleFromCoordinate:from toCoordinate:to] * 180.0 / pi;
        NSUInteger steps = (NSUInteger)fmin(fmax(ceil(degrees / 2.0), 1.0), 2048.0);
        if (sampled + steps > capacity) {
            break;
        }
        for (NSUInteger step = 1; step < steps; step++) {
            flat[sampled++] = [self revenant_coordinateFromCoordinate:from toCoordinate:to
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
    if (!line || line.pointCount != sampled) {
        return nil;
    }
    return line;
}

@end
