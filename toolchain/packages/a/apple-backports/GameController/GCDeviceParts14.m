#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCDeviceBattery {
    float _batteryLevel;
    GCDeviceBatteryState _batteryState;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _batteryLevel = 0.0f;
        _batteryState = GCDeviceBatteryStateUnknown;
    }
    return self;
}

- (float)batteryLevel
{
    return _batteryLevel;
}

- (GCDeviceBatteryState)batteryState
{
    return _batteryState;
}

- (void)charon_setBatteryLevel:(float)batteryLevel
{
    _batteryLevel = fmaxf(0.0f, fminf(1.0f, batteryLevel));
}

- (void)charon_setBatteryState:(GCDeviceBatteryState)batteryState
{
    _batteryState = batteryState;
}

@end

@implementation GCDeviceLight {
    GCColor *_color;
}

- (GCColor *)color
{
    return _color;
}

- (void)setColor:(GCColor *)color
{
    _color = [color copy];
}

@end

@implementation GCDeviceHaptics {
    NSSet<GCHapticsLocality> *_supportedLocalities;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _supportedLocalities = [NSSet setWithObjects:GCHapticsLocalityDefault, GCHapticsLocalityAll, nil];
    }
    return self;
}

- (NSSet<GCHapticsLocality> *)supportedLocalities
{
    return _supportedLocalities;
}

- (CHHapticEngine *)createEngineWithLocality:(GCHapticsLocality)locality
{
    return nil;
}

@end
