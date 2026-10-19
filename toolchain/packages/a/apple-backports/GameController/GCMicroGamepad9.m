#import "RevenantGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GCMicroGamepad {
    __weak GCController *_controller;
    BOOL _reportsAbsoluteDpadValues;
    BOOL _allowsRotation;
}

- (instancetype)init
{
    return [self initWithRevenantSpecs:[RevenantGCTables microSpecs]];
}

- (void)revenant_setController:(GCController *)controller
{
    _controller = controller;
}

- (GCController *)controller
{
    return _controller;
}

- (void)setStateFromMicroGamepad:(GCMicroGamepad *)microGamepad
{
    [self setStateFromPhysicalInput:microGamepad];
}

- (GCControllerDirectionPad *)dpad
{
    return (id)[self revenant_elementNamed:@"Direction Pad"];
}

- (GCControllerButtonInput *)buttonA
{
    return (id)[self revenant_elementNamed:@"Button A"];
}

- (GCControllerButtonInput *)buttonX
{
    return (id)[self revenant_elementNamed:@"Button X"];
}

- (GCControllerButtonInput *)buttonMenu
{
    return (id)[self revenant_elementNamed:@"Button Menu"];
}

@end
