#import "RevenantAudioUnitPreset.h"

NSDictionary *RevenantAudioUnitReadPreset(NSURL *url, NSError **outError)
{
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:outError];
    if (!data)
        return nil;
    NSError *parseError = nil;
    id preset = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&parseError];
    if (![preset isKindOfClass:[NSDictionary class]]) {
        if (outError)
            *outError = parseError ?: [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:nil];
        return nil;
    }
    return preset;
}

BOOL RevenantAudioUnitApplyPreset(AudioUnit unit, NSDictionary *preset, NSError **outError)
{
    CFPropertyListRef classInfo = (__bridge CFPropertyListRef)preset;
    OSStatus status = AudioUnitSetProperty(unit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &classInfo, sizeof(classInfo));
    if (status != noErr) {
        if (outError)
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return NO;
    }
    return YES;
}
