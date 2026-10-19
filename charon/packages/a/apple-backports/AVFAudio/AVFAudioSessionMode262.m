#import <AVFAudio/AVFAudio.h>

// The dual-route session mode of iOS 26.2 - the newest AVFAudio mode there is, and later than any
// release whose shared cache is held here, so the value is the host's own AVFAudio's, read the same
// way and with the same controls as AVFAudioSessionMode26.m.
NSString * const AVAudioSessionModeDualRoute = @"AVAudioSessionModeDualRoute";
