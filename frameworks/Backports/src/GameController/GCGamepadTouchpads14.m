#import "RevenantGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wincompatible-designated-initializers"

@implementation GCXboxGamepad

- (GCControllerButtonInput *)paddleButton1 { return nil; }
- (GCControllerButtonInput *)paddleButton2 { return nil; }
- (GCControllerButtonInput *)paddleButton3 { return nil; }
- (GCControllerButtonInput *)paddleButton4 { return nil; }

@end

static NSArray *RevenantDualShockSpecs(void)
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
            make(@"button", @"Touchpad Button", @"Touchpad Button", 0),
            @{@"kind": @"dpad", @"aliases": @[@"Touchpad Primary"], @"local": @"Touchpad", @"unmappedLocal": @"Touchpad",
              @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @1},
            @{@"kind": @"dpad", @"aliases": @[@"Touchpad Secondary"], @"local": @"Touchpad", @"unmappedLocal": @"Touchpad",
              @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @2},
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
    return [self initWithRevenantSpecs:RevenantDualShockSpecs()];
}

- (GCControllerButtonInput *)touchpadButton
{
    return (id)[self revenant_elementNamed:@"Touchpad Button"];
}

- (GCControllerDirectionPad *)touchpadPrimary
{
    return (id)[self revenant_elementNamed:@"Touchpad Primary"];
}

- (GCControllerDirectionPad *)touchpadSecondary
{
    return (id)[self revenant_elementNamed:@"Touchpad Secondary"];
}

@end

@implementation GCDualSenseGamepad

- (instancetype)init
{
    NSMutableArray *specs = [RevenantDualShockSpecs() mutableCopy];
    [specs addObject:@{@"kind": @"trigger", @"aliases": @[@"Left Trigger"], @"local": @"L2 Trigger", @"unmappedLocal": @"L2 Trigger",
                       @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @3}];
    [specs addObject:@{@"kind": @"trigger", @"aliases": @[@"Right Trigger"], @"local": @"R2 Trigger", @"unmappedLocal": @"R2 Trigger",
                       @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @1, @"system": @0, @"collection": [NSNull null], @"order": @4}];
    return [self initWithRevenantSpecs:specs];
}

- (GCControllerButtonInput *)touchpadButton
{
    return (id)[self revenant_elementNamed:@"Touchpad Button"];
}

- (GCControllerDirectionPad *)touchpadPrimary
{
    return (id)[self revenant_elementNamed:@"Touchpad Primary"];
}

- (GCControllerDirectionPad *)touchpadSecondary
{
    return (id)[self revenant_elementNamed:@"Touchpad Secondary"];
}

- (GCDualSenseAdaptiveTrigger *)leftTrigger
{
    return (id)[self revenant_elementNamed:@"Left Trigger"];
}

- (GCDualSenseAdaptiveTrigger *)rightTrigger
{
    return (id)[self revenant_elementNamed:@"Right Trigger"];
}

@end
