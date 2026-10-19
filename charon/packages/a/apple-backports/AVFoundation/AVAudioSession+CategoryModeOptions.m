#import <AVFoundation/AVFoundation.h>

// -setCategory:mode:options:error: (iOS 10.0) over the two calls iOS 6.1.3 already has:
// -setCategory:withOptions:error: (iOS 6.0) and -setMode:error: (iOS 5.0), both real, both
// measured against a live AVAudioSession on real hardware (an iPad 2, no telephony - a bit or
// mode tied to the phone path still needs the same measurement on an iPhone) before this file was
// written, not assumed from the header.
//
// The options mask: MixWithOthers/DuckOthers/AllowBluetooth/DefaultToSpeaker (0x1/0x2/0x4/0x8,
// all documented iOS 6.0) round-trip exactly, alone and in every combination tried, including all
// four together. Every bit introduced later - InterruptSpokenAudioAndMixWithOthers (iOS 9.0,
// 0x10), AllowBluetoothA2DP (iOS 10.0, 0x20), AllowAirPlay (iOS 10.0, 0x40) - is accepted without
// error and then silently masked off: -categoryOptions reads back with the bit gone, not an error
// and not a crash. That is the port's own defect to inherit if this bridge just forwarded the
// caller's mask unexamined - an option requested and silently dropped is indistinguishable from
// one honoured, from the caller's side. So this file checks the readback itself and, only for a
// bit the release actually dropped, says so once - not per call, matching the one-time NSLog
// pattern the rest of this project already uses for a kept-but-inert property
// (CoreLocation/CLLocationManager+Background.m).
//
// Mode needs no such mask: -setMode:error: on this release either accepts a mode and reads it
// back exactly, or refuses it with its own real NSError (AVAudioSessionModeMoviePlayback was
// refused this way against AVAudioSessionCategoryPlayAndRecord on the iPad measured) - genuinely
// honest either way, so this bridge only forwards the caller's error out, never invents one.

@implementation AVAudioSession (CharonCategoryModeOptions)

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError
{
    BOOL categoryOK = [self setCategory:category withOptions:options error:outError];
    if (!categoryOK)
        return NO;

    AVAudioSessionCategoryOptions dropped = options & ~self.categoryOptions;
    if (dropped != 0) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"AVAudioSession.setCategory:mode:options:error: is kept and only partly applied on iOS 6: option bits 0x%lx were accepted without error and then silently dropped by the release's own -setCategory:withOptions:error: - measured against categoryOptions readback, not assumed",
                  (unsigned long)dropped);
        });
    }

    NSError *modeError = nil;
    BOOL modeOK = [self setMode:mode error:&modeError];
    if (!modeOK && outError)
        *outError = modeError;
    return modeOK;
}

@end
