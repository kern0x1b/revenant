// AVSampleBufferRenderSynchronizer14.m - -[AVSampleBufferRenderSynchronizer setRate:time:atHostTime:].
//
// The 16.4 header declares it for iOS 14.5 (AVSampleBufferRenderSynchronizer.h:110), the class is 11.0,
// and so this member cannot live in the object that defines the class: tools/release-split.lua reads the
// 11.0 image and would find a 14.5 member in an 11.0 object. A category is the shape the tree already
// uses for exactly this split. It reads -currentTime, which is the 12.0 object's, and never needs its own
// clock.
//
// WHAT IT DOES, measured on this Mac and not taken from the header, because the two disagree:
//
//   - a host time already past: the clock's time is the named time plus what the rate has run on since that
//     host time, and it keeps running at that rate. Measured over six 100 ms steps: 101.1051 at the first,
//     101.6221 at the sixth, a rate of 1.0 throughout.
//   - a host time still in the future: the clock holds the named time and does not move until that host
//     time arrives, then it runs at the rate. Measured over fifteen 100 ms steps: exactly 200.0000 at
//     100 ms, 200.0000 at 900 ms, 200.0463 at 1000 ms, 200.5669 at 1500 ms. The header's paragraph says
//     instead the header's paragraph says the timebase starts at once to run at the requested rate, from a
//     point before the named time, so that it arrives there at the requested host time, and the class on this Mac does
//     not do that; what it does is what is implemented here.
//   - an invalid time leaves the clock's time alone and applies the rate; an invalid host time applies the
//     named time and the rate at once. Measured, both.
//
// Both shapes are the release's own CMTimebase: CMTimebaseSetRateAndAnchorTime for the host time already
// past, and CMTimebaseSetRate(0) with a timer on the host clock for the one still ahead. The timer is
// applied on the synchronizer's own queue, through the same seam -charon_setRate:time:hostTime: the 11.0
// setter uses, so a renderer attached at that moment is told once, whichever way the clock was anchored.
#import "CharonAVSampleBufferRender.h"

#import <CoreMedia/CoreMedia.h>

@implementation AVSampleBufferRenderSynchronizer (CharonSetRateTimeAtHostTime14)

- (void)setRate:(float)rate time:(CMTime)time atHostTime:(CMTime)hostTime
{
    if (rate < 0.0f)
        [NSException raise:NSInvalidArgumentException
                    format:@"-[AVSampleBufferRenderSynchronizer setRate:time:atHostTime:] was given %f, and a rate must be greater than or equal to 0.0", (double)rate];
    // The header leaves it to the client to make sure a proper time and hostTime are set, and that this method
    // does no validation of improper time or hostTime values (the header) - so nothing is checked
    // here beyond the rate, which every other entry point on this class refuses too.
    [self charon_setRate:rate time:time hostTime:hostTime];
}

@end