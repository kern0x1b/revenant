#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKit.h"

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

- (NSString *)fullAddressIncludingRegion:(BOOL)includingRegion
{
    if (!includingRegion || _regionName.length == 0) {
        return _fullAddress;
    }
    return [NSString stringWithFormat:@"%@, %@", _fullAddress, _regionName];
}

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

@interface CLGeocoder (CharonGeocoding)
- (void)geocodeAddressString:(NSString *)addressString
           completionHandler:(void (^)(NSArray<CLPlacemark *> *, NSError *))completionHandler;
- (void)reverseGeocodeLocation:(CLLocation *)location
             completionHandler:(void (^)(NSArray<CLPlacemark *> *, NSError *))completionHandler;
- (void)cancelGeocode;
@end

@interface MKMapItem (CharonGeocoding)
- (instancetype)initWithPlacemark:(MKPlacemark *)placemark;
- (void)setPlacemark:(MKPlacemark *)placemark;
- (void)setName:(NSString *)name;
@end

@interface MKPlacemark (CharonGeocoding)
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

- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> *, NSError *))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSString *address = _addressString;
    if (address.length == 0 || _cancelled) {
        BOOL cancelled = _cancelled;
        dispatch_async(dispatch_get_main_queue(), ^{
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
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the MKGeocodingRequest was released before the geocoder answered"}]);
                    return;
                }
                strong->_loading = NO;
                BOOL cancelled = strong->_cancelled;
                if (cancelled) {
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the geocoding request was cancelled"}]);
                    return;
                }
                completionHandler(items, error);
            });
        }];
    });
}

+ (NSArray<MKMapItem *> *)charon_mapItemsOf:(NSArray<CLPlacemark *> *)placemarks
{
    NSMutableArray *items = [NSMutableArray array];
    for (CLPlacemark *placemark in placemarks) {
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
                    completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
                        @{NSLocalizedDescriptionKey: @"the MKReverseGeocodingRequest was released before the geocoder answered"}]);
                    return;
                }
                strong->_loading = NO;
                BOOL cancelled = strong->_cancelled;
                if (cancelled) {
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
