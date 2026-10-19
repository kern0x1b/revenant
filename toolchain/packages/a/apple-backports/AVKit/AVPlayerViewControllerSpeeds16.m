#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVKitSpeeds.h"

@implementation AVPlaybackSpeed
{
    float _charonRate;
    NSString *_charonLocalizedName;
}

+ (NSArray<AVPlaybackSpeed *> *)systemDefaultSpeeds
{
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

static const void *CharonSpeedsKey = &CharonSpeedsKey;
static const void *CharonSelectedSpeedKey = &CharonSelectedSpeedKey;

@implementation AVPlayerViewController (CharonSpeeds16)

- (NSArray<AVPlaybackSpeed *> *)speeds
{
    NSArray *speeds = objc_getAssociatedObject(self, CharonSpeedsKey);
    return speeds ?: [AVPlaybackSpeed systemDefaultSpeeds];
}

- (void)setSpeeds:(NSArray<AVPlaybackSpeed *> *)speeds
{
    objc_setAssociatedObject(self, CharonSpeedsKey, [speeds copy] ?: [AVPlaybackSpeed systemDefaultSpeeds],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    AVPlaybackSpeed *selected = objc_getAssociatedObject(self, CharonSelectedSpeedKey);
    if (selected && ![speeds containsObject:selected])
        objc_setAssociatedObject(self, CharonSelectedSpeedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AVPlaybackSpeed *)selectedSpeed
{
    AVPlaybackSpeed *selected = objc_getAssociatedObject(self, CharonSelectedSpeedKey);
    if (selected && [self.speeds containsObject:selected])
        return selected;
    float rate = self.player.rate;
    for (AVPlaybackSpeed *speed in self.speeds) {
        if (speed.rate == rate)
            return speed;
    }
    return nil;
}

- (void)selectSpeed:(AVPlaybackSpeed *)speed
{
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
