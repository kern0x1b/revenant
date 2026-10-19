#import <AVFAudio/AVFAudio.h>

// The spoken-audio session mode of iOS 9.  Read out of the arm64 caches of iOS 7.0 and
// 12.0 and out of the host's own AVFAudio, which all three answer as the constant's own name -
// which is the shape the release uses for a mode it has no other name for.

NSString * const AVAudioSessionModeSpokenAudio = @"AVAudioSessionModeSpokenAudio";
