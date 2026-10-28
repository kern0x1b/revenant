#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

NSDictionary *RevenantAudioUnitReadPreset(NSURL *url, NSError **outError);
BOOL RevenantAudioUnitApplyPreset(AudioUnit unit, NSDictionary *preset, NSError **outError);
