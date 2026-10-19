#import <AVFAudio/AVAudioEnvironmentNode.h>

// AVAudioEnvironmentNode's reverbParameters.filterParameters: the defaults the host gives the band, and the value its
// bypass writes to the SpatialMixer. The node writes these and tests/backports/host/avfaudio/environment.m checks them
// against the host, so the test holds the very values the node uses.
//
// The mixer's own parameters carry the rest: frequency, bandwidth and gain are written as the band gives them, and the
// mixer clamps them (frequency to 10 to 10000 Hz, bandwidth to 0.05 to 4, gain to plus or minus 18 dB), while the band
// keeps the value it was given. facts/AVFAudio/AVAudioEnvironmentNode.md has the measurements.

#define CharonEnvironmentFilterDefaultFrequency 800.0f
#define CharonEnvironmentFilterDefaultBandwidth 3.0f
#define CharonEnvironmentFilterDefaultGain 0.0f

// The mixer's enable is the band's bypass inverted: a bypassed band is enable 0.
static inline float CharonEnvironmentFilterEnableValue(BOOL bypass)
{
    return bypass ? 0.0f : 1.0f;
}
