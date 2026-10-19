#import "CharonAVCaptureDeviceReactions17.h"

#define CHARON_CAPTURE_USER_PREFERRED_HISTORY_KEY @"CharonCaptureUserPreferredCameraHistory"
#define CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH 3

static NSArray<NSString *> *charon_user_preferred_history(void)
{
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:CHARON_CAPTURE_USER_PREFERRED_HISTORY_KEY];
    if (![stored isKindOfClass:[NSArray class]])
        return [NSArray array];
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (id entry in (NSArray *)stored) {
        if ([entry isKindOfClass:[NSString class]] && [entry length] && ![identifiers containsObject:entry])
            [identifiers addObject:entry];
        if (identifiers.count >= CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)
            break;
    }
    return identifiers;
}

@implementation AVCaptureDevice (CharonCaptureDeviceReactions17)

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
    NSArray<NSString *> *history = charon_user_preferred_history();
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
    NSMutableArray<NSString *> *history = [charon_user_preferred_history() mutableCopy];
    [history removeObject:identifier];
    [history insertObject:identifier atIndex:0];
    if (history.count > CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)
        [history removeObjectsInRange:NSMakeRange(CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH,
                                                  history.count - CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)];
    [[NSUserDefaults standardUserDefaults] setObject:[history copy]
                                              forKey:CHARON_CAPTURE_USER_PREFERRED_HISTORY_KEY];
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

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatReactions17)

- (BOOL)reactionEffectsSupported
{
    return NO;
}

- (AVFrameRateRange *)videoFrameRateRangeForReactionEffectsInProgress
{
    return nil;
}

@end
