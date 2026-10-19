#import <AVFAudio/AVFAudio.h>

// The remaining port type strings, all read out of the host's own AVFAudio, which is the only
// source among those held that exports all of them (18.0 keeps them in a sub-cache of a split
// cache whose linkedit the pointer reader of the time, which was never committed, did not reach;
// 7.0 and 12.0 predate most of them).  Their shapes are the port's own: the short
// names a port is known by, the same shape "CarAudio" and "ContinuityMicrophone" have in the
// releases that do export them.

NSString * const AVAudioSessionPortAVB = @"AVB";
NSString * const AVAudioSessionPortDisplayPort = @"DisplayPort";
NSString * const AVAudioSessionPortFireWire = @"FireWire";
NSString * const AVAudioSessionPortPCI = @"PCI";
NSString * const AVAudioSessionPortThunderbolt = @"Thunderbolt";
NSString * const AVAudioSessionPortVirtual = @"Virtual";
