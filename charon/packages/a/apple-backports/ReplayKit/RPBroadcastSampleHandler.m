#import <ReplayKit/ReplayKit.h>

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
