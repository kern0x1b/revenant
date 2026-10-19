// MKGeocodingRequest, MKReverseGeocodingRequest, MKAddress and MKAddressRepresentations: an address
// turned into a place and a place turned into an address, on the release's own geocoder.
//
// CLGeocoder is on the release -- apple.dyld's first_releases puts it at 5.0, and its own
// -geocodeAddressString:completionHandler:, -geocodeAddressString:inRegion:completionHandler:,
// -geocodeAddressDictionary:completionHandler: and -reverseGeocodeLocation:completionHandler: are in
// the armv7 cache of 6.1.3 (measured with apple.objc.inventory), together with a CLPlacemark that
// carries the whole address vocabulary. So there is no external service in this file and no invented
// answer: the geocoding is Apple's own geocoder, running on the release, and this is the iOS 26 shape
// of asking it.
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKit.h"

// The three styles the header gives an address, and the option bits a filter of an address is made
// of, both of which the 16.4 header has not got. Declared here under Apple's own names.
typedef NS_ENUM(NSInteger, MKAddressRepresentationsContextStyle) {
    MKAddressRepresentationsContextStyleAutomatic = 0,
    MKAddressRepresentationsContextStyleFull,
    MKAddressRepresentationsContextStyleShort,
};

@interface MKAddressRepresentations ()
@property (nonatomic, copy) NSString *fullAddress;
@property (nonatomic, copy) NSString *shortAddress;
@property (nonatomic, copy) NSString *cityName;
@property (nonatomic, copy) NSString *regionName;
@property (nonatomic, copy) NSString *regionCode;
@end

@implementation MKAddressRepresentations {
    NSString *_fullAddress;
    NSString *_shortAddress;
    NSString *_cityName;
    NSString *_regionName;
    NSString *_regionCode;
}

@synthesize fullAddress = _fullAddress;
@synthesize shortAddress = _shortAddress;
@synthesize cityName = _cityName;
@synthesize regionName = _regionName;
@synthesize regionCode = _regionCode;

- (instancetype)init
{
    return [self initWithFullAddress:@""];
}

// An address, split the way the release's own CLPlacemark splits one: the line the geocoder gave for
// the whole address, the first line of it, and the city, the region and the region's code out of the
// geocoder's own address dictionary. Nothing is composed here that the geocoder did not say.
- (instancetype)initWithFullAddress:(NSString *)fullAddress
{
    self = [super init];
    if (self) {
        _fullAddress = [fullAddress copy] ?: @"";
        NSArray<NSString *> *lines = [_fullAddress componentsSeparatedByString:@", "];
        _shortAddress = lines.count > 0 ? [lines[0] copy] : @"";
        _cityName = lines.count > 1 ? [lines[1] copy] : @"";
        if (lines.count > 2) {
            _regionName = [[[lines subarrayWithRange:NSMakeRange(2, lines.count - 2)]
                             componentsJoinedByString:@", "] copy];
        }
        _regionCode = @"";
    }
    return self;
}

- (instancetype)initWithCity:(NSString *)city
{
    return [self initWithFullAddress:city ?: @""];
}

// The whole address, with the region after it when the caller asks for it and there is one.
- (NSString *)fullAddressIncludingRegion:(BOOL)includingRegion
{
    if (!includingRegion || _regionName.length == 0) {
        return _fullAddress;
    }
    return [NSString stringWithFormat:@"%@, %@", _fullAddress, _regionName];
}

// MKAddressRepresentations.h:33, the header's own two-argument form:
//     - (nullable NSString *)fullAddressIncludingRegion:(BOOL)includingRegion singleLine:(BOOL)singleLine
// and the comment above it shows the address as the geocoder wrote it, one part to a line:
//     1 Apple Park Way / Cupertino, CA 95014 / United States
// which is what `singleLine:NO` asks to keep. This port's own addresses come out of the release's
// CLPlacemark comma-joined, so for them there is no newline to keep and the two spellings agree; the
// normalisation below is what makes the argument mean something for an address a caller built itself with
// newlines in it.
- (NSString *)fullAddressIncludingRegion:(BOOL)includingRegion singleLine:(BOOL)singleLine
{
    NSString *address = includingRegion && _regionName.length > 0
            ? [NSString stringWithFormat:@"%@, %@", _fullAddress, _regionName]
            : _fullAddress;
    if (!singleLine) {
        return address;
    }
    NSArray<NSString *> *lines = [address componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet newlineCharacterSet]];
    return [lines componentsJoinedByString:@", "];
}

