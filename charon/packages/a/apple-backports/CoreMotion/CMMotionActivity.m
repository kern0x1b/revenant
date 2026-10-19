#import <CoreMotion/CoreMotion.h>

// CMMotionActivity is a CMLogItem of iOS 7 and nothing the release has. The release's own
// activity is measured by a coprocessor this device does not have, so no instance is ever
// produced by the port: an application can allocate one, and the answers below are the ones
// a fresh instance gives on the host (facts/CoreMotion/CMMotionActivity.md).
@implementation CMMotionActivity {
    NSDate *_startDate;
    CMMotionActivityConfidence _confidence;
    BOOL _unknown;
    BOOL _stationary;
    BOOL _walking;
    BOOL _running;
    BOOL _automotive;
    BOOL _cycling;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _startDate = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        _confidence = CMMotionActivityConfidenceLow;
        _unknown = YES;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CMMotionActivity *copy = [super copyWithZone:zone];
    copy->_startDate = _startDate;
    copy->_confidence = _confidence;
    copy->_unknown = _unknown;
    copy->_stationary = _stationary;
    copy->_walking = _walking;
    copy->_running = _running;
    copy->_automotive = _automotive;
    copy->_cycling = _cycling;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _startDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"startDate"];
        _confidence = [coder decodeIntegerForKey:@"confidence"];
        _unknown = [coder decodeBoolForKey:@"unknown"];
        _stationary = [coder decodeBoolForKey:@"stationary"];
        _walking = [coder decodeBoolForKey:@"walking"];
        _running = [coder decodeBoolForKey:@"running"];
        _automotive = [coder decodeBoolForKey:@"automotive"];
        _cycling = [coder decodeBoolForKey:@"cycling"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_startDate forKey:@"startDate"];
    [coder encodeInteger:_confidence forKey:@"confidence"];
    [coder encodeBool:_unknown forKey:@"unknown"];
    [coder encodeBool:_stationary forKey:@"stationary"];
    [coder encodeBool:_walking forKey:@"walking"];
    [coder encodeBool:_running forKey:@"running"];
    [coder encodeBool:_automotive forKey:@"automotive"];
    [coder encodeBool:_cycling forKey:@"cycling"];
}

- (NSDate *)startDate
{
    return _startDate;
}

- (CMMotionActivityConfidence)confidence
{
    return _confidence;
}

- (BOOL)unknown
{
    return _unknown;
}

- (BOOL)stationary
{
    return _stationary;
}

- (BOOL)walking
{
    return _walking;
}

- (BOOL)running
{
    return _running;
}

- (BOOL)automotive
{
    return _automotive;
}

- (BOOL)cycling
{
    return _cycling;
}

@end
