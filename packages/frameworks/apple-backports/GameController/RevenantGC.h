#import <GameController/GameController.h>

@interface RevenantGCTables : NSObject
+ (NSArray<NSDictionary *> *)extendedSpecs;
+ (NSArray<NSDictionary *> *)microSpecs;
+ (NSArray<NSDictionary *> *)mouseSpecs;
+ (NSArray<NSDictionary *> *)keyboardSpecs;
@end

@interface GCControllerElement (Revenant)
- (instancetype)initWithRevenantSpec:(NSDictionary *)spec;
- (void)revenant_attachToProfile:(GCPhysicalInputProfile *)profile;
- (void)revenant_setCollection:(GCControllerElement *)collection;
- (void)revenant_enqueue:(dispatch_block_t)block;
@end

@interface GCControllerButtonInput (Revenant)
- (void)revenant_deriveFromAxis:(GCControllerAxisInput *)axis sign:(float)sign;
- (void)revenant_axisChanged;
- (void)revenant_update:(float)value;
@end

@interface GCControllerAxisInput (Revenant)
- (void)revenant_linkPositive:(GCControllerButtonInput *)positive negative:(GCControllerButtonInput *)negative dpad:(GCControllerDirectionPad *)dpad;
- (void)revenant_setValue:(float)value;
@end

@interface GCControllerDirectionPad (Revenant)
- (void)revenant_linkXAxis:(GCControllerAxisInput *)x yAxis:(GCControllerAxisInput *)y up:(GCControllerButtonInput *)up down:(GCControllerButtonInput *)down
                    left:(GCControllerButtonInput *)left right:(GCControllerButtonInput *)right;
- (void)revenant_axisChanged;
@end

@interface GCDualSenseAdaptiveTrigger (Revenant)

- (GCDualSenseAdaptiveTriggerMode)revenant_requestedMode;
- (void)revenant_setRequestedMode:(GCDualSenseAdaptiveTriggerMode)mode;
- (void)revenant_setArmPosition:(float)armPosition;

@end

@interface GCPhysicalInputProfile (Revenant)
- (instancetype)initWithRevenantSpecs:(NSArray<NSDictionary *> *)specs;
- (void)revenant_setDevice:(id<GCDevice>)device;
- (GCControllerElement *)revenant_elementNamed:(NSString *)alias;
@end

@interface GCKeyboardInput (Revenant)
- (void)revenant_setPressed:(BOOL)pressed forKeyCode:(GCKeyCode)code value:(float)value;
@end

@interface GCDeviceBattery (Revenant)
- (void)revenant_setBatteryLevel:(float)batteryLevel;
- (void)revenant_setBatteryState:(GCDeviceBatteryState)batteryState;
@end

@interface GCGamepad (Revenant)
- (void)revenant_setController:(GCController *)controller;
@end

@interface GCExtendedGamepad (Revenant)
- (void)revenant_setController:(GCController *)controller;
@end

@interface GCMicroGamepad (Revenant)
- (void)revenant_setController:(GCController *)controller;
@end

@interface GCController (Revenant)
- (instancetype)initWithRevenantProfile:(GCPhysicalInputProfile *)profile vendorName:(NSString *)vendorName productCategory:(NSString *)productCategory;
@end

@interface GCMotion (Revenant)
- (instancetype)initWithRevenantAttitudeAndRotationRate:(BOOL)has;
- (void)revenant_setHasAttitudeAndRotationRate:(BOOL)has;
- (void)revenant_setController:(GCController *)controller;
@end
