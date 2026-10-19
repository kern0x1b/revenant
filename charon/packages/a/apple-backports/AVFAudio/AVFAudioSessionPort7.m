#import <AVFAudio/AVFAudio.h>

// The port type strings of iOS 7.  AVAudioSessionPortCarAudio is read out
// of the arm64 caches of iOS 7.0 and 12.0 (libAVFAudio.dylib) and out of the host's own AVFAudio;
// all three answer "CarAudio".  Its documented use is AVAudioSessionPortDescription.portType, which
// iOS 6 already has, so the port hands an application a type string it can compare against the
// ports the release's own route reports.

NSString * const AVAudioSessionPortCarAudio = @"CarAudio";
