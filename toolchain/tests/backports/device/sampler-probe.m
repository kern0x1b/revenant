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
