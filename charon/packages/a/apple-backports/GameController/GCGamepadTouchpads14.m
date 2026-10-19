#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wincompatible-designated-initializers"

// The extra parts of three controller profiles: the touchpad a DualShock or DualSense carries,
// the paddle buttons an Xbox Elite controller carries, and the DualSense's adaptive triggers.
//
// The touchpads and the triggers are real, built from the same specs and through the same linking
// every other profile in this package uses. The paddles are nil, which is what the host's own
// GCXboxGamepad answers for a controller with no paddles - the header declares all four nullable,
// and the standard Xbox controller the profile describes has none.

// An Xbox controller's four paddle buttons. The header declares all four nullable and says why: the
// standard Bluetooth Xbox controller has none, and only the Elite has four. The host's own
// GCXboxGamepad answers nil for all four (measured, tests/backports/host/gamecontroller), so they are
// nil here - and nil is what the header's own example code expects a caller to handle. Each is a real
// accessor rather than an @dynamic, because a caller that reaches one gets nil rather than
// doesNotRecognizeSelector:.
//
// buttonShare - the Series X controller's share button, iOS 15 - is no member of this iOS 14 object:
// no controller carrying one attaches, so it is not written, and default property synthesis answers
// it off an ivar nothing here writes, which reads nil as the paddles do.
@implementation GCXboxGamepad

- (GCControllerButtonInput *)paddleButton1 { return nil; }
- (GCControllerButtonInput *)paddleButton2 { return nil; }
- (GCControllerButtonInput *)paddleButton3 { return nil; }
- (GCControllerButtonInput *)paddleButton4 { return nil; }

@end

// A DualShock's touchpad: the touch surface's button, and the two surfaces - primary for the first
// finger, secondary for the second - each a real dpad of this port's own making.
static NSArray *CharonDualShockSpecs(void)
{
    static NSArray *specs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *(^make)(NSString *, NSString *, NSString *, NSInteger) = ^NSDictionary *(NSString *kind, NSString *alias, NSString *local, NSInteger order) {
            BOOL analog = [kind isEqual:@"axis"];
            return @{@"kind": kind, @"aliases": @[alias], @"local": local, @"unmappedLocal": local,
                     @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @(analog), @"system": @0,
                     @"collection": [NSNull null], @"order": @(order)};
        };
        specs = @[
            // The button built into the touch surface, and the two surfaces themselves.
            make(@"button", @"Touchpad Button", @"Touchpad Button", 0),
            @{@"kind": @"dpad", @"aliases": @[@"Touchpad Primary"], @"local": @"Touchpad", @"unmappedLocal": @"Touchpad",
              @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @1},
            @{@"kind": @"dpad", @"aliases": @[@"Touchpad Secondary"], @"local": @"Touchpad", @"unmappedLocal": @"Touchpad",
              @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @2},
            // A surface's two axes and four buttons, which the profile links to the dpad above.
            make(@"axis", @"Touchpad Primary X Axis", @"Touchpad (Horizontal)", -1),
            make(@"axis", @"Touchpad Primary Y Axis", @"Touchpad (Vertical)", -1),
            make(@"button", @"Touchpad Primary Up", @"Touchpad (Up)", -1),
            make(@"button", @"Touchpad Primary Down", @"Touchpad (Down)", -1),
            make(@"button", @"Touchpad Primary Left", @"Touchpad (Left)", -1),
            make(@"button", @"Touchpad Primary Right", @"Touchpad (Right)", -1),
            make(@"axis", @"Touchpad Secondary X Axis", @"Touchpad (Horizontal)", -1),
            make(@"axis", @"Touchpad Secondary Y Axis", @"Touchpad (Vertical)", -1),
            make(@"button", @"Touchpad Secondary Up", @"Touchpad (Up)", -1),
            make(@"button", @"Touchpad Secondary Down", @"Touchpad (Down)", -1),
            make(@"button", @"Touchpad Secondary Left", @"Touchpad (Left)", -1),
            make(@"button", @"Touchpad Secondary Right", @"Touchpad (Right)", -1),
        ];
    });
    return specs;
}

@implementation GCDualShockGamepad

- (instancetype)init
{
    return [self initWithCharonSpecs:CharonDualShockSpecs()];
}

- (GCControllerButtonInput *)touchpadButton
{
    return (id)[self charon_elementNamed:@"Touchpad Button"];
}

- (GCControllerDirectionPad *)touchpadPrimary
{
    return (id)[self charon_elementNamed:@"Touchpad Primary"];
}

- (GCControllerDirectionPad *)touchpadSecondary
{
    return (id)[self charon_elementNamed:@"Touchpad Secondary"];
}

@end

// A DualSense carries the same touchpad and, on each side, an adaptive trigger - a button whose
// mode the application commands and whose status and arm position the controller reports back.
@implementation GCDualSenseGamepad

- (instancetype)init
{
    NSMutableArray *specs = [CharonDualShockSpecs() mutableCopy];
    [specs addObject:@{@"kind": @"trigger", @"aliases": @[@"Left Trigger"], @"local": @"L2 Trigger", @"unmappedLocal": @"L2 Trigger",
                       @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @3}];
    [specs addObject:@{@"kind": @"trigger", @"aliases": @[@"Right Trigger"], @"local": @"R2 Trigger", @"unmappedLocal": @"R2 Trigger",
                       @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @4}];
    return [self initWithCharonSpecs:specs];
}

- (GCControllerButtonInput *)touchpadButton
{
    return (id)[self charon_elementNamed:@"Touchpad Button"];
}

- (GCControllerDirectionPad *)touchpadPrimary
{
    return (id)[self charon_elementNamed:@"Touchpad Primary"];
}

- (GCControllerDirectionPad *)touchpadSecondary
{
    return (id)[self charon_elementNamed:@"Touchpad Secondary"];
}

- (GCDualSenseAdaptiveTrigger *)leftTrigger
{
    return (id)[self charon_elementNamed:@"Left Trigger"];
}

- (GCDualSenseAdaptiveTrigger *)rightTrigger
{
    return (id)[self charon_elementNamed:@"Right Trigger"];
}

@end
