#import <CoreMotion/CoreMotion.h>

@implementation CMAbsoluteAltitudeData {
    double _altitude;
    double _accuracy;
    double _precision;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    CMAbsoluteAltitudeData *copy = [super copyWithZone:zone];
    copy->_altitude = _altitude;
    copy->_accuracy = _accuracy;
    copy->_precision = _precision;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _altitude = [coder decodeDoubleForKey:@"altitude"];
        _accuracy = [coder decodeDoubleForKey:@"accuracy"];
        _precision = [coder decodeDoubleForKey:@"precision"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_altitude forKey:@"altitude"];
    [coder encodeDouble:_accuracy forKey:@"accuracy"];
    [coder encodeDouble:_precision forKey:@"precision"];
}

- (double)altitude
{
    return _altitude;
}

- (double)accuracy
{
    return _accuracy;
}

- (double)precision
{
    return _precision;
}

@end
