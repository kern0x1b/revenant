#import <AVFAudio/AVAudioEnvironmentNode.h>

#define RevenantEnvironmentFilterDefaultFrequency 800.0f
#define RevenantEnvironmentFilterDefaultBandwidth 3.0f
#define RevenantEnvironmentFilterDefaultGain 0.0f

static inline float RevenantEnvironmentFilterEnableValue(BOOL bypass)
{
    return bypass ? 0.0f : 1.0f;
}
