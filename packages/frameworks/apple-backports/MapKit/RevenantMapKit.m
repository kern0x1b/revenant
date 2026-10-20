#import "RevenantMapKit.h"
#import <math.h>

@implementation RevenantMapKit

+ (MKMapSize)revenant_mapSizeAtZoomScale:(MKZoomScale)zoomScale
{
    double scale = pow(2.0, (double)zoomScale);
    MKMapSize size;
    size.width = (double)MKMapSizeWorld.width / scale;
    size.height = (double)MKMapSizeWorld.height / scale;
    return size;
}

+ (MKZoomScale)revenant_zoomScaleForMapSize:(MKMapSize)mapSize
{
    if (mapSize.width <= 0.0 || mapSize.height <= 0.0) {
        return 0.0;
    }
    return (MKZoomScale)log2((double)MKMapSizeWorld.width / mapSize.width);
}

+ (CLLocationDistance)revenant_metersPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect
{
    CLLocationCoordinate2D centre = MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(mapRect), MKMapRectGetMidY(mapRect)));
    double perPoint = MKMetersPerMapPointAtLatitude(centre.latitude);
    return perPoint / pow(2.0, (double)zoomScale);
}

+ (CLLocationDistance)revenant_metresPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect
{
    CLLocationCoordinate2D centre = MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(mapRect), MKMapRectGetMidY(mapRect)));
    return MKMetersPerMapPointAtLatitude(centre.latitude) / pow(2.0, (double)zoomScale);
}

+ (CLLocationDirection)revenant_bearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to
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

+ (CLLocationDirection)revenant_arrivalBearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to
{
    CLLocationDirection initial = [self revenant_bearingFromCoordinate:to toCoordinate:from];
    return (CLLocationDirection)fmod(fmod((double)initial, 360.0) + 360.0, 360.0);
}

+ (MKMapRect)revenant_mapRectForRegion:(MKCoordinateRegion)region
{
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

void revenant_sayOnce(NSString *api, NSString *why)
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
