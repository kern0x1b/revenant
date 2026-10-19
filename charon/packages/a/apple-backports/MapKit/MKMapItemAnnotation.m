// MKMapItem's own later members, as a CATEGORY on the release's class, and MKMapItemAnnotation.
//
// Measured on the host first, on the host's own MapKit.framework, and every member's shape is the
// host's: all seven of MKMapItem's answer an object (`@16@0:8`), and MKMapItemAnnotation carries
// `-mapItem` `@16@0:8`, `-initWithMapItem:` `@24@0:8@16`, and the MKAnnotation members `-coordinate`
// and `-title`.
//
// What the port answers, and from where:
//
//   -timeZone                  the release's own CLTimeZone of the item's own placemark, which the
//                              release has carried since 3.2
//   -pointOfInterestCategory  the item's own category, out of the release's own
//                              -[MKMapItem dictionaryRepresentation], and nil where the pass does not
//                              declare one
//   -identifier               the release's own -placeID, which is in the armv7 cache of 6.1.3
//                              (measured with apple.objc.inventory). **The host's own class no longer
//                              has -placeID and has -identifier instead**, so the port reads the
//                              release's name and the two are the same idea on each release
//   -alternateIdentifiers     one identifier here, which is the truth on this release: the release
//                              has no second place to name
//   -address, -addressRepresentations, -location
//                              the 26.0 trio, and the honest answer is built from the release's own
//                              placemark address vocabulary (country, administrative area, locality,
//                              postal code, the thoroughfare and the formatted lines) -- a real address
//                              out of the release's own data, or nil where the item has no placemark
//
// MKMapItemAnnotation is the release's own MKAnnotation shape: it holds the item and answers the
// annotation members from the item's own placemark, so it is a real annotation a map can show and not
// a wrapper around nothing.
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/message.h>
#import "CharonMapKit.h"

// The release's own placemark vocabulary, which is what an address here is built from. The 16.4
// headers declare these, so nothing here is a port's own name.
@interface MKPlacemark (CharonMapItemAddress)
@end

@interface MKMapItem (CharonMembers)

// The release's own JSON for a pass, which is in the armv7 cache of 6.1.3 (measured) and which the
// 16.4 headers do not declare. Declared and not implemented: the method is the release's.
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

// The release's own place identifier, asked of the item itself by its own name on this release.
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
    // One identifier, and that is the truth on this release: there is no second place to name, and a
    // list padded with a repeat would be a list that says there are two.
    return identifier.length > 0 ? @[identifier] : @[];
}

// The time zone of the place, from the release's own placemark, and nil where it has none.
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

// The category of the place, out of the release's own JSON for it, and nil where the pass does not
// declare one. The key is Apple's own, from the release's own dictionaryRepresentation.
- (NSString *)pointOfInterestCategory
{
    NSDictionary *json = self.dictionaryRepresentation;
    id value = [json objectForKey:@"poiCategory"];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return nil;
}

// Where the place is, as a CLLocation the release can work with, built from the release's own
// placemark rather than from the item's own geometry.
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

// The address, out of the release's own placemark vocabulary: the country, the administrative area,
// the locality, the postal code and the thoroughfare, each the release's own accessor's own value.
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

// MKMapItemAnnotation: a map item ON the map, which is the release's own annotation shape with the
// item behind it. The coordinate and the title come from the item's own placemark, so a map that shows
// this annotation shows the place, and where there is no placemark there is no coordinate and the
// annotation says so rather than pointing at (0,0).
// MKMapItemAnnotation, the iOS 18 annotation for a map item, which the 16.4 headers do not declare.
// Apple's own name, under the same host guard as the rest of the port's own declarations.
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
