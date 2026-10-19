#import <AVFAudio/AVFAudio.h>

// The short-form-video session mode of iOS 26.  No cache is held for a release that new - the newest
// 64-bit cache on this machine is 18.0, and 18.0 does not export the name - so the value is the one
// the host's own AVFAudio holds, read through dlsym with CFStringGetCString
// (.agent-work/plan-and-analysis/avfaudio/probe4.c, log hostmodes.log).  The four mode strings that
// cache 18.0 and 12.0 do export - Default, VoicePrompt, SpokenAudio, GameChat, Measurement,
// VideoRecording - all answer with the constant's own name, which is the shape this one answers too,
// and Default and VoicePrompt are read in the same call as the controls for the reader.
NSString * const AVAudioSessionModeShortFormVideo = @"AVAudioSessionModeShortFormVideo";
