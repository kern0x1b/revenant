// The time events of iOS 11.0: HMTimeEvent and the four that fire on a time -- HMDurationEvent,
// HMCalendarEvent, HMSignificantTimeEvent and HMPresenceEvent -- their mutable forms, the threshold
// event that fires on a characteristic leaving a number range, and HMNumberRange, the value object
// that range is.
//
// One release's API per object file, which is what the band machinery needs: every class here
// arrived in iOS 11.0, whatever release a later member of one of them arrived in.
#import "CharonHomeKitInternal.h"

#pragma mark - HMTimeEvent

@implementation HMTimeEvent

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super charon_initWithStore:store identifier:identifier];
}

@end

#pragma mark - HMDurationEvent

@implementation HMDurationEvent

@synthesize charon_duration = _charon_duration;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super charon_initWithStore:store identifier:identifier];
}

- (instancetype)initWithDuration:(NSTimeInterval)duration
{
    self = [super init];
    if (self)
        _charon_duration = @(duration);
    return self;
}

- (NSTimeInterval)duration
{
    return [_charon_duration doubleValue];
}

@end

@implementation HMMutableDurationEvent

- (void)setDuration:(NSTimeInterval)duration
{
    self.charon_duration = @(duration);
}

@end

#pragma mark - HMCalendarEvent

@implementation HMCalendarEvent

@synthesize charon_fireDateComponents = _charon_fireDateComponents;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super charon_initWithStore:store identifier:identifier];
}

- (instancetype)initWithFireDateComponents:(NSDateComponents *)fireDateComponents
{
    self = [super init];
    if (self)
        _charon_fireDateComponents = [fireDateComponents copy];
    return self;
}

- (NSDateComponents *)fireDateComponents
{
    return [_charon_fireDateComponents copy];
}

@end

@implementation HMMutableCalendarEvent

- (void)setFireDateComponents:(NSDateComponents *)fireDateComponents
{
    self.charon_fireDateComponents = fireDateComponents;
}

@end

#pragma mark - HMSignificantTimeEvent

@implementation HMSignificantTimeEvent

@synthesize charon_significantEvent = _charon_significantEvent, charon_offset = _charon_offset;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super charon_initWithStore:store identifier:identifier];
}

- (instancetype)initWithSignificantEvent:(HMSignificantEvent)significantEvent offset:(NSTimeInterval)offset
{
    self = [super init];
    if (self) {
        _charon_significantEvent = [significantEvent copy];
        _charon_offset = @(offset);
    }
    return self;
}

- (HMSignificantEvent)significantEvent
{
    return [self.charon_significantEvent copy];
}

- (NSTimeInterval)offset
{
    return [_charon_offset doubleValue];
}

@end

@implementation HMMutableSignificantTimeEvent

- (void)setSignificantEvent:(HMSignificantEvent)significantEvent
{
    self.charon_significantEvent = significantEvent;
}

- (void)setOffset:(NSTimeInterval)offset
{
    self.charon_offset = @(offset);
}

@end

#pragma mark - HMPresenceEvent

@implementation HMPresenceEvent

@synthesize charon_presenceEventType = _charon_presenceEventType, charon_presenceUserType = _charon_presenceUserType;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super charon_initWithStore:store identifier:identifier];
}

- (instancetype)initWithPresenceEventType:(HMPresenceEventType)presenceEventType
                          presenceUserType:(HMPresenceEventUserType)presenceUserType
{
    self = [super init];
    if (self) {
        // The two types are the header's own enumerations, not strings, and they are held as the
        // numbers they are so that what comes back is the value the release gives.
        _charon_presenceEventType = @(presenceEventType);
        _charon_presenceUserType = @(presenceUserType);
    }
    return self;
}

- (HMPresenceEventType)presenceEventType
{
    return (HMPresenceEventType)[self.charon_presenceEventType unsignedIntegerValue];
}

- (HMPresenceEventUserType)presenceUserType
{
    return (HMPresenceEventUserType)[self.charon_presenceUserType unsignedIntegerValue];
}

@end

@implementation HMMutablePresenceEvent

- (void)setPresenceEventType:(HMPresenceEventType)presenceEventType
{
    self.charon_presenceEventType = @(presenceEventType);
}

- (void)setPresenceUserType:(HMPresenceEventUserType)presenceUserType
{
    self.charon_presenceUserType = @(presenceUserType);
}

@end

#pragma mark - HMCharacteristicEvent's mutable form

@implementation HMMutableCharacteristicEvent

- (void)setCharacteristic:(HMCharacteristic *)characteristic
{
    self.charon_characteristic = characteristic;
}

- (void)setTriggerValue:(id)triggerValue
{
    self.charon_triggerValue = triggerValue;
}

@end

#pragma mark - HMCharacteristicThresholdRangeEvent

@implementation HMCharacteristicThresholdRangeEvent

@synthesize charon_characteristic = _charon_characteristic, charon_thresholdRange = _charon_thresholdRange;

- (instancetype)charon_initWithStore:(CharonHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super charon_initWithStore:store identifier:identifier];
}

- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic thresholdRange:(HMNumberRange *)thresholdRange
{
    self = [super init];
    if (self) {
        _charon_characteristic = characteristic;
        _charon_thresholdRange = thresholdRange;
    }
    return self;
}

- (HMCharacteristic *)characteristic
{
    return self.charon_characteristic;
}

- (HMNumberRange *)thresholdRange
{
    return self.charon_thresholdRange;
}

@end

@implementation HMMutableCharacteristicThresholdRangeEvent

- (void)setCharacteristic:(HMCharacteristic *)characteristic
{
    self.charon_characteristic = characteristic;
}

- (void)setThresholdRange:(HMNumberRange *)thresholdRange
{
    self.charon_thresholdRange = thresholdRange;
}

@end
