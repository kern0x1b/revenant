#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#import <math.h>
#import "RevenantAudioUnitPreset.h"
#import "check.h"

static AudioComponentInstance revenant_delay_unit(void)
{
    AudioComponentDescription description = {kAudioUnitType_Effect, kAudioUnitSubType_Delay, kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    AudioComponentInstance unit = NULL;
    if (component)
        AudioComponentInstanceNew(component, &unit);
    return unit;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        AudioComponentInstance source = revenant_delay_unit();
        revenant_check(source != NULL, "the Apple delay unit instantiates", @"no delay unit on this host");
        if (!source)
            return revenant_finish();

        AudioUnitSetParameter(source, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, 1.5, 0);
        CFPropertyListRef info = NULL;
        UInt32 size = sizeof(info);
        OSStatus status = AudioUnitGetProperty(source, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &info, &size);
        revenant_check(status == noErr && info != NULL, "the delay unit reports its ClassInfo", [NSString stringWithFormat:@"status %d", (int)status]);
        NSDictionary *preset = (__bridge_transfer NSDictionary *)info;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:preset format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
        NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-delay-test.aupreset"]];
        BOOL written = [data writeToURL:url atomically:YES];
        revenant_check(written, "the ClassInfo is written as a plist", @"the preset file was not written");

        AudioComponentInstance target = revenant_delay_unit();
        NSError *error = nil;
        NSDictionary *read = RevenantAudioUnitReadPreset(url, &error);
        revenant_check(read != nil, "the preset file reads back as a dictionary", [NSString stringWithFormat:@"%@", error]);
        BOOL applied = read != nil && (revenant_negative ? NO : RevenantAudioUnitApplyPreset(target, read, &error));
        revenant_check(applied, "the preset is applied to a new unit", [NSString stringWithFormat:@"%@", error]);
        AudioUnitParameterValue delay = 0;
        AudioUnitGetParameter(target, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, &delay);
        revenant_check(fabsf(delay - 1.5f) < 0.001f, "the applied preset sets the delay time to 1.5 s", [NSString stringWithFormat:@"delay %g", delay]);

        NSError *missing = nil;
        NSDictionary *none = RevenantAudioUnitReadPreset([NSURL fileURLWithPath:@"/nonexistent/revenant.aupreset"], &missing);
        revenant_check(none == nil && missing != nil, "a missing preset file is an error", @"the read did not fail");

        NSURL *array = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-array-test.aupreset"]];
        [[NSPropertyListSerialization dataWithPropertyList:@[@1] format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL] writeToURL:array atomically:YES];
        revenant_check(RevenantAudioUnitReadPreset(array, NULL) == nil, "a plist that is not a dictionary is refused", @"the array was accepted");
    }
    return revenant_finish();
}
