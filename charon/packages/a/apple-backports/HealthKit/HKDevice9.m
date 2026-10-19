// HKDevice: the device a piece of health data came from, and HKSourceRevision: which revision of
// which source wrote it. Both arrived in iOS 9.0, so both are files of their own.

#import <UIKit/UIKit.h>
#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKDevice {
    NSString *_name;
    NSString *_manufacturer;
    NSString *_model;
    NSString *_hardwareVersion;
    NSString *_firmwareVersion;
    NSString *_softwareVersion;
    NSString *_localIdentifier;
    NSString *_UDIDeviceIdentifier;
}
CHARON_HEALTHKIT_UNCREATABLE_INIT

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithName:(nullable NSString *)name
                manufacturer:(nullable NSString *)manufacturer
                       model:(nullable NSString *)model
             hardwareVersion:(nullable NSString *)hardwareVersion
             firmwareVersion:(nullable NSString *)firmwareVersion
             softwareVersion:(nullable NSString *)softwareVersion
             localIdentifier:(nullable NSString *)localIdentifier
         UDIDeviceIdentifier:(nullable NSString *)UDIDeviceIdentifier
{
    // Every one of the eight is optional, and the header says so: a device is whatever the caller
    // knows of it, and a nil stays a nil rather than becoming an empty string, because a caller that
    // asks for the firmware of a device that never gave one must be able to tell it from one that gave
    // an empty one.
    HKDevice *device = [super init];
    if (device) {
        device->_name = [name copy];
        device->_manufacturer = [manufacturer copy];
        device->_model = [model copy];
        device->_hardwareVersion = [hardwareVersion copy];
        device->_firmwareVersion = [firmwareVersion copy];
        device->_softwareVersion = [softwareVersion copy];
        device->_localIdentifier = [localIdentifier copy];
        device->_UDIDeviceIdentifier = [UDIDeviceIdentifier copy];
    }
    return device;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithName:[coder decodeObjectOfClass:[NSString class] forKey:@"name"]
                manufacturer:[coder decodeObjectOfClass:[NSString class] forKey:@"manufacturer"]
                       model:[coder decodeObjectOfClass:[NSString class] forKey:@"model"]
             hardwareVersion:[coder decodeObjectOfClass:[NSString class] forKey:@"hardwareVersion"]
             firmwareVersion:[coder decodeObjectOfClass:[NSString class] forKey:@"firmwareVersion"]
             softwareVersion:[coder decodeObjectOfClass:[NSString class] forKey:@"softwareVersion"]
             localIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"localIdentifier"]
         UDIDeviceIdentifier:[coder decodeObjectOfClass:[NSString class] forKey:@"UDIDeviceIdentifier"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_manufacturer forKey:@"manufacturer"];
    [coder encodeObject:_model forKey:@"model"];
    [coder encodeObject:_hardwareVersion forKey:@"hardwareVersion"];
    [coder encodeObject:_firmwareVersion forKey:@"firmwareVersion"];
    [coder encodeObject:_softwareVersion forKey:@"softwareVersion"];
    [coder encodeObject:_localIdentifier forKey:@"localIdentifier"];
    [coder encodeObject:_UDIDeviceIdentifier forKey:@"UDIDeviceIdentifier"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[HKDevice alloc] initWithName:_name
                             manufacturer:_manufacturer
                                    model:_model
                          hardwareVersion:_hardwareVersion
                          firmwareVersion:_firmwareVersion
                          softwareVersion:_softwareVersion
                          localIdentifier:_localIdentifier
                      UDIDeviceIdentifier:_UDIDeviceIdentifier];
}

// The device this process runs on.
//
// Three of the eight are the release's own: the host's name, model and system version come out of
// the release's own UIDevice, which is where the release reads them from. The four the header leaves
// optional and that a host device has no value for - the hardware and firmware revisions and the two
// identifiers, which are a paired accessory's - stay nil, which is what the release answers for them.
//
// The fifth, the manufacturer, is THIS PORT'S OWN STRING, and it is the one field of this class
// whose value no measurement in this repository supports. Measured: the HealthKit image of the armv7
// shared cache of iOS 9.0 holds exactly one occurrence of the string `Apple` and no exported symbol
// reaches it - the only names in that image with `Apple` in them are
// HKCategoryTypeIdentifierAppleStandHour, HKSourceOptionsForAppleDevice and
// HKSourceOptionsForNonAppleDevice - and the image of iOS 8.0 holds none at all. There is no
// manufacturer constant of HealthKit's to read, on this release or on any image this workspace holds.
// So the value is written here, it is a true statement about the hardware every device this port runs
// on is made by, and it is said in the registry entry and in facts/HealthKit/HealthKit.md rather than
// left to look measured.
+ (HKDevice *)localDevice
{
    static HKDevice *device;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIDevice *host = [UIDevice currentDevice];
        device = [[HKDevice alloc] initWithName:host.name
                                   manufacturer:@"Apple"
                                          model:host.model
                                hardwareVersion:nil
                                firmwareVersion:nil
                                softwareVersion:host.systemVersion
                                localIdentifier:nil
                            UDIDeviceIdentifier:nil];
    });
    return device;
}

- (nullable NSString *)name
{
    return _name;
}

- (nullable NSString *)manufacturer
{
    return _manufacturer;
}

- (nullable NSString *)model
{
    return _model;
}

- (nullable NSString *)hardwareVersion
{
    return _hardwareVersion;
}

- (nullable NSString *)firmwareVersion
{
    return _firmwareVersion;
}

- (nullable NSString *)softwareVersion
{
    return _softwareVersion;
}

- (nullable NSString *)localIdentifier
{
    return _localIdentifier;
}

- (nullable NSString *)UDIDeviceIdentifier
{
    return _UDIDeviceIdentifier;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[HKDevice class]])
        return NO;
    HKDevice *that = other;
    return [self charon_isSameString:_name to:that.name] && [self charon_isSameString:_manufacturer to:that.manufacturer]
           && [self charon_isSameString:_model to:that.model] && [self charon_isSameString:_hardwareVersion to:that.hardwareVersion]
           && [self charon_isSameString:_firmwareVersion to:that.firmwareVersion]
           && [self charon_isSameString:_softwareVersion to:that.softwareVersion]
           && [self charon_isSameString:_localIdentifier to:that.localIdentifier]
           && [self charon_isSameString:_UDIDeviceIdentifier to:that.UDIDeviceIdentifier];
}

- (BOOL)charon_isSameString:(nullable NSString *)mine to:(nullable NSString *)theirs
{
    return mine == theirs || [mine isEqualToString:theirs];
}

- (NSUInteger)hash
{
    return _name.hash ^ _model.hash ^ _localIdentifier.hash ^ _UDIDeviceIdentifier.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKDevice[%@ %@ %@]", _name, _manufacturer, _model];
}

@end
