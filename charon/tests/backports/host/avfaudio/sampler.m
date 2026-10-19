// What the host's own AVAudioUnitSampler holds for the three parameters the port has to reach.
//
// The release names kAUSamplerParam_Gain 900, _CoarseTuning 901, _FineTuning 902 and _Pan 903 in
// AudioUnitParameters.h, but it gives no range for any of them there, so the range is asked of the
// host: a real AVAudioUnitSampler, AudioUnitGetParameterInfo over the global scope for each id, and
// then the AVFAudio property set and the AU parameter read, which is the mapping the port has to
// reproduce. The host's audioUnit handle is the same handle the port's is.

#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioUnitUtilities.h>

static void report(NSString *label, AudioUnit unit, AudioUnitParameterID identifier)
{
    AudioUnitParameterValue defaultValue = 0;
    OSStatus status = AudioUnitGetParameter(unit, identifier, kAudioUnitScope_Global, 0, &defaultValue);
    // The range is the v2 property kAudioUnitProperty_ParameterInfo with the parameter id as the
    // element - the same path the port's own parameter tree walks. There is no
    // AudioUnitGetParameterInfo on this SDK, and the property is the release's own.
    struct AudioUnitParameterInfo info = {0};
    UInt32 size = sizeof(info);
    OSStatus infoStatus = AudioUnitGetProperty(unit, kAudioUnitProperty_ParameterInfo, kAudioUnitScope_Global,
                                             identifier, &info, &size);
    printf("%-16s id %3u  status %d  infoStatus %d  current %g", label.UTF8String, (unsigned)identifier,
           (int)status, (int)infoStatus, (double)defaultValue);
    if (infoStatus == noErr) {
        printf("  range %g .. %g", (double)info.minValue, (double)info.maxValue);
    } else {
        printf("  range <not published>");
    }
    printf("\n");
}

int main(void)
{
    @autoreleasepool {
        AudioComponentDescription description = {0};
        description.componentType = kAudioUnitType_MusicDevice;
        description.componentSubType = kAudioUnitSubType_Sampler;
        description.componentManufacturer = kAudioUnitManufacturer_Apple;
        AudioComponent component = AudioComponentFindNext(NULL, &description);
        if (component == NULL) {
            printf("no AUSampler on this host\n");
            return 1;
        }
        AVAudioUnitSampler *sampler = [[AVAudioUnitSampler alloc] initWithAudioComponentDescription:description];
        if (sampler == nil) {
            printf("the host's AVAudioUnitSampler would not instantiate\n");
            return 1;
        }
        [sampler loadInstrumentAtURL:[NSURL URLWithString:@"file:///nonexistent"] error:nil];
        AudioUnit unit = sampler.audioUnit;
        printf("stage the host's sampler: unit %p\n", (void *)unit);

        report(@"globalTuning", unit, kAUSamplerParam_CoarseTuning);
        report(@"fineTuning", unit, kAUSamplerParam_FineTuning);
        report(@"masterGain", unit, kAUSamplerParam_Gain);
        report(@"stereoPan", unit, kAUSamplerParam_Pan);

        // The mapping: set the AVFAudio property, then read the AU parameter the port would set.
        struct { NSString *name; AudioUnitParameterID id; SEL selector; float value; } probes[] = {
            {@"globalTuning", kAUSamplerParam_CoarseTuning, @selector(setGlobalTuning:), 100.0f},
            {@"globalTuning", kAUSamplerParam_CoarseTuning, @selector(setGlobalTuning:), -100.0f},
            {@"masterGain", kAUSamplerParam_Gain, @selector(setMasterGain:), -6.0f},
            {@"stereoPan", kAUSamplerParam_Pan, @selector(setStereoPan:), 0.5f},
        };
        for (size_t index = 0; index < sizeof(probes) / sizeof(*probes); index++) {
            [sampler setValue:@(probes[index].value) forKey:probes[index].name];
            AudioUnitParameterValue read = -12345;
            OSStatus status = AudioUnitGetParameter(unit, probes[index].id, kAudioUnitScope_Global, 0, &read);
            printf("stage %s = %g -> parameter %u reads %g (status %d)\n", probes[index].name.UTF8String,
                   (double)probes[index].value, (unsigned)probes[index].id, (double)read, (int)status);
        }
    }
    return 0;
}
