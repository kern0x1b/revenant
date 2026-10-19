#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation AVPlayer (CharonAVFoundation10)

- (AVPlayerTimeControlStatus)timeControlStatus
{
    AVPlayerItem *item = self.currentItem;
    if (item == nil)
        return AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
    if (self.rate == 0.0f)
        return AVPlayerTimeControlStatusPaused;
    return item.isPlaybackLikelyToKeepUp ? AVPlayerTimeControlStatusPlaying
                                         : AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
}

@end
