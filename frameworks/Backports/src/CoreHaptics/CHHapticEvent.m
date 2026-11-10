#import "RevenantCoreHaptics.h"

@implementation CHHapticEvent
{
    CHHapticEventType _type;
    NSArray<CHHapticEventParameter *> *_eventParameters;
    NSTimeInterval _relativeTime;
    NSTimeInterval _duration;
}

- (instancetype)initWithEventType:(CHHapticEventType)type
                       parameters:(NSArray<CHHapticEventParameter *> *)eventParams
                     relativeTime:(NSTimeInterval)time
{
    return [self initWithEventType:type parameters:eventParams relativeTime:time duration:0.0];
}

- (instancetype)initWithEventType:(CHHapticEventType)type
                       parameters:(NSArray<CHHapticEventParameter *> *)eventParams
                     relativeTime:(NSTimeInterval)time
                         duration:(NSTimeInterval)duration
{
    self = [super init];
    if (self) {
        _type = [type copy];
        _eventParameters = [eventParams copy];
        _relativeTime = time;
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithAudioResourceID:(CHHapticAudioResourceID)resID
                              parameters:(NSArray<CHHapticEventParameter *> *)eventParams
                            relativeTime:(NSTimeInterval)time
{
    return nil;
}

- (instancetype)initWithAudioResourceID:(CHHapticAudioResourceID)resID
                              parameters:(NSArray<CHHapticEventParameter *> *)eventParams
                            relativeTime:(NSTimeInterval)time
                                duration:(NSTimeInterval)duration
{
    return nil;
}

- (CHHapticEventType)type
{
    return _type;
}

- (NSArray<CHHapticEventParameter *> *)eventParameters
{
    return _eventParameters;
}

- (NSTimeInterval)relativeTime
{
    return _relativeTime;
}

- (void)setRelativeTime:(NSTimeInterval)relativeTime
{
    _relativeTime = relativeTime;
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (void)setDuration:(NSTimeInterval)duration
{
    _duration = duration;
}

@end
