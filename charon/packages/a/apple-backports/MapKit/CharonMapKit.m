#import "CharonMapKit.h"
#import <math.h>

@implementation CharonMapKit

+ (MKMapSize)charon_mapSizeAtZoomScale:(MKZoomScale)zoomScale
{
    double scale = pow(2.0, (double)zoomScale);
    MKMapSize size;
    size.width = (double)MKMapSizeWorld.width / scale;
    size.height = (double)MKMapSizeWorld.height / scale;
    return size;
}

+ (MKZoomScale)charon_zoomScaleForMapSize:(MKMapSize)mapSize
{
    if (mapSize.width <= 0.0 || mapSize.height <= 0.0) {
        return 0.0;
    }
    return (MKZoomScale)log2((double)MKMapSizeWorld.width / mapSize.width);
}

+ (CLLocationDistance)charon_metersPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect
{
    // The release's own metres-per-map-point at the centre of the rect, halved once per zoom
    // level: a map point is half as many metres for every doubling of the scale, which is what
    // MKZoomScale means.
    CLLocationCoordinate2D centre = MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(mapRect), MKMapRectGetMidY(mapRect)));
    double perPoint = MKMetersPerMapPointAtLatitude(centre.latitude);
    return perPoint / pow(2.0, (double)zoomScale);
}

+ (CLLocationDistance)charon_metresPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect
{
    // The release's own metres per map point at the middle of the rect, halved once per zoom level:
    // a map point is half as many metres for every doubling of the scale, which is what MKZoomScale
    // means. The release's function is the projection's own, in the armv7 cache of 3.2 (measured).
    CLLocationCoordinate2D centre = MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(mapRect), MKMapRectGetMidY(mapRect)));
    return MKMetersPerMapPointAtLatitude(centre.latitude) / pow(2.0, (double)zoomScale);
}

+ (CLLocationDirection)charon_bearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to
{
    static const double pi = 3.14159265358979323846;
    double lat1 = from.latitude * pi / 180.0;
    double lat2 = to.latitude * pi / 180.0;
    double deltaLon = (to.longitude - from.longitude) * pi / 180.0;
    double y = sin(deltaLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);
    double degrees = 180.0 / pi * atan2(y, x);
    return (CLLocationDirection)fmod(fmod(degrees, 360.0) + 360.0, 360.0);
}

// The bearing of the ARRIVAL: the direction you are travelling in when you get there, which is
// the initial bearing of the reverse leg. It is the same for the short legs and tens of degrees
// different for the long ones, and a factory that answers a camera's heading has to say which it
// means: the host's own answers the arrival bearing, measured over London->Paris (0.97 degrees from
// the initial one) and New York->London (26.8 degrees from it).
+ (CLLocationDirection)charon_arrivalBearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to
{
    CLLocationDirection initial = [self charon_bearingFromCoordinate:to toCoordinate:from];
    return (CLLocationDirection)fmod(fmod((double)initial, 360.0) + 360.0, 360.0);
}

+ (MKMapRect)charon_mapRectForRegion:(MKCoordinateRegion)region
{
    // The centre of the region and the span it covers, in the two halves MapKit's own projection
    // makes linear: the longitude span is a plain number of degrees, and the latitude span is
    // measured in the projected plane, where a degree of latitude is the same everywhere.
    MKMapPoint centre = MKMapPointForCoordinate(region.center);
    double longitudeDelta = region.span.longitudeDelta;
    double latitudeDelta = region.span.latitudeDelta;
    if (longitudeDelta < 0.0 || latitudeDelta < 0.0) {
        return MKMapRectNull;
    }
    double halfWorldX = (double)MKMapSizeWorld.width * longitudeDelta / 360.0;
    CLLocationCoordinate2D north = region.center;
    north.latitude = region.center.latitude + latitudeDelta / 2.0;
    CLLocationCoordinate2D south = region.center;
    south.latitude = region.center.latitude - latitudeDelta / 2.0;
    double halfWorldY = (MKMapPointForCoordinate(north).y - MKMapPointForCoordinate(south).y) / 2.0;
    if (north.latitude >= 90.0) {
        halfWorldY = centre.y;
    } else if (south.latitude <= -90.0) {
        halfWorldY = (double)MKMapSizeWorld.height - centre.y;
    }
    double x = centre.x - halfWorldX;
    double width = halfWorldX * 2.0;
    if (x < 0.0) {
        width += x;
        x = 0.0;
    }
    if (x + width > (double)MKMapSizeWorld.width) {
        width = (double)MKMapSizeWorld.width - x;
    }
    return MKMapRectMake(x, centre.y - halfWorldY, width, halfWorldY * 2.0);
}

@end

// The once-only log. A static set of the names already said, so the second use is silent.
void charon_sayOnce(NSString *api, NSString *why)
{
    static NSMutableSet *told;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        told = [[NSMutableSet alloc] init];
    });
    if (api.length == 0) {
        return;
    }
    @synchronized(told) {
        if ([told containsObject:api]) {
            return;
        }
        [told addObject:api];
    }
    NSLog(@"MKMapBackports: %@ is inert -- %@", api, why ?: @"no reason recorded");
}
