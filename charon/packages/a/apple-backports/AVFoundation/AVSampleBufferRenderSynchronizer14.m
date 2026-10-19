#import "CharonAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

@implementation AVSampleBufferRenderSynchronizer (CharonSetRateTimeAtHostTime14)

- (void)setRate:(float)rate time:(CMTime)time atHostTime:(CMTime)hostTime
{
    if (rate < 0.0f)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer setRate:time:atHostTime:] was given %f, and a rate must be greater than or equal to 0.0", (double)rate];
    [self charon_setRate:rate time:time hostTime:hostTime];
}

@end
