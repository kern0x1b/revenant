#import <CoreMotion/CoreMotion.h>

// The event of the pedometer of iOS 10. No pedometer on this device reports one, so the port never hands one over: an
// application can allocate one, and the answers below are the ones a fresh instance gives on the host, a nil date and the
// pause type, with the copy and the secure archive both working (facts/CoreMotion/CMPedometer.md).
@implementation CMPedometerEvent {
    NSDate *_date;
    CMPedometerEventType _type;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    CMPedometerEvent *copy = [[[self class] allocWithZone:zone] init];
    copy->_date = _date;
    copy->_type = _type;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _date = [coder decodeObjectOfClass:[NSDate class] forKey:@"date"];
        _type = [coder decodeIntegerForKey:@"type"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_date forKey:@"date"];
    [coder encodeInteger:_type forKey:@"type"];
}

- (NSDate *)date
{
    return _date;
}

- (CMPedometerEventType)type
{
    return _type;
}

@end
