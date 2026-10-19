#import "CharonAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

@implementation AVSampleBufferRenderSynchronizer (CharonCurrentTime12)

- (CMTime)currentTime
{
    return CMTimebaseGetTime(self.timebase);
}

@end
