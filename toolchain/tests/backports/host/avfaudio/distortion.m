#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <stdio.h>
#include "../../../../packages/a/apple-backports/AVFAudio/RevenantDistortionPresets.h"

static int failures = 0;

static void readBack(AudioUnit unit, float out[16])
{
    for (AudioUnitParameterID identifier = 0; identifier < 16; identifier++) {
        AudioUnitParameterValue value = -999;
        AudioUnitGetParameter(unit, identifier, kAudioUnitScope_Global, 0, &value);
        out[identifier] = (float)value;
    }
}

static void sameAs(const float got[16], const float want[16], const char *what, int preset)
{
    for (int i = 0; i < 16; i++) {
        if (got[i] != want[i]) {
            printf("FAIL %s preset %d parameter %d: %g != %g\n", what, preset, i, got[i], want[i]);
            failures++;
            return;
        }
    }
}

int main(void)
{
    @autoreleasepool {
        AVAudioUnitDistortion *host = [[AVAudioUnitDistortion alloc] init];
        AudioUnit hostUnit = host.audioUnit;
        if (hostUnit == NULL) {
            printf("FAIL the host distortion has no unit\n");
            return 1;
        }

        float fresh[16];
        readBack(hostUnit, fresh);
        sameAs(fresh, RevenantDistortionPresets[0], "fresh unit", 0);
        if (host.preGain != RevenantDistortionPresets[0][14] || host.wetDryMix != RevenantDistortionPresets[0][15]) {
            printf("FAIL fresh preGain/wetDryMix %g %g\n", host.preGain, host.wetDryMix);
            failures++;
        }

        AVAudioUnitDistortion *port = [[AVAudioUnitDistortion alloc] init];
        AudioUnit portUnit = port.audioUnit;
        const float heldPreGain = host.preGain, heldWetDryMix = host.wetDryMix;
        for (int preset = 0; preset < RevenantDistortionPresetCount; preset++) {
            [host loadFactoryPreset:(AVAudioUnitDistortionPreset)preset];
            float got[16];
            readBack(hostUnit, got);
            sameAs(got, RevenantDistortionPresets[preset], "host loadFactoryPreset", preset);
            if (host.preGain != heldPreGain || host.wetDryMix != heldWetDryMix) {
                printf("FAIL host preGain/wetDryMix followed preset %d: %g %g\n", preset, host.preGain, host.wetDryMix);
                failures++;
            }

            RevenantApplyDistortionPreset(portUnit, preset);
            float ported[16];
            readBack(portUnit, ported);
            sameAs(ported, got, "port apply against the host", preset);
        }

        float before[16], after[16];
        readBack(hostUnit, before);
        [host loadFactoryPreset:(AVAudioUnitDistortionPreset)-1];
        [host loadFactoryPreset:(AVAudioUnitDistortionPreset)RevenantDistortionPresetCount];
        readBack(hostUnit, after);
        sameAs(after, before, "host out of range", -1);
        RevenantApplyDistortionPreset(portUnit, -1);
        RevenantApplyDistortionPreset(portUnit, RevenantDistortionPresetCount);
        readBack(portUnit, after);
        sameAs(after, RevenantDistortionPresets[RevenantDistortionPresetCount - 1], "port out of range", RevenantDistortionPresetCount - 1);

        host.preGain = 12.5f;
        host.wetDryMix = 33.25f;
        AudioUnitParameterValue pg = -999, wdm = -999;
        AudioUnitGetParameter(hostUnit, kDistortionParam_SoftClipGain, kAudioUnitScope_Global, 0, &pg);
        AudioUnitGetParameter(hostUnit, kDistortionParam_FinalMix, kAudioUnitScope_Global, 0, &wdm);
        if (pg != 12.5f || wdm != 33.25f || host.preGain != 12.5f || host.wetDryMix != 33.25f) {
            printf("FAIL preGain/wetDryMix ids: param14=%g param15=%g\n", pg, wdm);
            failures++;
        }

        printf("presets=%d checks=distortion-presets failures=%d\n", RevenantDistortionPresetCount, failures);
    }
    return failures == 0 ? 0 : 1;
}
