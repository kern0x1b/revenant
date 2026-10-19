#import <ReplayKit/ReplayKit.h>

// The sample handler an extension subclasses. Nothing reaches it on this release, so every lifecycle call and every sample
// answers nothing. The host's base class holds no readable state, so the host's answer is that each call returns, and the
// port shows no more than that (facts/ReplayKit/RPBroadcastSampleHandler.md).
@implementation RPBroadcastSampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary *)setupInfo
{
}

- (void)broadcastPaused
{
}

- (void)broadcastResumed
{
}

- (void)broadcastFinished
{
}

- (void)broadcastAnnotatedWithApplicationInfo:(NSDictionary *)applicationInfo
{
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType
{
}

- (void)finishBroadcastWithError:(NSError *)error
{
}

@end
