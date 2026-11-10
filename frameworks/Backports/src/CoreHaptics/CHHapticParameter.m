#import "RevenantCoreHaptics.h"

@implementation CHHapticEventParameter
{
    CHHapticEventParameterID _parameterID;
    float _value;
}

- (instancetype)initWithParameterID:(CHHapticEventParameterID)parameterID value:(float)value
{
    self = [super init];
    if (self) {
        _parameterID = [parameterID copy];
        _value = value;
    }
    return self;
}

- (CHHapticEventParameterID)parameterID
{
    return _parameterID;
}

- (float)value
{
    return _value;
}

- (void)setValue:(float)value
{
    _value = value;
}

@end

@implementation CHHapticDynamicParameter
{
    CHHapticDynamicParameterID _parameterID;
    float _value;
    NSTimeInterval _relativeTime;
}

- (instancetype)initWithParameterID:(CHHapticDynamicParameterID)parameterID
                              value:(float)value
                       relativeTime:(NSTimeInterval)time
{
    self = [super init];
    if (self) {
        _parameterID = [parameterID copy];
        _value = value;
        _relativeTime = time;
    }
    return self;
}

- (CHHapticDynamicParameterID)parameterID
{
    return _parameterID;
}

- (float)value
{
    return _value;
}

- (void)setValue:(float)value
{
    _value = value;
}

- (NSTimeInterval)relativeTime
{
    return _relativeTime;
}

- (void)setRelativeTime:(NSTimeInterval)relativeTime
{
    _relativeTime = relativeTime;
}

@end
