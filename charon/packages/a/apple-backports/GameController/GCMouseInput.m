#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GCMouseInput
{
    GCMouseMoved _mouseMovedHandler;
}

- (instancetype)init
{
    return [self initWithCharonSpecs:[CharonGCTables mouseSpecs]];
}

- (GCDeviceCursor *)scroll
{
    return (id)[self charon_elementNamed:@"Scroll"];
}

- (GCControllerButtonInput *)leftButton
{
    return (id)[self charon_elementNamed:@"Left Button"];
}

- (GCControllerButtonInput *)rightButton
{
    return (id)[self charon_elementNamed:@"Right Button"];
}

- (GCControllerButtonInput *)middleButton
{
    return (id)[self charon_elementNamed:@"Middle Button"];
}

- (NSArray<GCControllerButtonInput *> *)auxiliaryButtons
{
    return nil;
}

- (GCMouseMoved)mouseMovedHandler
{
    return _mouseMovedHandler;
}

- (void)setMouseMovedHandler:(GCMouseMoved)mouseMovedHandler
{
    _mouseMovedHandler = [mouseMovedHandler copy];
}

@end