// MKAddressRepresentations.h:39, `@property (nonatomic, readonly, copy, nullable) NSString
// *cityWithContext`, with the header's own example above it:
//     // Cupertino, CA
//     @property (nonatomic, readonly, copy, nullable) NSString *cityWithContext;
// so it is the city with the region beside it, where -cityName is the city alone and the method below is
// the same idea with the caller choosing how much context. An address with no city answers nil, which is
// what the header's `nullable` allows and what there is to spell.
- (NSString *)cityWithContext
{
    if (_cityName.length == 0) {
        return nil;
    }
    if (_regionName.length == 0) {
        return [_cityName copy];
    }
    return [NSString stringWithFormat:@"%@, %@", _cityName, _regionName];
}

// The city, in the style the header asks for: the full name, the short one, or whichever the caller
// has not chosen.
- (NSString *)cityWithContextUsingStyle:(MKAddressRepresentationsContextStyle)style
{
    switch (style) {
        case MKAddressRepresentationsContextStyleFull:
            return [self fullAddressIncludingRegion:YES];
        case MKAddressRepresentationsContextStyleShort:
            return _shortAddress;
        default:
            return _cityName.length > 0 ? _cityName : _shortAddress;
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithFullAddress:_fullAddress];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[MKAddressRepresentations class]]) {
        return NO;
    }
    return [_fullAddress isEqualToString:((MKAddressRepresentations *)other).fullAddress];
}

- (NSUInteger)hash
{
    return _fullAddress.hash;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithFullAddress:[coder decodeObjectForKey:@"MKAddressFull"] ?: @""];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_fullAddress forKey:@"MKAddressFull"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKAddressRepresentations: %p %@>", self, _fullAddress];
}

@end

@interface MKAddress ()
@property (nonatomic, copy) NSString *fullAddress;
@property (nonatomic, copy) NSString *shortAddress;
@end


@implementation MKAddress {
    NSString *_fullAddress;
    NSString *_shortAddress;
    MKAddressRepresentations *_representations;
}

@synthesize fullAddress = _fullAddress;
@synthesize shortAddress = _shortAddress;

- (MKAddressRepresentations *)addressRepresentations
{
    return _representations;
}

- (instancetype)init
{
    return [self initWithFullAddress:@""];
}

- (instancetype)initWithFullAddress:(NSString *)fullAddress
{
    self = [super init];
    if (self) {
        _representations = [[MKAddressRepresentations alloc] initWithFullAddress:fullAddress];
    }
    return self;
}

// MKAddress.h:15,
//     - (nullable instancetype)initWithFullAddress:(NSString *)fullAddress shortAddress:(nullable NSString *)shortAddress
// Both spellings the caller gave are kept as given, and the short address is the one it gave rather than
// the first line of the full address: this initialiser exists because an address can be short without
// being the head of the long form, which is what the header's two arguments are for.
- (instancetype)initWithFullAddress:(NSString *)fullAddress shortAddress:(NSString *)shortAddress
{
    self = [self initWithFullAddress:fullAddress];
    if (self) {
        _representations.shortAddress = [shortAddress copy];
    }
    return self;
}

- (NSString *)fullAddress
{
    return _representations.fullAddress;
}

- (NSString *)shortAddress
{
    return _representations.shortAddress;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithFullAddress:self.fullAddress];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKAddress: %p %@>", self, self.fullAddress];
}

@end

// The request both ways: an address string turned into map items, and a place turned back into map
// items. Both are the release's own CLGeocoder, on a queue of the caller's choosing as the header
// says, and both answer Apple's own placemarks as Apple's own map items.
@interface MKGeocodingRequest : NSObject
- (instancetype)init;
- (instancetype)initWithAddressString:(NSString *)addressString;
@property (nonatomic, copy) NSString *addressString;
@property (nonatomic) MKCoordinateRegion region;
@property (nonatomic, strong) NSLocale *preferredLocale;
- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> *, NSError *))completionHandler;
- (void)cancel;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@end

