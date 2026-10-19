#import <AVFAudio/AVAudioEnvironmentNode.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

typedef NS_ENUM(NSInteger, RevenantEnvironmentRouteClass) {
    RevenantEnvironmentRouteClassUnknown = 0,
    RevenantEnvironmentRouteClassWired,
    RevenantEnvironmentRouteClassBuiltIn,
    RevenantEnvironmentRouteClassExternal,
};

static inline AVAudioEnvironmentOutputType RevenantResolveEnvironmentOutputType(AVAudioEnvironmentOutputType requested,
                                                                             RevenantEnvironmentRouteClass route)
{
    if (requested != AVAudioEnvironmentOutputTypeAuto) {
        return requested;
    }
    switch (route) {
        case RevenantEnvironmentRouteClassWired:
            return AVAudioEnvironmentOutputTypeHeadphones;
        case RevenantEnvironmentRouteClassBuiltIn:
            return AVAudioEnvironmentOutputTypeBuiltInSpeakers;
        case RevenantEnvironmentRouteClassUnknown:
        case RevenantEnvironmentRouteClassExternal:
            return AVAudioEnvironmentOutputTypeExternalSpeakers;
    }
    return AVAudioEnvironmentOutputTypeExternalSpeakers;
}

#pragma clang diagnostic pop

static inline BOOL RevenantEnvironmentHeadTrackingAnswer(BOOL requested)
{
    (void)requested;
    return NO;
}
