#import "RevenantGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GCGamepad {
    __weak GCController *_controller;
}

- (instancetype)init
{
    NSSet *wanted = [NSSet setWithObjects:@"Direction Pad", @"Direction Pad X Axis", @"Direction Pad Y Axis", @"Direction Pad Up", @"Direction Pad Down", @"Direction Pad Left",
                     @"Direction Pad Right", @"Button A", @"Button B", @"Button X", @"Button Y", @"Button Menu", @"Left Shoulder", @"Right Shoulder", nil];
    NSMutableArray *specs = [NSMutableArray array];
    for (NSDictionary *spec in [RevenantGCTables extendedSpecs]) {
        if (![wanted containsObject:[spec[@"aliases"] firstObject]])
            continue;
        NSMutableDictionary *plain = [spec mutableCopy];
        for (NSString *key in @[@"local", @"unmappedLocal", @"sf", @"unmappedSf"])
            plain[key] = [NSNull null];
        [specs addObject:plain];
    }
    return [self initWithRevenantSpecs:specs];
}

- (void)revenant_setController:(GCController *)controller
{
    _controller = controller;
}

- (GCController *)controller
{
    return _controller;
}

- (GCControllerDirectionPad *)dpad
{
    return (id)[self revenant_elementNamed:@"Direction Pad"];
}

- (GCControllerButtonInput *)buttonA
{
    return (id)[self revenant_elementNamed:@"Button A"];
}

- (GCControllerButtonInput *)buttonB
{
    return (id)[self revenant_elementNamed:@"Button B"];
}

- (GCControllerButtonInput *)buttonX
{
    return (id)[self revenant_elementNamed:@"Button X"];
}

- (GCControllerButtonInput *)buttonY
{
    return (id)[self revenant_elementNamed:@"Button Y"];
}

- (GCControllerButtonInput *)leftShoulder
{
    return (id)[self revenant_elementNamed:@"Left Shoulder"];
}

- (GCControllerButtonInput *)rightShoulder
{
    return (id)[self revenant_elementNamed:@"Right Shoulder"];
}

@end

@implementation GCExtendedGamepad {
    __weak GCController *_controller;
}

- (instancetype)init
{
    return [self initWithRevenantSpecs:[RevenantGCTables extendedSpecs]];
}

- (void)revenant_setController:(GCController *)controller
{
    _controller = controller;
}

- (GCController *)controller
{
    return _controller;
}

- (void)setStateFromExtendedGamepad:(GCExtendedGamepad *)extendedGamepad
{
    [self setStateFromPhysicalInput:extendedGamepad];
}

- (GCControllerDirectionPad *)dpad
{
    return (id)[self revenant_elementNamed:@"Direction Pad"];
}

- (GCControllerButtonInput *)buttonA
{
    return (id)[self revenant_elementNamed:@"Button A"];
}

- (GCControllerButtonInput *)buttonB
{
    return (id)[self revenant_elementNamed:@"Button B"];
}

- (GCControllerButtonInput *)buttonX
{
    return (id)[self revenant_elementNamed:@"Button X"];
}

- (GCControllerButtonInput *)buttonY
{
    return (id)[self revenant_elementNamed:@"Button Y"];
}

- (GCControllerButtonInput *)buttonMenu
{
    return (id)[self revenant_elementNamed:@"Button Menu"];
}

- (GCControllerButtonInput *)buttonOptions
{
    return (id)[self revenant_elementNamed:@"Button Options"];
}

- (GCControllerButtonInput *)buttonHome
{
    return (id)[self revenant_elementNamed:@"Button Home"];
}

- (GCControllerDirectionPad *)leftThumbstick
{
    return (id)[self revenant_elementNamed:@"Left Thumbstick"];
}

- (GCControllerDirectionPad *)rightThumbstick
{
    return (id)[self revenant_elementNamed:@"Right Thumbstick"];
}

- (GCControllerButtonInput *)leftShoulder
{
    return (id)[self revenant_elementNamed:@"Left Shoulder"];
}

- (GCControllerButtonInput *)rightShoulder
{
    return (id)[self revenant_elementNamed:@"Right Shoulder"];
}

- (GCControllerButtonInput *)leftTrigger
{
    return (id)[self revenant_elementNamed:@"Left Trigger"];
}

- (GCControllerButtonInput *)rightTrigger
{
    return (id)[self revenant_elementNamed:@"Right Trigger"];
}

- (GCControllerButtonInput *)leftThumbstickButton
{
    return (id)[self revenant_elementNamed:@"Left Thumbstick Button"];
}

- (GCControllerButtonInput *)rightThumbstickButton
{
    return (id)[self revenant_elementNamed:@"Right Thumbstick Button"];
}

@end
