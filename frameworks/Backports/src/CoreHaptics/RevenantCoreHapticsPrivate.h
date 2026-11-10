#ifndef REVENANT_COREHAPTICS_PRIVATE_H
#define REVENANT_COREHAPTICS_PRIVATE_H

#import "RevenantCoreHaptics.h"
#import "../RevenantVibration.h"

#define REVENANT_HAPTIC_TRANSIENT_MS 40
#define REVENANT_HAPTIC_INTENSITY_FLOOR 0.5f

@interface RevenantHapticParameterAttributes : NSObject <CHHapticParameterAttributes>

- (instancetype)initWithMinimum:(float)minimum maximum:(float)maximum initial:(float)initial;

@end

@interface RevenantHapticDeviceCapability : NSObject <CHHapticDeviceCapability>
@end

@interface RevenantCHHapticPatternPlayer : NSObject <CHHapticPatternPlayer>

- (instancetype)initWithEngine:(CHHapticEngine *)engine pattern:(CHHapticPattern *)pattern;
- (void)revenant_cancel;

@end

@interface CHHapticPattern (RevenantCoreHaptics)

- (NSArray<CHHapticEvent *> *)revenant_events;
- (NSArray<CHHapticDynamicParameter *> *)revenant_parameters;

@end

@interface CHHapticEngine (RevenantCoreHaptics)

- (BOOL)revenant_isRunning;
- (void)revenant_addPlayer:(id<CHHapticPatternPlayer>)player;
- (void)revenant_playerDidFinish:(id<CHHapticPatternPlayer>)player;
- (void)revenant_runFinishedHandlers:(NSArray *)handlers;

@end

NSError *revenant_corehaptics_error(CHHapticErrorCode code);

#endif
