#import "RevenantAVCaptureDeviceReactions17.h"

#define REVENANT_CAPTURE_USER_PREFERRED_HISTORY_KEY @"RevenantCaptureUserPreferredCameraHistory"
#define REVENANT_CAPTURE_USER_PREFERRED_HISTORY_DEPTH 3

static NSArray<NSString *> *revenant_user_preferred_history(void)
{
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:REVENANT_CAPTURE_USER_PREFERRED_HISTORY_KEY];
    if (![stored isKindOfClass:[NSArray class]])
        return [NSArray array];
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (id entry in (NSArray *)stored) {
        if ([entry isKindOfClass:[NSString class]] && [entry length] && ![identifiers containsObject:entry])
            [identifiers addObject:entry];
        if (identifiers.count >= REVENANT_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)
            break;
    }
    return identifiers;
}

@implementation AVCaptureDevice (RevenantCaptureDeviceReactions17)

- (NSSet<AVCaptureReactionType> *)availableReactionTypes
{
    return [NSSet set];
}

- (BOOL)canPerformReactionEffects
{
    return NO;
}

- (NSArray<AVCaptureReactionEffectState *> *)reactionEffectsInProgress
{
    return [NSArray array];
}

+ (BOOL)reactionEffectsEnabled
{
    NSBundle *bundle = [NSBundle mainBundle];
    id opted_in = [bundle objectForInfoDictionaryKey:@"NSCameraReactionEffectsEnabled"];
    if ([opted_in isKindOfClass:[NSNumber class]] && [opted_in boolValue]) {
        return YES;
    }
    id modes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    if ([modes isKindOfClass:[NSArray class]] && [modes containsObject:@"voip"]) {
        return YES;
    }
    return NO;
}

+ (BOOL)reactionEffectGesturesEnabled
{
    id setting = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSCameraReactionEffectGesturesEnabledDefault"];
    if ([setting isKindOfClass:[NSNumber class]]) {
        return [setting boolValue];
    }
    return YES;
}

+ (AVCaptureDevice *)systemPreferredCamera
{
    return [AVCaptureDevice userPreferredCamera] ?: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

+ (AVCaptureDevice *)userPreferredCamera
{
    NSArray<NSString *> *history = revenant_user_preferred_history();
    NSArray<AVCaptureDevice *> *present = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (NSString *identifier in history) {
        for (AVCaptureDevice *device in present) {
            if ([device.uniqueID isEqualToString:identifier])
                return device;
        }
    }
    if (history.count == 0)
        return nil;
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

+ (void)setUserPreferredCamera:(AVCaptureDevice *)userPreferredCamera
{
    if (!userPreferredCamera)
        return;
    NSString *identifier = userPreferredCamera.uniqueID;
    if (![identifier length])
        return;
    NSMutableArray<NSString *> *history = [revenant_user_preferred_history() mutableCopy];
    [history removeObject:identifier];
    [history insertObject:identifier atIndex:0];
    if (history.count > REVENANT_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)
        [history removeObjectsInRange:NSMakeRange(REVENANT_CAPTURE_USER_PREFERRED_HISTORY_DEPTH,
                                                  history.count - REVENANT_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)];
    [[NSUserDefaults standardUserDefaults] setObject:[history copy]
                                              forKey:REVENANT_CAPTURE_USER_PREFERRED_HISTORY_KEY];
}

- (void)performEffectForReaction:(AVCaptureReactionType)reactionType
{
    if (![[self availableReactionTypes] containsObject:reactionType]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"-%@ is not one of the reaction types this AVCaptureDevice can perform (availableReactionTypes "
                           @"is empty: this camera has no reaction effects), and -performEffectForReaction: throws "
                           @"for any other type", NSStringFromSelector(_cmd)];
    }
}

@end

@implementation AVCaptureDeviceFormat (RevenantCaptureDeviceFormatReactions17)

- (BOOL)reactionEffectsSupported
{
    return NO;
}

- (AVFrameRateRange *)videoFrameRateRangeForReactionEffectsInProgress
{
    return nil;
}

@end
