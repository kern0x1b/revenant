#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "RevenantMapKit.h"

static MKCoordinateRegion RevenantRegionAroundCoordinate(CLLocationCoordinate2D coordinate, CLLocationDistance radius)
{
    MKMapPoint centre = MKMapPointForCoordinate(coordinate);
    double reach = MKMapPointsPerMeterAtLatitude(coordinate.latitude) * (double)radius;
    MKMapRect area = MKMapRectMake(centre.x - reach, centre.y - reach, reach * 2.0, reach * 2.0);
    return MKCoordinateRegionForMapRect(area);
}

static CLLocationDistance RevenantRadiusAroundRegion(MKCoordinateRegion region)
{
    double perMetre = MKMapPointsPerMeterAtLatitude(region.center.latitude);
    if (!(perMetre > 0.0) || !(region.span.latitudeDelta >= 0.0) || !(region.span.longitudeDelta >= 0.0)) {
        return 0.0;
    }
    double halfWidth = (double)MKMapSizeWorld.width * region.span.longitudeDelta / 360.0 / 2.0 / perMetre;
    CLLocationCoordinate2D north = region.center;
    north.latitude += region.span.latitudeDelta / 2.0;
    CLLocationCoordinate2D south = region.center;
    south.latitude -= region.span.latitudeDelta / 2.0;
    double halfHeight = fabs(MKMapPointForCoordinate(south).y - MKMapPointForCoordinate(north).y) / 2.0 / perMetre;
    return halfWidth > halfHeight ? halfWidth : halfHeight;
}

@implementation MKLocalPointsOfInterestRequest {
    CLLocationCoordinate2D _coordinate;
    CLLocationDistance _radius;
    MKCoordinateRegion _region;
    MKPointOfInterestFilter *_pointOfInterestFilter;
}

- (instancetype)init
{
    revenant_sayOnce(@"[MKLocalPointsOfInterestRequest init]",
                   @"it answers the whole world, and the release's own search is asked with no query: "
                   @"MKLocalSearchRequest13.m's -initWithPointsOfInterestRequest: drops its argument");
    return [self initWithCoordinateRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0),
                                                                 MKCoordinateSpanMake(180.0, 360.0))];
}

- (instancetype)initWithCenterCoordinate:(CLLocationCoordinate2D)coordinate radius:(CLLocationDistance)radius
{
    revenant_sayOnce(@"[MKLocalPointsOfInterestRequest initWithCenterCoordinate:radius:]",
                   @"the circle is recorded and answered back, and the release's own search is asked "
                   @"with no query: MKLocalSearchRequest13.m's -initWithPointsOfInterestRequest: drops "
                   @"its argument");
    self = [super init];
    if (self) {
        _coordinate = coordinate;
        _radius = radius < 0.0 ? 0.0 : radius;
        _region = RevenantRegionAroundCoordinate(coordinate, _radius);
    }
    return self;
}

- (instancetype)initWithCoordinateRegion:(MKCoordinateRegion)region
{
    revenant_sayOnce(@"[MKLocalPointsOfInterestRequest initWithCoordinateRegion:]",
                   @"the region is recorded and answered back, and the release's own search is asked "
                   @"with no query: MKLocalSearchRequest13.m's -initWithPointsOfInterestRequest: drops "
                   @"its argument");
    self = [super init];
    if (self) {
        _region = region;
        _coordinate = region.center;
        _radius = RevenantRadiusAroundRegion(region);
    }
    return self;
}

- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (CLLocationDistance)radius
{
    return _radius;
}

- (MKCoordinateRegion)region
{
    return _region;
}

- (nullable MKPointOfInterestFilter *)pointOfInterestFilter
{
    return _pointOfInterestFilter;
}

- (void)setPointOfInterestFilter:(nullable MKPointOfInterestFilter *)pointOfInterestFilter
{
    revenant_sayOnce(@"MKLocalPointsOfInterestRequest.pointOfInterestFilter",
                   @"the filter is kept and answered back and nothing asks the release's own search "
                   @"with it: the release's own request has no filter member and its own map item has "
                   @"no category, both measured on the armv7 cache of 6.1.3");
    _pointOfInterestFilter = [pointOfInterestFilter copy];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    MKLocalPointsOfInterestRequest *copied = [[[self class] allocWithZone:zone] initWithCenterCoordinate:_coordinate
                                                                                              radius:_radius];
    copied->_region = _region;
    copied->_pointOfInterestFilter = [_pointOfInterestFilter copy];
    return copied;
}

@end
