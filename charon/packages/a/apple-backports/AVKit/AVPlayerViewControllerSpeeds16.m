// AVPlayerViewControllerSpeeds16.m - the 16.0 playback speed API: AVPlaybackSpeed, and the three
// members of AVPlayerViewController that carry it. One object, one release: every name below is
// ios(16.0) in the SDK 26.2 header, and the registry's minimum places the whole object.
//
// WHAT IS MEASURED, and where each value came from. The rates and the two kinds of name are the
// system's own answers, read out of the host's AVKit by tests/backports/host/avkitspeeds/host.m
// (locale en_US@rg=plzzzz, 5 speeds, fastest first):
//
//     speed: rate=2     name=Double numeric=2x        <- the real character is U+00D7
//     speed: rate=1.5   name=Faster numeric=1,5x
//     speed: rate=1.25  name=Fast   numeric=1,25x
//     speed: rate=1     name=Normal numeric=1x
//     speed: rate=0.5   name=Half   numeric=0,5x
//     made:  rate=1.75  name=port probe numeric=1,75x
//
// Two facts in that output carry the implementation. First, +systemDefaultSpeeds is ordered
// fastest first, so the port's list is in that order and not sorted by us. Second, a speed built by
// the public initialiser with the name "port probe" still answers the numeric name "1,75x": the
// numeric name is not stored, it is computed from the rate, so this class derives it and the digits
// come out of the DEVICE's own locale rather than out of a string typed here. That is why the
// separator above is a comma (the measured locale's) while the source of this file stays ASCII and
// the multiplication sign is written as an escape.
//
// The release's own substrate, measured in the armv7 shared cache of 6.1.3 (568965 names): the
// AVPlayer `rate` property, `canPlayFastForward` and `canPlaySlowForward` are all there (`rate`
// first appears at 3.0, the two capability selectors at 5.0), and this port's transport bar already
// reads `player.rate` to decide whether to draw play or pause. `defaultRate` is NOT there - it
// first appears at 16.0 - which is the one place this port parts company with the header and says so
// below rather than inventing a stand-in for it.
//
// THE DEVIATION, in the header's own terms. AVPlaybackSpeed.h:51 documents that the rate takes effect
// when the play button is pressed, and AVPlayerViewController.h:187 documents that
// selectedSpeed tracks the associated AVPlayer's `defaultRate` in both directions. This release has
// no `defaultRate` to track, so the port keeps the selection itself and applies it on the same event
// the header names: -selectSpeed: takes effect at once when the player is already playing, and
// otherwise on the next press of play, which AVPlayerViewController.m's own -charon_playPause: calls
// through -charon_applySelectedSpeed. Nothing here is a stored value that is never read.

#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// The seam AVPlayerViewController.m's play path calls: declared in CharonAVKitSpeeds.h, defined
// below, in this object, which owns the 16.0 API. Registered as its own row; see the registry.
#import "CharonAVKitSpeeds.h"

@implementation AVPlaybackSpeed
{
    float _charonRate;
    NSString *_charonLocalizedName;
}

+ (NSArray<AVPlaybackSpeed *> *)systemDefaultSpeeds
{
    // The five the host answers, in the order it answers them. Built once: these are read-only
    // objects the caller may hand back to -selectSpeed:, and two calls answering equal-but-distinct
    // arrays would make -selectedSpeed's identity comparison depend on call order.
    static NSArray<AVPlaybackSpeed *> *speeds;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        speeds = @[[[AVPlaybackSpeed alloc] initWithRate:2.0f localizedName:@"Double"],
                   [[AVPlaybackSpeed alloc] initWithRate:1.5f localizedName:@"Faster"],
                   [[AVPlaybackSpeed alloc] initWithRate:1.25f localizedName:@"Fast"],
                   [[AVPlaybackSpeed alloc] initWithRate:1.0f localizedName:@"Normal"],
                   [[AVPlaybackSpeed alloc] initWithRate:0.5f localizedName:@"Half"]];
    });
    return speeds;
}

