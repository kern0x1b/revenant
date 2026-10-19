#import "CharonAVFAudio.h"

@implementation AVAudioUnitComponent (Charon16)

- (NSDictionary<NSString *, id> *)configurationDictionary
{
    return @{};
}

- (nullable UIImage *)icon
{
    return nil;
}

- (BOOL)passesAUVal
{
    return NO;
}

@end
