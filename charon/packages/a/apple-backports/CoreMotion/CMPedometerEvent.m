#import <CoreMotion/CoreMotion.h>

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
