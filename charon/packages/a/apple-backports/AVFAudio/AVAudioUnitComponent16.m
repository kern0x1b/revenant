#import "CharonAVFAudio.h"

// The three members AVAudioUnitComponent gained in iOS 16, as a category beside the class's own
// implementation in AVAudioUnitComponent9.m - one release per object file, so the 9.0 members stay
// carried from 9.0 and these from 16.0 (backports.lua's minimums()).

@implementation AVAudioUnitComponent (Charon16)

// The header (AVAudioUnitComponent.h:160-162) describes this as a dictionary of facts about the AudioComponent's
// capabilities. Which facts it holds depends on the component's type, and the keys are declared in AudioUnitProperties.h.
//
// The release cannot describe a component: iOS 6.1.3 exports no AudioComponentCopyInformation and no
// AudioComponentGetParameter, which is where a modern release answers it, so there is nothing to ask.
// The empty dictionary is the true answer over the empty set - not a value invented to look filled -
// and an application that reads it can tell an old device from a new one by it being empty. See
// facts/AVFAudio/AVAudioUnitComponent.md.
- (NSDictionary<NSString *, id> *)configurationDictionary
{
    return @{};
}

// An icon is a resource of a component bundle. A component of this release is inside the shared
// cache, which has no bundle and no resource, so there is none to hand back - the header allows nil,
// and nil is what is answered rather than a drawn placeholder.
- (nullable UIImage *)icon
{
    return nil;
}

// Whether a component passed Apple's AU validation suite. The suite is not on the device and no C
// API of this release reports the result, so nothing has passed it here: NO is the answer that
// describes the state of this release, and an application that gates on it gates on a device without
// the suite.
- (BOOL)passesAUVal
{
    return NO;
}

@end
