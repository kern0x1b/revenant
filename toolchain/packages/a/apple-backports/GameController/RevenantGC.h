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
