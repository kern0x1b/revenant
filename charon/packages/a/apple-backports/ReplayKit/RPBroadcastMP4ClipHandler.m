#import <ReplayKit/ReplayKit.h>

// The handler of the movie clips a broadcast records, from iOS 10 to 11. No clip is recorded on this release, so the clip
// the system would hand over never arrives, and the two calls answer nothing (facts/ReplayKit/RPBroadcastSampleHandler.md).
@implementation RPBroadcastMP4ClipHandler

- (void)processMP4ClipWithURL:(NSURL *)mp4ClipURL setupInfo:(NSDictionary *)setupInfo finished:(BOOL)finished
{
}

- (void)finishedProcessingMP4ClipWithUpdatedBroadcastConfiguration:(RPBroadcastConfiguration *)broadcastConfiguration error:(NSError *)error
{
}

@end
