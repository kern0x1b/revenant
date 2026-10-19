#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CLBeacon {
    NSUUID *_proximityUUID;
    NSNumber *_major;
    NSNumber *_minor;
    CLProximity _proximity;
    CLLocationAccuracy _accuracy;
    NSInteger _rssi;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init]))
        _accuracy = -1;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CLBeacon *copy = [[[self class] allocWithZone:zone] init];
    copy->_proximityUUID = _proximityUUID;
    copy->_major = _major;
    copy->_minor = _minor;
    copy->_proximity = _proximity;
    copy->_accuracy = _accuracy;
    copy->_rssi = _rssi;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        _proximityUUID = [coder decodeObjectOfClass:[NSUUID class] forKey:@"proximityUUID"];
        _major = [coder decodeObjectOfClass:[NSNumber class] forKey:@"major"];
        _minor = [coder decodeObjectOfClass:[NSNumber class] forKey:@"minor"];
        _proximity = [coder decodeIntegerForKey:@"proximity"];
        _accuracy = [coder containsValueForKey:@"accuracy"] ? [coder decodeDoubleForKey:@"accuracy"] : -1;
        _rssi = [coder decodeIntegerForKey:@"rssi"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_proximityUUID forKey:@"proximityUUID"];
    [coder encodeObject:_major forKey:@"major"];
    [coder encodeObject:_minor forKey:@"minor"];
    [coder encodeInteger:_proximity forKey:@"proximity"];
    [coder encodeDouble:_accuracy forKey:@"accuracy"];
    [coder encodeInteger:_rssi forKey:@"rssi"];
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

- (CLProximity)proximity
{
    return _proximity;
}

- (CLLocationAccuracy)accuracy
{
    return _accuracy;
}

- (NSInteger)rssi
{
    return _rssi;
}

@end
