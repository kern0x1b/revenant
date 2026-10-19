#import <CoreMotion/CoreMotion.h>

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
