#import <CoreMotion/CoreMotion.h>

// The relative altitude of iOS 8, a CMLogItem of the release. No altimeter on this device produces one, so the port never
// hands one over: an application can allocate one, and the answers below are the ones a fresh instance gives, both readings
// nil. The host crashes on a fresh instance in its getters, its copy and its secure archive, so for those three the port's
// answer is the documented value of a fresh object and nothing is compared (facts/CoreMotion/CMAltimeter.md).
@implementation CMAltitudeData {
    NSNumber *_relativeAltitude;
    NSNumber *_pressure;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    CMAltitudeData *copy = [super copyWithZone:zone];
    copy->_relativeAltitude = _relativeAltitude;
    copy->_pressure = _pressure;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _relativeAltitude = [coder decodeObjectOfClass:[NSNumber class] forKey:@"relativeAltitude"];
        _pressure = [coder decodeObjectOfClass:[NSNumber class] forKey:@"pressure"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_relativeAltitude forKey:@"relativeAltitude"];
    [coder encodeObject:_pressure forKey:@"pressure"];
}

- (NSNumber *)relativeAltitude
{
    return _relativeAltitude;
}

- (NSNumber *)pressure
{
    return _pressure;
}

@end
