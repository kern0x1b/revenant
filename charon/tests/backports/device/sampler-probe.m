// Sampler probe: does the emulated iOS 6.1.3 carry the Apple sampler as an audio component?
//
// The question is a registration, not an export, so the answer can only come from asking the release:
// AudioComponentFindNext for {kAudioUnitType_MusicDevice, kAudioUnitSubType_Sampler, kAudioUnitManufacturer_Apple},
// and then the same walk with a wildcard manufacturer and with 'aumu', in case the component is there
// under a code this port would not have guessed. Every answer is printed with the code that produced
// it, and the component list is walked whole so a sampler under any name shows up.
//
// The distinction this settles: a grep for a Sampler *symbol* in the 6.1.3 cache proves nothing, because
// a component is registered rather than exported. facts/AVFAudio/AVAudioUnitMIDI.md records that, and
// this is the measurement it asks for.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

static void report(NSString *label, AudioComponentDescription desc)
{
    AudioComponentDescription found = desc;
    AudioComponent component = AudioComponentFindNext(NULL, &found);
    if (component == NULL) {
        printf("%s: none\n", label.UTF8String);
        return;
    }
    CFStringRef name = NULL;
    UInt32 size = 0;
    if (AudioComponentCopyName(component, &name) != noErr) {
        name = NULL;
    }
    AudioComponentDescription described;
    AudioComponentGetDescription(component, &described);
    UInt32 version = 0;
    AudioComponentGetVersion(component, &version);
    printf("%s: found, name=%s type=0x%08x subtype=0x%08x manufacturer=0x%08x version=0x%x\n",
           label.UTF8String,
           name ? [(__bridge NSString *)name UTF8String] : "(no name)",
           (unsigned)described.componentType, (unsigned)described.componentSubType,
           (unsigned)described.componentManufacturer, (unsigned)version);
    if (name) {
        CFRelease(name);
    }
}

int main(void)
{
    AudioComponentDescription every = {0, 0, 0};
    printf("probe: AudioComponentCount = %u\n", AudioComponentCount(&every));
    printf("probe: minimum = %s\n", PROBE_MINIMUM);

    AudioComponentDescription sampler = {0};
    sampler.componentType = kAudioUnitType_MusicDevice;
    sampler.componentSubType = kAudioUnitSubType_Sampler;
    sampler.componentManufacturer = kAudioUnitManufacturer_Apple;
    report(@"MusicDevice/Sampler/Apple", sampler);

    AudioComponentDescription aumu = {0};
    aumu.componentType = 'aumu';
    aumu.componentSubType = 'samp';
    report(@"'aumu'/'samp'/any", aumu);

    AudioComponentDescription anySampler = {0};
    anySampler.componentSubType = kAudioUnitSubType_Sampler;
    report(@"anyType/Sampler/any", anySampler);

    // The whole list, so a sampler under a name this probe would not have guessed is still seen.
    AudioComponentDescription any = {0};
    AudioComponent component = NULL;
    for (UInt32 index = 0; index < AudioComponentCount(&any); index++) {
        component = AudioComponentFindNext(component, &any);
        if (component == NULL) {
            break;
        }
        AudioComponentDescription described;
        AudioComponentGetDescription(component, &described);
        CFStringRef name = NULL;
        UInt32 size = 0;
        AudioComponentCopyName(component, &name);
        printf("component %u: type=0x%08x subtype=0x%08x manufacturer=0x%08x name=%s\n",
               (unsigned)index, (unsigned)described.componentType, (unsigned)described.componentSubType,
               (unsigned)described.componentManufacturer,
               name ? [(__bridge NSString *)name UTF8String] : "(no name)");
        if (name) {
            CFRelease(name);
        }
    }
    return 0;
}
