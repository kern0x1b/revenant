#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioComponent.h>
#import <AudioToolbox/AudioQueue.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioUnit/AudioUnitParameters.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AUComponent.h>
#include <stdio.h>
#include "../../../../packages/frameworks/apple-backports/AVFAudio/RevenantAudioToolboxNames.h"

static int checks = 0;
static int failures = 0;

static void check(int passed, const char *name)
{
    checks++;
    if (!passed) {
        failures++;
        printf("FAIL %s\n", name);
    }
}

static int sameString(CFStringRef host, NSString *port)
{
    return host != NULL && [(__bridge NSString *)host isEqualToString:port];
}

int main(void)
{
    @autoreleasepool {
        check(sameString(kAudioComponentRegistrationsChangedNotification, RevenantAudioComponentRegistrationsChangedName),
              "kAudioComponentRegistrationsChangedNotification has the host's string");
        check(sameString(kAudioComponentInstanceInvalidationNotification, RevenantAudioComponentInstanceInvalidatedName),
              "kAudioComponentInstanceInvalidationNotification has the host's string");

        check((long long)k3DMixerParam_BusEnable == 20, "k3DMixerParam_BusEnable is 20 in the iOS 26.2 declarations");
        check((long long)k3DMixerParam_DryWetReverbBlend == 23, "k3DMixerParam_DryWetReverbBlend is 23 in the iOS 26.2 declarations");
        check((long long)k3DMixerParam_GlobalReverbGainInDecibels == 24, "k3DMixerParam_GlobalReverbGainInDecibels is 24 in the iOS 26.2 declarations");
        check((long long)k3DMixerParam_MaxGainInDecibels == 22, "k3DMixerParam_MaxGainInDecibels is 22 in the iOS 26.2 declarations");
        check((long long)k3DMixerParam_MinGainInDecibels == 21, "k3DMixerParam_MinGainInDecibels is 21 in the iOS 26.2 declarations");
        check((long long)k3DMixerParam_ObstructionAttenuationInDecibels == 26, "k3DMixerParam_ObstructionAttenuationInDecibels is 26 in the iOS 26.2 declarations");
        check((long long)k3DMixerParam_OcclusionAttenuationInDecibels == 25, "k3DMixerParam_OcclusionAttenuationInDecibels is 25 in the iOS 26.2 declarations");
        check((long long)kAUAudioMixParameter_RemixAmount == 1, "kAUAudioMixParameter_RemixAmount is 1 in the iOS 26.2 declarations");
        check((long long)kAUAudioMixParameter_Style == 0, "kAUAudioMixParameter_Style is 0 in the iOS 26.2 declarations");
        check((long long)kAUAudioMixProperty_EnableSpatialization == 5001, "kAUAudioMixProperty_EnableSpatialization is 5001 in the iOS 26.2 declarations");
        check((long long)kAUAudioMixProperty_SpatialAudioMixMetadata == 5000, "kAUAudioMixProperty_SpatialAudioMixMetadata is 5000 in the iOS 26.2 declarations");
        check((long long)kAUSoundIsolationParam_SoundToIsolate == 1, "kAUSoundIsolationParam_SoundToIsolate is 1 in the iOS 26.2 declarations");
        check((long long)kAUSoundIsolationParam_WetDryMixPercent == 0, "kAUSoundIsolationParam_WetDryMixPercent is 0 in the iOS 26.2 declarations");
        check((long long)kAUSoundIsolationSoundType_HighQualityVoice == 0, "kAUSoundIsolationSoundType_HighQualityVoice is 0 in the iOS 26.2 declarations");
        check((long long)kAUSoundIsolationSoundType_Voice == 1, "kAUSoundIsolationSoundType_Voice is 1 in the iOS 26.2 declarations");
        check((long long)kAUVoiceIOProperty_MutedSpeechActivityEventListener == 2106, "kAUVoiceIOProperty_MutedSpeechActivityEventListener is 2106 in the iOS 26.2 declarations");
        check((long long)kAUVoiceIOProperty_OtherAudioDuckingConfiguration == 2108, "kAUVoiceIOProperty_OtherAudioDuckingConfiguration is 2108 in the iOS 26.2 declarations");
        check((long long)kAudioQueueProperty_ChannelAssignments == 1634820961, "kAudioQueueProperty_ChannelAssignments is 1634820961 in the iOS 26.2 declarations");
        check((long long)kAudioUnitProperty_SpatialMixerAnyInputIsUsingPersonalizedHRTF == 3116, "kAudioUnitProperty_SpatialMixerAnyInputIsUsingPersonalizedHRTF is 3116 in the iOS 26.2 declarations");
        check((long long)kAudioUnitProperty_SpatialMixerEnableHeadTracking == 3111, "kAudioUnitProperty_SpatialMixerEnableHeadTracking is 3111 in the iOS 26.2 declarations");
        check((long long)kAudioUnitProperty_SpatialMixerPersonalizedHRTFMode == 3113, "kAudioUnitProperty_SpatialMixerPersonalizedHRTFMode is 3113 in the iOS 26.2 declarations");
        check((long long)kAudioUnitSubType_AUAudioMix == 1634560376, "kAudioUnitSubType_AUAudioMix is 1634560376 in the iOS 26.2 declarations");
        check((long long)kAudioUnitSubType_AUSoundIsolation == 1987012979, "kAudioUnitSubType_AUSoundIsolation is 1987012979 in the iOS 26.2 declarations");
        check((long long)kAudioUnitType_SpeechSynthesizer == 1635087216, "kAudioUnitType_SpeechSynthesizer is 1635087216 in the iOS 26.2 declarations");

        printf("checks=audiotoolbox-constants failures=%d\n", failures);
        return failures == 0 ? 0 : 1;
    }
}