- (instancetype)initWithRate:(float)rate localizedName:(NSString *)localizedName
{
    if ((self = [super init])) {
        _charonRate = rate;
        _charonLocalizedName = [localizedName copy] ?: @"";
    }
    return self;
}

- (float)rate
{
    return _charonRate;
}

- (NSString *)localizedName
{
    return _charonLocalizedName;
}

- (NSString *)localizedNumericName
{
    // Measured: a speed named "port probe" at rate 1.75 answers "1,75x", so the host computes this
    // from the rate in the current locale. NSNumberFormatter is the release's own locale-aware
    // formatter, so the digits and the decimal separator are the device's, not this file's.
    static NSNumberFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 2;
        formatter.minimumFractionDigits = 0;
        formatter.usesGroupingSeparator = NO;
    });
    NSString *digits = [formatter stringFromNumber:@(_charonRate)] ?: [NSString stringWithFormat:@"%g", (double)_charonRate];
    return [NSString stringWithFormat:@"%@\u00D7", digits];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVPlaybackSpeed %.6g %@>", (double)_charonRate, _charonLocalizedName];
}

@end

// The controller's own state, kept beside the class because a category cannot add an ivar. The two
// associated keys are file-static, so nothing here is a new exported name.
static const void *CharonSpeedsKey = &CharonSpeedsKey;
static const void *CharonSelectedSpeedKey = &CharonSelectedSpeedKey;

@implementation AVPlayerViewController (CharonSpeeds16)

- (NSArray<AVPlaybackSpeed *> *)speeds
{
    // The public getter, spelled as the header spells it. Measured: naming this charon_speeds
    // instead compiles clean and leaves -speeds unimplemented, which otool -ov shows as a category
    // holding setSpeeds: and no getter - the property would then answer nothing at all.
    NSArray *speeds = objc_getAssociatedObject(self, CharonSpeedsKey);
    return speeds ?: [AVPlaybackSpeed systemDefaultSpeeds];
}

- (void)setSpeeds:(NSArray<AVPlaybackSpeed *> *)speeds
{
    // A copy, as the header's `copy` says. A nil list is not a list: the header types it
    // non-null, and an empty one would make every later -selectSpeed: a no-op by the rule below.
    objc_setAssociatedObject(self, CharonSpeedsKey, [speeds copy] ?: [AVPlaybackSpeed systemDefaultSpeeds],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    // A selection that is no longer offered stops being the selection, which is what the header's
    // "ignored" rule implies from the other end.
    AVPlaybackSpeed *selected = objc_getAssociatedObject(self, CharonSelectedSpeedKey);
    if (selected && ![speeds containsObject:selected])
        objc_setAssociatedObject(self, CharonSelectedSpeedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AVPlaybackSpeed *)selectedSpeed
{
    AVPlaybackSpeed *selected = objc_getAssociatedObject(self, CharonSelectedSpeedKey);
    if (selected && [self.speeds containsObject:selected])
        return selected;
    // No selection made yet, or the player's rate was set from outside: the header says a rate that
    // matches no speed in the list leaves this nil, and the nearest honest reading of "which speed is
    // this" is the one whose rate the player is actually running at.
    float rate = self.player.rate;
    for (AVPlaybackSpeed *speed in self.speeds) {
        if (speed.rate == rate)
            return speed;
    }
    return nil;
}

- (void)selectSpeed:(AVPlaybackSpeed *)speed
{
    // The header says that selectSpeed given an AVPlaybackSpeed outside the speeds property array is ignored.
    // A nil speed is ignored by the same rule: there is nothing to select.
    if (!speed || ![self.speeds containsObject:speed])
        return;
    objc_setAssociatedObject(self, CharonSelectedSpeedKey, speed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.player.rate != 0)
        [self charon_applySelectedSpeed];
}

- (void)charon_applySelectedSpeed
{
    AVPlaybackSpeed *selected = objc_getAssociatedObject(self, CharonSelectedSpeedKey);
    if (selected && self.player)
        self.player.rate = selected.rate;
}

@end
