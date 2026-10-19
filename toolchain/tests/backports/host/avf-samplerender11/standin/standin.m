#import <AVFoundation/AVFoundation.h>

NSString *const AVFoundationErrorDomain = @"AVFoundationErrorDomain";

@implementation NSValue (RevenantStandinCMTime)

+ (NSValue *)valueWithCMTime:(CMTime)time
{
    return [NSValue valueWithBytes:&time objCType:@encode(CMTime)];
}

- (CMTime)CMTimeValue
{
    CMTime time;
    [self getValue:&time];
    return time;
}

@end
