// AVAudioUnitDistortion's factory presets, preGain and wetDryMix, against the host's own unit.
//
// The port's preset table and its apply function are in packages/a/apple-backports/AVFAudio/CharonDistortionPresets.h,
// the header the port's class includes, so this probe checks the very table the class sends. Held to the host's unit,
// read back parameter by parameter:
//   - the host's loadFactoryPreset: for presets 0-21 leaves the sixteen parameters at the table's row;
//   - the port's apply, run on a second host unit, leaves the same sixteen values as the host's preset does;
//   - the unit's parameters 14 and 15 (preGain and wetDryMix) are what the table says after a preset.
// The host's preGain and wetDryMix properties are a different thing: they do not follow a preset. They keep the value
// the object held, which the port's object mirrors (checked below). A preset outside 0-21 changes nothing, on both.
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <stdio.h>
#include "../../../../packages/a/apple-backports/AVFAudio/CharonDistortionPresets.h"

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

        // A fresh unit holds row 0, and the object's own preGain and wetDryMix are the same row's values.
        float fresh[16];
        readBack(hostUnit, fresh);
        sameAs(fresh, CharonDistortionPresets[0], "fresh unit", 0);
        if (host.preGain != CharonDistortionPresets[0][14] || host.wetDryMix != CharonDistortionPresets[0][15]) {
            printf("FAIL fresh preGain/wetDryMix %g %g\n", host.preGain, host.wetDryMix);
            failures++;
        }

        AVAudioUnitDistortion *port = [[AVAudioUnitDistortion alloc] init];
        AudioUnit portUnit = port.audioUnit;
        const float heldPreGain = host.preGain, heldWetDryMix = host.wetDryMix;
        for (int preset = 0; preset < CharonDistortionPresetCount; preset++) {
            [host loadFactoryPreset:(AVAudioUnitDistortionPreset)preset];
            float got[16];
            readBack(hostUnit, got);
            sameAs(got, CharonDistortionPresets[preset], "host loadFactoryPreset", preset);
            if (host.preGain != heldPreGain || host.wetDryMix != heldWetDryMix) {
                printf("FAIL host preGain/wetDryMix followed preset %d: %g %g\n", preset, host.preGain, host.wetDryMix);
                failures++;
            }

            CharonApplyDistortionPreset(portUnit, preset);
            float ported[16];
            readBack(portUnit, ported);
            sameAs(ported, got, "port apply against the host", preset);
        }

        // Out of range: the host changes nothing, and the port's apply changes nothing either.
        float before[16], after[16];
        readBack(hostUnit, before);
        [host loadFactoryPreset:(AVAudioUnitDistortionPreset)-1];
        [host loadFactoryPreset:(AVAudioUnitDistortionPreset)CharonDistortionPresetCount];
        readBack(hostUnit, after);
        sameAs(after, before, "host out of range", -1);
        CharonApplyDistortionPreset(portUnit, -1);
        CharonApplyDistortionPreset(portUnit, CharonDistortionPresetCount);
        readBack(portUnit, after);
        sameAs(after, CharonDistortionPresets[CharonDistortionPresetCount - 1], "port out of range", CharonDistortionPresetCount - 1);

        // preGain and wetDryMix are parameters 14 and 15: a value set through the property is the parameter, and back.
        host.preGain = 12.5f;
        host.wetDryMix = 33.25f;
        AudioUnitParameterValue pg = -999, wdm = -999;
        AudioUnitGetParameter(hostUnit, kDistortionParam_SoftClipGain, kAudioUnitScope_Global, 0, &pg);
        AudioUnitGetParameter(hostUnit, kDistortionParam_FinalMix, kAudioUnitScope_Global, 0, &wdm);
        if (pg != 12.5f || wdm != 33.25f || host.preGain != 12.5f || host.wetDryMix != 33.25f) {
            printf("FAIL preGain/wetDryMix ids: param14=%g param15=%g\n", pg, wdm);
            failures++;
        }

        printf("presets=%d checks=distortion-presets failures=%d\n", CharonDistortionPresetCount, failures);
    }
    return failures == 0 ? 0 : 1;
}
