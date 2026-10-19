#import <MapKit/MapKit.h>
#import <MapKit/MKMapCameraBoundary.h>
#import <MapKit/MKMapCameraZoomRange.h>
#import "CharonMapKit.h"

@implementation MKMapCameraBoundary

@synthesize mapRect = _mapRect;
@synthesize region = _region;

- (instancetype)initWithMapRect:(MKMapRect)mapRect
{
    self = [super init];
    if (self) {
        _mapRect = mapRect;
        _region = MKCoordinateRegionForMapRect(mapRect);
    }
    return self;
}

- (instancetype)initWithCoordinateRegion:(MKCoordinateRegion)region
{
    self = [super init];
    if (self) {
        _region = region;
        _mapRect = [CharonMapKit charon_mapRectForRegion:region];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    MKMapRect rect = MKMapRectMake([coder decodeDoubleForKey:@"MKMapRectX"],
                                   [coder decodeDoubleForKey:@"MKMapRectY"],
                                   [coder decodeDoubleForKey:@"MKMapRectWidth"],
                                   [coder decodeDoubleForKey:@"MKMapRectHeight"]);
    return [self initWithMapRect:rect];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_mapRect.origin.x forKey:@"MKMapRectX"];
    [coder encodeDouble:_mapRect.origin.y forKey:@"MKMapRectY"];
    [coder encodeDouble:_mapRect.size.width forKey:@"MKMapRectWidth"];
    [coder encodeDouble:_mapRect.size.height forKey:@"MKMapRectHeight"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithMapRect:_mapRect];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[MKMapCameraBoundary class]]) {
        return NO;
    }
    return MKMapRectEqualToRect(((MKMapCameraBoundary *)other).mapRect, _mapRect);
}

- (NSUInteger)hash
{
    return (NSUInteger)(long)_mapRect.origin.x ^ (NSUInteger)(long)_mapRect.size.height;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation MKMapCameraZoomRange

@synthesize minCenterCoordinateDistance = _minCenterCoordinateDistance;
@synthesize maxCenterCoordinateDistance = _maxCenterCoordinateDistance;

- (instancetype)initWithMinCenterCoordinateDistance:(CLLocationDistance)minDistance maxCenterCoordinateDistance:(CLLocationDistance)maxDistance
{
    if ((minDistance > 0.0 && maxDistance > 0.0 && minDistance > maxDistance) ||
        (minDistance <= 0.0 && minDistance != MKMapCameraZoomDefault) ||
        (maxDistance <= 0.0 && maxDistance != MKMapCameraZoomDefault)) {
        return nil;
    }
    self = [super init];
    if (self) {
        _minCenterCoordinateDistance = minDistance;
        _maxCenterCoordinateDistance = maxDistance;
    }
    return self;
}

- (instancetype)initWithMinCenterCoordinateDistance:(CLLocationDistance)minDistance
{
    return [self initWithMinCenterCoordinateDistance:minDistance maxCenterCoordinateDistance:MKMapCameraZoomDefault];
}

- (instancetype)initWithMaxCenterCoordinateDistance:(CLLocationDistance)maxDistance
{
    return [self initWithMinCenterCoordinateDistance:MKMapCameraZoomDefault maxCenterCoordinateDistance:maxDistance];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithMinCenterCoordinateDistance:_minCenterCoordinateDistance
                                                        maxCenterCoordinateDistance:_maxCenterCoordinateDistance];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[MKMapCameraZoomRange class]]) {
        return NO;
    }
    MKMapCameraZoomRange *range = other;
    return range.minCenterCoordinateDistance == _minCenterCoordinateDistance &&
           range.maxCenterCoordinateDistance == _maxCenterCoordinateDistance;
}

- (NSUInteger)hash
{
    return (NSUInteger)(long)_minCenterCoordinateDistance ^ (NSUInteger)(long)_maxCenterCoordinateDistance;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_minCenterCoordinateDistance forKey:@"MKMinCenterCoordinateDistance"];
    [coder encodeDouble:_maxCenterCoordinateDistance forKey:@"MKMaxCenterCoordinateDistance"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    CLLocationDistance lowest = [coder decodeDoubleForKey:@"MKMinCenterCoordinateDistance"];
    CLLocationDistance highest = [coder decodeDoubleForKey:@"MKMaxCenterCoordinateDistance"];
    return [self initWithMinCenterCoordinateDistance:lowest maxCenterCoordinateDistance:highest];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
