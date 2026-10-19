#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The three parts of a controller that describe hardware rather than input, and the protocol
// a controller, a keyboard and a mouse all answer to.
//
// Each of the three classes marks `- (instancetype)init NS_UNAVAILABLE` in the SDK 16.4
// header, so an application never makes one: it asks a controller, and -[GCController battery],
// -light and -haptics answer nil for a controller with no such hardware, which is what this
// port does too and what the header's own `nullable` on each of the three accessors says. The
// members are still carried and real, because the port's own profile machinery can and does
// make one: the class is built so a caller that holds one is not holding a trap.

// The header states the defaults plainly: batteryLevel runs from empty (0.0) to full (1.0) and
// defaults to 0, and batteryState defaults to GCControllerBatteryStateUnknown.
// Nothing about iOS 6 has a controller battery to move either value off those defaults, so a
// battery this port makes reports them and stays there - which is what a controller with no
// battery in it means, not a value invented to look busy.
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

// The colour a controller's light is showing. GCColor is carried whole (extras.json), so this
// is a stored copy of one: nil until it is set, the colour given after, and a copy on the way
// in so a later change to the caller's object is not this light's business.
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

// The haptic actuators of a controller. The header guarantees exactly two localities are
// supported and "they may be equivalent": GCHapticsLocalityDefault and GCHapticsLocalityAll.
// Both are carried as constants by names14.json, so the set is those two names.
//
// -createEngineWithLocality: cannot answer with an engine on this release and answers nil, which
// is what the header's own `_Nullable` return allows. A CHHapticEngine is CoreHaptics, a
// framework that arrived in iOS 13; there is no engine class on iOS 6 for it to return and no
// haptics hardware to run one, so nil is the honest answer rather than a stand-in object.
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
    // No CoreHaptics on this release: CHHapticEngine is not a class here, so there is nothing
    // to build and nothing to hand back. The localities above are still the honest answer for
    // what this controller could drive.
    return nil;
}

@end
