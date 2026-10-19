#import <AVFAudio/AVAudioEnvironmentNode.h>

#define CharonEnvironmentFilterDefaultFrequency 800.0f
#define CharonEnvironmentFilterDefaultBandwidth 3.0f
#define CharonEnvironmentFilterDefaultGain 0.0f

static inline float CharonEnvironmentFilterEnableValue(BOOL bypass)
{
    return bypass ? 0.0f : 1.0f;
}
