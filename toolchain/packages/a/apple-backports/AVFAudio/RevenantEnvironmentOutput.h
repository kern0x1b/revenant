#import <AVFAudio/AVAudioEnvironmentNode.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

typedef NS_ENUM(NSInteger, CharonEnvironmentRouteClass) {
    CharonEnvironmentRouteClassUnknown = 0,
    CharonEnvironmentRouteClassWired,
    CharonEnvironmentRouteClassBuiltIn,
    CharonEnvironmentRouteClassExternal,
};

static inline AVAudioEnvironmentOutputType CharonResolveEnvironmentOutputType(AVAudioEnvironmentOutputType requested,
                                                                             CharonEnvironmentRouteClass route)
{
    if (requested != AVAudioEnvironmentOutputTypeAuto) {
        return requested;
    }
    switch (route) {
        case CharonEnvironmentRouteClassWired:
            return AVAudioEnvironmentOutputTypeHeadphones;
        case CharonEnvironmentRouteClassBuiltIn:
            return AVAudioEnvironmentOutputTypeBuiltInSpeakers;
        case CharonEnvironmentRouteClassUnknown:
        case CharonEnvironmentRouteClassExternal:
            return AVAudioEnvironmentOutputTypeExternalSpeakers;
    }
    return AVAudioEnvironmentOutputTypeExternalSpeakers;
}

#pragma clang diagnostic pop

static inline BOOL CharonEnvironmentHeadTrackingAnswer(BOOL requested)
{
    (void)requested;
    return NO;
}
