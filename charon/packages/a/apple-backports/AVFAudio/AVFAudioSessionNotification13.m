#import <AVFAudio/AVFAudio.h>

// The notification of iOS 13, read out of libAVFAudio.dylib in the arm64e cache of iOS
// 18.0 and out of the host's own AVFAudio - both answer the constant's own name, which is the
// shape AVFAudio uses for a notification name.  The AVFAudio component manager below posts it
// when AudioComponentRegister adds a component this process had not listed before.

NSString * const AVAudioUnitComponentManagerRegistrationsChangedNotification = @"AVAudioUnitComponentManagerRegistrationsChangedNotification";
