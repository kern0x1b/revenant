#import <GameController/GameController.h>

@interface CharonGCTables : NSObject
+ (NSArray<NSDictionary *> *)extendedSpecs;
+ (NSArray<NSDictionary *> *)microSpecs;
+ (NSArray<NSDictionary *> *)mouseSpecs;
+ (NSArray<NSDictionary *> *)keyboardSpecs;
@end

@interface GCControllerElement (Charon)
- (instancetype)initWithCharonSpec:(NSDictionary *)spec;
- (void)charon_attachToProfile:(GCPhysicalInputProfile *)profile;
- (void)charon_setCollection:(GCControllerElement *)collection;
- (void)charon_enqueue:(dispatch_block_t)block;
@end

@interface GCControllerButtonInput (Charon)
- (void)charon_deriveFromAxis:(GCControllerAxisInput *)axis sign:(float)sign;
- (void)charon_axisChanged;
- (void)charon_update:(float)value;
@end

@interface GCControllerAxisInput (Charon)
- (void)charon_linkPositive:(GCControllerButtonInput *)positive negative:(GCControllerButtonInput *)negative dpad:(GCControllerDirectionPad *)dpad;
- (void)charon_setValue:(float)value;
@end

@interface GCControllerDirectionPad (Charon)
- (void)charon_linkXAxis:(GCControllerAxisInput *)x yAxis:(GCControllerAxisInput *)y up:(GCControllerButtonInput *)up down:(GCControllerButtonInput *)down
                    left:(GCControllerButtonInput *)left right:(GCControllerButtonInput *)right;
- (void)charon_axisChanged;
@end

// The adaptive trigger's own storage, reached from the objects that carry its setMode family.
//
// GCDualSenseAdaptiveTrigger's @implementation is GCAdaptiveTrigger145.m at the release the class
// arrived in, and a category cannot add an ivar. -charon_requestedMode: is what the four setMode calls
// of that object record and what the 15.4 object's three more record through
// -charon_setRequestedMode:, because the header says the public `mode` is the controller's answer and
// not the caller's: the header makes mode the physical state of the triggers, which the controller has to
// answer, so it does not change at once after -[GCDualSenseAdaptiveTrigger setMode...] is called. Measured on the host's own trigger with no controller
// behind it: each of the seven calls leaves mode and status at 0.
@interface GCDualSenseAdaptiveTrigger (Charon)

- (GCDualSenseAdaptiveTriggerMode)charon_requestedMode;
- (void)charon_setRequestedMode:(GCDualSenseAdaptiveTriggerMode)mode;
- (void)charon_setArmPosition:(float)armPosition;

@end

@interface GCPhysicalInputProfile (Charon)
- (instancetype)initWithCharonSpecs:(NSArray<NSDictionary *> *)specs;
- (void)charon_setDevice:(id<GCDevice>)device;
- (GCControllerElement *)charon_elementNamed:(NSString *)alias;
@end

@interface GCKeyboardInput (Charon)
- (void)charon_setPressed:(BOOL)pressed forKeyCode:(GCKeyCode)code value:(float)value;
@end

@interface GCDeviceBattery (Charon)
- (void)charon_setBatteryLevel:(float)batteryLevel;
- (void)charon_setBatteryState:(GCDeviceBatteryState)batteryState;
@end

@interface GCGamepad (Charon)
- (void)charon_setController:(GCController *)controller;
@end

@interface GCExtendedGamepad (Charon)
- (void)charon_setController:(GCController *)controller;
@end

@interface GCMicroGamepad (Charon)
- (void)charon_setController:(GCController *)controller;
@end

@interface GCController (Charon)
- (instancetype)initWithCharonProfile:(GCPhysicalInputProfile *)profile vendorName:(NSString *)vendorName productCategory:(NSString *)productCategory;
@end

@interface GCMotion (Charon)
- (instancetype)initWithCharonAttitudeAndRotationRate:(BOOL)has;
- (void)charon_setHasAttitudeAndRotationRate:(BOOL)has;
- (void)charon_setController:(GCController *)controller;
@end
