#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/message.h>
#import "CharonMapKit.h"

@interface MKPlacemark (CharonMapItemAddress)
@end

@interface MKMapItem (CharonMembers)

- (nullable NSDictionary *)dictionaryRepresentation;

- (nullable NSTimeZone *)timeZone;
- (nullable NSString *)pointOfInterestCategory;
- (nullable NSString *)identifier;
@property (nonatomic, readonly, copy) NSArray<NSString *> *alternateIdentifiers;
- (nullable MKAddress *)address;
- (nullable MKAddressRepresentations *)addressRepresentations;
- (nullable CLLocation *)location;

@end

@implementation MKMapItem (CharonMembers)

- (NSString *)identifier
{
    SEL placeID = NSSelectorFromString(@"placeID");
    if ([self respondsToSelector:placeID]) {
        id (*read)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id value = read(self, placeID);
        if ([value isKindOfClass:[NSString class]]) {
            return value;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)alternateIdentifiers
{
    NSString *identifier = self.identifier;
    return identifier.length > 0 ? @[identifier] : @[];
}

- (NSTimeZone *)timeZone
{
    MKPlacemark *placemark = self.placemark;
    if (!placemark) {
        return nil;
    }
    id timeZone = [placemark valueForKey:@"timeZone"];
    if ([timeZone isKindOfClass:[NSTimeZone class]]) {
        return timeZone;
    }
    return nil;
}

- (NSString *)pointOfInterestCategory
{
    NSDictionary *json = self.dictionaryRepresentation;
    id value = [json objectForKey:@"poiCategory"];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return nil;
}

- (CLLocation *)location
{
    MKPlacemark *placemark = self.placemark;
    if (!placemark) {
        return nil;
    }
    CLLocationCoordinate2D coordinate = placemark.coordinate;
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

- (MKAddress *)address
{
    MKPlacemark *placemark = self.placemark;
    if (!placemark) {
        return nil;
    }
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *part in @[placemark.thoroughfare, placemark.locality, placemark.administrativeArea,
                             placemark.country]) {
        if ([part isKindOfClass:[NSString class]] && part.length > 0) {
            [lines addObject:part];
        }
    }
    if (lines.count == 0) {
        return nil;
    }
    return [[MKAddress alloc] initWithFullAddress:[lines componentsJoinedByString:@", "]];
}

- (MKAddressRepresentations *)addressRepresentations
{
    MKAddress *address = self.address;
    return address ? [address addressRepresentations] : nil;
}

@end

#if !CHARON_HOST_PROBE
@interface MKMapItemAnnotation : NSObject
- (instancetype)initWithMapItem:(MKMapItem *)mapItem;
@property (nonatomic, strong) MKMapItem *mapItem;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly, copy) NSString *title;
@end
#endif

@implementation MKMapItemAnnotation {
    MKMapItem *_mapItem;
}

@synthesize mapItem = _mapItem;

- (instancetype)initWithMapItem:(MKMapItem *)mapItem
{
    self = [super init];
    if (self) {
        _mapItem = mapItem;
    }
    return self;
}

- (MKMapItem *)mapItem
{
    return _mapItem;
}

- (void)setMapItem:(MKMapItem *)mapItem
{
    _mapItem = mapItem;
}

- (CLLocationCoordinate2D)coordinate
{
    MKPlacemark *placemark = _mapItem.placemark;
    return placemark ? placemark.coordinate : kCLLocationCoordinate2DInvalid;
}

- (NSString *)title
{
    NSString *named = _mapItem.name;
    if (named.length > 0) {
        return named;
    }
    MKAddress *address = _mapItem.address;
    return address.shortAddress;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKMapItemAnnotation: %p %@>", self, self.title ?: @"(no title)"];
}

@end
