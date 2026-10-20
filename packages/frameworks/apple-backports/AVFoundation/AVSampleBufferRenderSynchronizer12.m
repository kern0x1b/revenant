#import "RevenantAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

@implementation AVSampleBufferRenderSynchronizer (RevenantCurrentTime12)

- (CMTime)currentTime
{
    return CMTimebaseGetTime(self.timebase);
}

@end
