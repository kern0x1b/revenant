#import <AVFAudio/AVAudioEnvironmentNode.h>

// AVAudioEnvironmentNode's outputType, resolved from the route the release reports. A pure function of the requested
// type and the class of the route, so a host test can hold it to the header's table without an audio session.
//
// The header's rule for AVAudioEnvironmentOutputTypeAuto is that Auto follows the playback route, and that a wired route
// resolves to headphones. Every other route is not wired, so the answer for it is the external speakers, and the built-in
// hardware answers built-in speakers. A requested type other than Auto is what the caller asked for, whatever the route is.

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

// listenerHeadTrackingEnabled. This release's mixer has no head pose: nothing in its parameter set says where the
// listener's head points, and no motion sensor feeds one. So the answer is always NO, whatever was set. The host stores
// the value it was given (measured on macOS 27: YES reads back YES), which is a divergence the facts file records.
static inline BOOL CharonEnvironmentHeadTrackingAnswer(BOOL requested)
{
    (void)requested;
    return NO;
}