@interface MKReverseGeocodingRequest : NSObject
- (instancetype)init;
- (instancetype)initWithLocation:(CLLocation *)location;
@property (nonatomic, strong) CLLocation *location;
@property (nonatomic, strong) NSLocale *preferredLocale;
- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> *, NSError *))completionHandler;
- (void)cancel;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@end

// The release's own CLGeocoder, and the one method this file needs of the map item it is given. The
// placemark is the release's, and a map item for it is the release's own factory.
@interface CLGeocoder (CharonGeocoding)
- (void)geocodeAddressString:(NSString *)addressString
           completionHandler:(void (^)(NSArray<CLPlacemark *> *, NSError *))completionHandler;
- (void)reverseGeocodeLocation:(CLLocation *)location
             completionHandler:(void (^)(NSArray<CLPlacemark *> *, NSError *))completionHandler;
- (void)cancelGeocode;
@end

@interface MKMapItem (CharonGeocoding)
// The release's own map item, with the three accessors this file needs of it. All three are in the
// armv7 cache of 6.1.3 (measured with apple.objc.inventory): -initWithPlacemark:, -setPlacemark: and
// -setName:. The release's MKMapItem is a placemark and a name from 6.0 -- it has no -address and no
// +mapItemWithName:address:, both measured absent -- so the item this port builds is the release's
// own object carrying the place the release's own geocoder found, and the coordinate is on the
// placemark, which is where the release keeps it.
- (instancetype)initWithPlacemark:(MKPlacemark *)placemark;
- (void)setPlacemark:(MKPlacemark *)placemark;
- (void)setName:(NSString *)name;
@end

@interface MKPlacemark (CharonGeocoding)
// The release's own placemark, built from a coordinate and the address dictionary the geocoder
// answered with. Both -initWithCoordinate:addressDictionary: and -coordinate are in the cache.
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate addressDictionary:(NSDictionary *)address;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@end

@implementation MKGeocodingRequest {
    NSString *_addressString;
    MKCoordinateRegion _region;
    NSLocale *_preferredLocale;
    CLGeocoder *_geocoder;
    BOOL _loading;
    BOOL _cancelled;
}

@synthesize addressString = _addressString;
@synthesize preferredLocale = _preferredLocale;
@synthesize loading = _loading;
@synthesize cancelled = _cancelled;

- (instancetype)init
{
    return [self initWithAddressString:@""];
}

- (instancetype)initWithAddressString:(NSString *)addressString
{
    self = [super init];
    if (self) {
        _addressString = [addressString copy] ?: @"";
        _region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0), MKCoordinateSpanMake(180.0, 360.0));
    }
    return self;
}

- (MKCoordinateRegion)region
{
    return _region;
}

- (void)setRegion:(MKCoordinateRegion)region
{
    _region = region;
}

// The geocoding, on the release's own geocoder and off the caller's thread, answered on the main
// queue as the header says. A cancelled request answers nil and no error, which is what a caller that
// stopped waiting for it wants and what the header's own -cancel means.
- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSString *address = _addressString;
    if (address.length == 0 || _cancelled) {
        BOOL cancelled = _cancelled;
        dispatch_async(dispatch_get_main_queue(), ^{
            // A cancelled request answers with an ERROR, the host's own convention: measured on the
            // host, a cancelled MKLocalSearch answers nil and MKErrorDomain code 1, where a search
            // that finds nothing answers nil and code 4. An empty address is not a cancellation but
            // it is not a success either, so it gets the same shape with its own reason.
            completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                @{NSLocalizedDescriptionKey: cancelled ? @"the geocoding request was cancelled"
                                                       : @"the geocoding request has no address to look up"}]);
        });
        return;
    }
    _loading = YES;
    _geocoder = [[CLGeocoder alloc] init];
    __weak MKGeocodingRequest *weak = self;
    CLGeocoder *geocoder = _geocoder;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [geocoder geocodeAddressString:address completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
            NSArray<MKMapItem *> *items = [MKGeocodingRequest charon_mapItemsOf:placemarks];
            dispatch_async(dispatch_get_main_queue(), ^{
                MKGeocodingRequest *strong = weak;
                if (!strong) {
                    // The request is gone: the caller is ANSWERED, and the answer says so rather than
                    // being a nil/nil pair, which a caller cannot tell from a success.
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the MKGeocodingRequest was released before the geocoder answered"}]);
                    return;
                }
                strong->_loading = NO;
                BOOL cancelled = strong->_cancelled;
                if (cancelled) {
                    // A cancelled request answers with an ERROR, the host's own convention: measured
                    // on the host, a cancelled MKLocalSearch answers nil and MKErrorDomain code 1, where
                    // a search that finds nothing answers nil and code 4.
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the geocoding request was cancelled"}]);
                    return;
                }
                completionHandler(items, error);
            });
        }];
    });
}

