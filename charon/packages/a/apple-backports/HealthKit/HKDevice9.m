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
