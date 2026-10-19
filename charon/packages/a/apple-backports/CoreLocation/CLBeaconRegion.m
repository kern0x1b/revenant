#import <CoreLocation/CoreLocation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const int8_t charon_default_measured_power = -59;

@implementation CLBeaconRegion {
    NSUUID *_proximityUUID;
    NSNumber *_major;
    NSNumber *_minor;
    BOOL _notifyEntryStateOnDisplay;
}

- (instancetype)initWithProximityUUID:(NSUUID *)proximityUUID identifier:(NSString *)identifier
{
    return [self initWithCharonProximityUUID:proximityUUID major:nil minor:nil identifier:identifier];
}

- (instancetype)initWithProximityUUID:(NSUUID *)proximityUUID major:(CLBeaconMajorValue)major identifier:(NSString *)identifier
{
    return [self initWithCharonProximityUUID:proximityUUID major:@(major) minor:nil identifier:identifier];
}

- (instancetype)initWithProximityUUID:(NSUUID *)proximityUUID major:(CLBeaconMajorValue)major minor:(CLBeaconMinorValue)minor identifier:(NSString *)identifier
{
    return [self initWithCharonProximityUUID:proximityUUID major:@(major) minor:@(minor) identifier:identifier];
}

- (instancetype)initWithCharonProximityUUID:(NSUUID *)proximityUUID major:(NSNumber *)major minor:(NSNumber *)minor identifier:(NSString *)identifier
{
    if (!proximityUUID)
        [NSException raise:NSInvalidArgumentException format:@"Invalid parameter not satisfying: proximityUUID != nil"];
    typedef id (*initializer)(id, SEL, CLLocationCoordinate2D, CLLocationDistance, NSString *);
    CLLocationCoordinate2D nowhere = {0, 0};
    if ((self = ((initializer)objc_msgSend)(self, sel_registerName("initCircularRegionWithCenter:radius:identifier:"), nowhere, 1, identifier))) {
        _proximityUUID = [proximityUUID copy];
        _major = [major copy];
        _minor = [minor copy];
    }
    return self;
}

- (NSUUID *)proximityUUID
{
    return _proximityUUID;
}

- (NSNumber *)major
{
    return _major;
}

- (NSNumber *)minor
{
    return _minor;
}

- (BOOL)notifyEntryStateOnDisplay
{
    return _notifyEntryStateOnDisplay;
}

- (void)setNotifyEntryStateOnDisplay:(BOOL)notifyEntryStateOnDisplay
{
    if (notifyEntryStateOnDisplay) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"CLBeaconRegion.notifyEntryStateOnDisplay is kept and not applied on iOS 6: nothing tells the delegate an entry state when the display turns on");
        });
    }
    _notifyEntryStateOnDisplay = notifyEntryStateOnDisplay;
}

- (NSMutableDictionary *)peripheralDataWithMeasuredPower:(NSNumber *)measuredPower
{
    uuid_t uuid = {0};
    [_proximityUUID getUUIDBytes:uuid];
    uint16_t major = CFSwapInt16HostToBig((uint16_t)_major.shortValue);
    uint16_t minor = CFSwapInt16HostToBig((uint16_t)_minor.shortValue);
    int8_t power = measuredPower ? (int8_t)measuredPower.charValue : charon_default_measured_power;
    NSMutableData *data = [NSMutableData dataWithCapacity:21];
    [data appendBytes:uuid length:sizeof uuid];
    [data appendBytes:&major length:sizeof major];
    [data appendBytes:&minor length:sizeof minor];
    [data appendBytes:&power length:sizeof power];
    return [NSMutableDictionary dictionaryWithObject:data forKey:@"kCBAdvDataAppleBeaconKey"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (identifier:'%@', uuid:%@, major:%@, minor:%@)", NSStringFromClass([self class]), self.identifier,
                                      _proximityUUID.UUIDString, _major ?: @"-", _minor ?: @"-"];
}

@end