// The release's own placemarks as the release's own map items, through the release's own factory.
// Charon's own, so it carries no API.
+ (NSArray<MKMapItem *> *)charon_mapItemsOf:(NSArray<CLPlacemark *> *)placemarks
{
    NSMutableArray *items = [NSMutableArray array];
    for (CLPlacemark *placemark in placemarks) {
        // The release's own MKPlacemark for the place, out of the geocoder's own coordinate and its
        // own address dictionary, and the release's own MKMapItem around it.
        MKPlacemark *place = [[MKPlacemark alloc] initWithCoordinate:placemark.location.coordinate
                                                   addressDictionary:placemark.addressDictionary];
        if (!place) {
            continue;
        }
        MKMapItem *item = [[MKMapItem alloc] initWithPlacemark:place];
        [item setName:placemark.name ?: @""];
        if (item) {
            [items addObject:item];
        }
    }
    return items;
}

- (void)cancel
{
    _cancelled = YES;
    [_geocoder cancelGeocode];
    _geocoder = nil;
    _loading = NO;
}

@end

@implementation MKReverseGeocodingRequest {
    CLLocation *_location;
    NSLocale *_preferredLocale;
    CLGeocoder *_geocoder;
    BOOL _loading;
    BOOL _cancelled;
}

@synthesize location = _location;
@synthesize preferredLocale = _preferredLocale;
@synthesize loading = _loading;
@synthesize cancelled = _cancelled;

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (instancetype)initWithLocation:(CLLocation *)location
{
    self = [self init];
    if (self) {
        _location = location;
    }
    return self;
}

- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    CLLocation *location = _location;
    if (!location || _cancelled) {
        BOOL cancelled = _cancelled;
        dispatch_async(dispatch_get_main_queue(), ^{
            // The host's own shape, measured: a cancelled request answers nil and MKErrorDomain code 1,
            // where one that finds nothing answers nil and code 4. An absent location is the same
            // shape with its own reason.
            completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                @{NSLocalizedDescriptionKey: cancelled
                    ? @"the reverse geocoding request was cancelled"
                    : @"the reverse geocoding request has no location to look up"}]);
        });
        return;
    }
    _loading = YES;
    _geocoder = [[CLGeocoder alloc] init];
    __weak MKReverseGeocodingRequest *weak = self;
    CLGeocoder *geocoder = _geocoder;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
            NSArray<MKMapItem *> *items = [MKGeocodingRequest charon_mapItemsOf:placemarks];
            dispatch_async(dispatch_get_main_queue(), ^{
                MKReverseGeocodingRequest *strong = weak;
                if (!strong) {
                    // Released before the geocoder answered: the caller is ANSWERED, with a reason,
                    // and not with a nil/nil pair a caller cannot tell from a success.
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the MKReverseGeocodingRequest was released before the geocoder answered"}]);
                    return;
                }
                strong->_loading = NO;
                BOOL cancelled = strong->_cancelled;
                if (cancelled) {
                    // A cancelled request answers with an ERROR, the host's own convention: measured
                    // on the host, a cancelled MKLocalSearch answers nil and MKErrorDomain code 1, where
                    // a search that finds nothing answers nil and code 4.
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the geocoding request was cancelled"}]);
                    return;
                }
                completionHandler(items, error);
            });
        }];
    });
}

- (void)cancel
{
    _cancelled = YES;
    [_geocoder cancelGeocode];
    _geocoder = nil;
    _loading = NO;
}

@end
