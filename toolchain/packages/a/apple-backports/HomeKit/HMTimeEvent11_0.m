#import "RevenantHomeKitInternal.h"

#pragma mark - HMTimeEvent

@implementation HMTimeEvent

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super revenant_initWithStore:store identifier:identifier];
}

@end

#pragma mark - HMDurationEvent

@implementation HMDurationEvent

@synthesize revenant_duration = _revenant_duration;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super revenant_initWithStore:store identifier:identifier];
}

- (instancetype)initWithDuration:(NSTimeInterval)duration
{
    self = [super init];
    if (self)
        _revenant_duration = @(duration);
    return self;
}

- (NSTimeInterval)duration
{
    return [_revenant_duration doubleValue];
}

@end

@implementation HMMutableDurationEvent

- (void)setDuration:(NSTimeInterval)duration
{
    self.revenant_duration = @(duration);
}

@end

#pragma mark - HMCalendarEvent

@implementation HMCalendarEvent

@synthesize revenant_fireDateComponents = _revenant_fireDateComponents;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super revenant_initWithStore:store identifier:identifier];
}

- (instancetype)initWithFireDateComponents:(NSDateComponents *)fireDateComponents
{
    self = [super init];
    if (self)
        _revenant_fireDateComponents = [fireDateComponents copy];
    return self;
}

- (NSDateComponents *)fireDateComponents
{
    return [_revenant_fireDateComponents copy];
}

@end

@implementation HMMutableCalendarEvent

- (void)setFireDateComponents:(NSDateComponents *)fireDateComponents
{
    self.revenant_fireDateComponents = fireDateComponents;
}

@end

#pragma mark - HMSignificantTimeEvent

@implementation HMSignificantTimeEvent

@synthesize revenant_significantEvent = _revenant_significantEvent, revenant_offset = _revenant_offset;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super revenant_initWithStore:store identifier:identifier];
}

- (instancetype)initWithSignificantEvent:(HMSignificantEvent)significantEvent offset:(NSTimeInterval)offset
{
    self = [super init];
    if (self) {
        _revenant_significantEvent = [significantEvent copy];
        _revenant_offset = @(offset);
    }
    return self;
}

- (HMSignificantEvent)significantEvent
{
    return [self.revenant_significantEvent copy];
}

- (NSTimeInterval)offset
{
    return [_revenant_offset doubleValue];
}

@end

@implementation HMMutableSignificantTimeEvent

- (void)setSignificantEvent:(HMSignificantEvent)significantEvent
{
    self.revenant_significantEvent = significantEvent;
}

- (void)setOffset:(NSTimeInterval)offset
{
    self.revenant_offset = @(offset);
}

@end

#pragma mark - HMPresenceEvent

@implementation HMPresenceEvent

@synthesize revenant_presenceEventType = _revenant_presenceEventType, revenant_presenceUserType = _revenant_presenceUserType;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super revenant_initWithStore:store identifier:identifier];
}

- (instancetype)initWithPresenceEventType:(HMPresenceEventType)presenceEventType
                          presenceUserType:(HMPresenceEventUserType)presenceUserType
{
    self = [super init];
    if (self) {
        _revenant_presenceEventType = @(presenceEventType);
        _revenant_presenceUserType = @(presenceUserType);
    }
    return self;
}

- (HMPresenceEventType)presenceEventType
{
    return (HMPresenceEventType)[self.revenant_presenceEventType unsignedIntegerValue];
}

- (HMPresenceEventUserType)presenceUserType
{
    return (HMPresenceEventUserType)[self.revenant_presenceUserType unsignedIntegerValue];
}

@end

@implementation HMMutablePresenceEvent

- (void)setPresenceEventType:(HMPresenceEventType)presenceEventType
{
    self.revenant_presenceEventType = @(presenceEventType);
}

- (void)setPresenceUserType:(HMPresenceEventUserType)presenceUserType
{
    self.revenant_presenceUserType = @(presenceUserType);
}

@end

#pragma mark - HMCharacteristicEvent's mutable form

@implementation HMMutableCharacteristicEvent

- (void)setCharacteristic:(HMCharacteristic *)characteristic
{
    self.revenant_characteristic = characteristic;
}

- (void)setTriggerValue:(id)triggerValue
{
    self.revenant_triggerValue = triggerValue;
}

@end

#pragma mark - HMCharacteristicThresholdRangeEvent

@implementation HMCharacteristicThresholdRangeEvent

@synthesize revenant_characteristic = _revenant_characteristic, revenant_thresholdRange = _revenant_thresholdRange;

- (instancetype)revenant_initWithStore:(RevenantHomeKitStore *)store identifier:(NSUUID *)identifier __attribute__((objc_method_family(init)))
{
    return [super revenant_initWithStore:store identifier:identifier];
}

- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic thresholdRange:(HMNumberRange *)thresholdRange
{
    self = [super init];
    if (self) {
        _revenant_characteristic = characteristic;
        _revenant_thresholdRange = thresholdRange;
    }
    return self;
}

- (HMCharacteristic *)characteristic
{
    return self.revenant_characteristic;
}

- (HMNumberRange *)thresholdRange
{
    return self.revenant_thresholdRange;
}

@end

@implementation HMMutableCharacteristicThresholdRangeEvent

- (void)setCharacteristic:(HMCharacteristic *)characteristic
{
    self.revenant_characteristic = characteristic;
}

- (void)setThresholdRange:(HMNumberRange *)thresholdRange
{
    self.revenant_thresholdRange = thresholdRange;
}

@end
