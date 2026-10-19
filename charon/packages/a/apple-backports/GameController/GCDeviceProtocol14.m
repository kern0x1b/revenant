#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

// The protocol a controller, a keyboard and a mouse all answer to, and the parts of a
// controller that describe hardware rather than input.
//
// @protocol GCDevice itself has no accessors of its own to implement: its five instance
// members - handlerQueue, setHandlerQueue:, vendorName, productCategory and
// physicalInputProfile - are each answered by the class that conforms, and this package
// answers all five already (GCController.m for all of them, GCMouse.m for the queue and the
// two names, and this file for the keyboard). Declaring it here is what makes the protocol
// object exist, so NSProtocolFromString(@"GCDevice") answers it and conformsToProtocol: on a
// controller answers YES - the header's own contract for the protocol, and the reason the
// row is implemented rather than absent.
//
// GCDeviceBattery, GCDeviceLight and GCDeviceHaptics: see the comments in GCDeviceParts14.m,
// which carries their bodies. They are declared here, not implemented, so the conformance is
// the SDK's own declaration and not this port's.

// A keyboard is a GCDevice, so it answers the four members the protocol names that a keyboard
// has: the queue the value changed handlers are submitted on, the two names, and the profile.
// GCKeyboard.keyboardInput is the profile - -[GCController physicalInputProfile]'s keyboard
// counterpart, which is what the GCDevice.h header's own note points at.
@implementation GCKeyboard {
    GCKeyboardInput *_keyboardInput;
    dispatch_queue_t _handlerQueue;
    NSString *_vendorName;
    NSString *_productCategory;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _keyboardInput = [[GCKeyboardInput alloc] init];
        [_keyboardInput charon_setDevice:self];
        _handlerQueue = dispatch_get_main_queue();
        _vendorName = @"Keyboard";
        // The product category a keyboard reports, spelled as a literal rather than as
        // GCProductCategoryKeyboard: that constant arrived in iOS 15 (names14.json carries it
        // with introduced 15.0), and naming it here would put a 15.0 symbol's use in a 14.0
        // object, which release-split reads as one release per file and this one must not mix.
        // The value is the constant's own, @"Keyboard", which GCConstants15.m declares.
        _productCategory = @"Keyboard";
    }
    return self;
}

+ (GCKeyboard *)coalescedKeyboard
{
    return nil;
}

- (GCKeyboardInput *)keyboardInput
{
    return _keyboardInput;
}

- (dispatch_queue_t)handlerQueue
{
    return _handlerQueue;
}

- (void)setHandlerQueue:(dispatch_queue_t)handlerQueue
{
    _handlerQueue = handlerQueue;
}

- (NSString *)vendorName
{
    return _vendorName;
}

- (NSString *)productCategory
{
    return _productCategory;
}

- (GCPhysicalInputProfile *)physicalInputProfile
{
    return _keyboardInput;
}

@end
