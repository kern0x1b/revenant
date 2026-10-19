// AVSampleBufferRenderSynchronizer12.m - -[AVSampleBufferRenderSynchronizer currentTime].
//
// The 16.4 header declares it for iOS 12.0 (AVSampleBufferRenderSynchronizer.h:65), the class is 11.0, and
// so this member cannot live in the object that defines the class: tools/release-split.lua reads the
// 11.0 image and would find a 12.0 member in an 11.0 object. A category is the shape the tree already
// uses for exactly this split.
//
// It is one CMTimebase call, and it is what the host answers: the synchronizer's own clock, to the
// nanosecond, with the timescale that clock carries. Measured on this Mac, -currentTime right after
// -setRate:time: 600/1 reads 600000011125/1000000000, which is what CMTimebaseGetTime on a timebase whose
// time has just been set answers as well (the timebase keeps its own timescale and converts), and this
// Mac's -currentTime on a fresh synchronizer reads 0/1, which is what a fresh timebase reads too. The
// header's own note - "Not key-value observable; use
// -addPeriodicTimeObserverForInterval:queue:usingBlock: instead" - is why there is nothing else here.
#import "CharonAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

@implementation AVSampleBufferRenderSynchronizer (CharonCurrentTime12)

- (CMTime)currentTime
{
    return CMTimebaseGetTime(self.timebase);
}

@end