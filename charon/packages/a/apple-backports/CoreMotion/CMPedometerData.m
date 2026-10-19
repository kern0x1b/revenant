#import <CoreMotion/CoreMotion.h>

// The data of the pedometer of iOS 8. No pedometer on this device ever produces one, so the port never hands one over: an
// application can allocate one, and the answers below are the ones a fresh instance gives on the host, where every property
// reads nil and the copy and the secure archive both work (facts/CoreMotion/CMPedometer.md).
@implementation CMPedometerData {
    NSDate *_startDate;
    NSDate *_endDate;
    NSNumber *_numberOfSteps;
    NSNumber *_distance;
    NSNumber *_floorsAscended;
    NSNumber *_floorsDescended;
    NSNumber *_currentPace;
    NSNumber *_currentCadence;
    NSNumber *_averageActivePace;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    CMPedometerData *copy = [[[self class] allocWithZone:zone] init];
    copy->_startDate = _startDate;
    copy->_endDate = _endDate;
    copy->_numberOfSteps = _numberOfSteps;
    copy->_distance = _distance;
    copy->_floorsAscended = _floorsAscended;
    copy->_floorsDescended = _floorsDescended;
    copy->_currentPace = _currentPace;
    copy->_currentCadence = _currentCadence;
    copy->_averageActivePace = _averageActivePace;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _startDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"startDate"];
        _endDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"endDate"];
        _numberOfSteps = [coder decodeObjectOfClass:[NSNumber class] forKey:@"numberOfSteps"];
        _distance = [coder decodeObjectOfClass:[NSNumber class] forKey:@"distance"];
        _floorsAscended = [coder decodeObjectOfClass:[NSNumber class] forKey:@"floorsAscended"];
        _floorsDescended = [coder decodeObjectOfClass:[NSNumber class] forKey:@"floorsDescended"];
        _currentPace = [coder decodeObjectOfClass:[NSNumber class] forKey:@"currentPace"];
        _currentCadence = [coder decodeObjectOfClass:[NSNumber class] forKey:@"currentCadence"];
        _averageActivePace = [coder decodeObjectOfClass:[NSNumber class] forKey:@"averageActivePace"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_startDate forKey:@"startDate"];
    [coder encodeObject:_endDate forKey:@"endDate"];
    [coder encodeObject:_numberOfSteps forKey:@"numberOfSteps"];
    [coder encodeObject:_distance forKey:@"distance"];
    [coder encodeObject:_floorsAscended forKey:@"floorsAscended"];
    [coder encodeObject:_floorsDescended forKey:@"floorsDescended"];
    [coder encodeObject:_currentPace forKey:@"currentPace"];
    [coder encodeObject:_currentCadence forKey:@"currentCadence"];
    [coder encodeObject:_averageActivePace forKey:@"averageActivePace"];
}

- (NSDate *)startDate
{
    return _startDate;
}

- (NSDate *)endDate
{
    return _endDate;
}

- (NSNumber *)numberOfSteps
{
    return _numberOfSteps;
}

- (NSNumber *)distance
{
    return _distance;
}

- (NSNumber *)floorsAscended
{
    return _floorsAscended;
}

- (NSNumber *)floorsDescended
{
    return _floorsDescended;
}

- (NSNumber *)currentPace
{
    return _currentPace;
}

- (NSNumber *)currentCadence
{
    return _currentCadence;
}

- (NSNumber *)averageActivePace
{
    return _averageActivePace;
}

@end
