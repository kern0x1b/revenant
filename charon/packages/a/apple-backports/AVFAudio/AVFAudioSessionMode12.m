#import <AVFAudio/AVFAudio.h>

// The voice-prompt session mode of iOS 12, read out of the arm64 caches of iOS 7.0 and 12.0
// and out of the host's own AVFAudio - all three answer the constant's own name.

NSString * const AVAudioSessionModeVoicePrompt = @"AVAudioSessionModeVoicePrompt";
