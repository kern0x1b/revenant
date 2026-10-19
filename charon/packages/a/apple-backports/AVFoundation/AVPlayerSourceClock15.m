#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

// -[AVPlayer sourceClock], and the setter beside it.
//
// This is a RENAME, not a new capability, and the SDK's own header says which way it went:
//
//   /// (the header's note: masterClock is replaced by sourceClock)
//   @property (nonatomic, retain, nullable) __attribute__((NSObject)) CMClockRef masterClock
//       API_DEPRECATED_WITH_REPLACEMENT("sourceClock", macos(10.8, 15.0), ios(6.0, 18.0), ...)
//
// Read as it is written: `masterClock` is available from **iOS 6.0** and was replaced by `sourceClock`
// in 18.0. So this release has the property - the row's "introduced 15.0" is the SDK surface's
// introduction of the new spelling, not of the capability - and the port's job is to answer the new
// name from the old one. Measured on the armv7 cache of 6.1.3, class-scoped on AVPlayer: it declares
// 140 instance selectors and both `-masterClock` and `-setMasterClock:` are among them. The 4.3 cache
// carries neither, which is why the row keeps `minimum` 6.0 rather than 4.0.
//
// Both accessors forward through `objc_msgSend` to the release's own selector rather than calling
// `[self masterClock]`: this file compiles against an SDK that declares `masterClock` as deprecated,
// and a direct call would carry that deprecation into the port's own object while answering the same
// thing. It is the same call either way, and the one that stays valid as the SDK moves on.
//
// The property is `retain, nullable` and of type CMClockRef, so the getter's answer is an object the
// caller owns under ARC and may be nil - which is what Apple's own answers, the header says nullable,
// and what a player with no playback clock set gives. Facts: facts/AVFoundation/PlayerClock.md.

@interface AVPlayer (CharonSourceClock)
@end

@implementation AVPlayer (CharonSourceClock)

- (id)sourceClock
{
    return ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("masterClock"));
}

- (void)setSourceClock:(id)sourceClock
{
    ((void (*)(id, SEL, id))objc_msgSend)(self, sel_registerName("setMasterClock:"), sourceClock);
}

@end