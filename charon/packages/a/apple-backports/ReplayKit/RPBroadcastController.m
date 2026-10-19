#import <ReplayKit/ReplayKit.h>

// The controller of a broadcast the user has set up. A port never has a session: no extension runs on this release, so
// nothing is broadcasting, nothing is paused, and no URL, service information or extension identifier exists. The start
// answers -5808, the header's code for a start with no prior session. That is documented, not measured: measuring it would
// start a capture on the host (facts/ReplayKit/RPBroadcastController.md). Finishing a broadcast that never started answers
// -5829, which the host measures.
@implementation RPBroadcastController

- (BOOL)isBroadcasting
{
    return NO;
}

- (BOOL)isPaused
{
    return NO;
}

- (NSURL *)broadcastURL
{
    return nil;
}

- (NSDictionary *)serviceInfo
{
    return nil;
}

- (NSString *)broadcastExtensionBundleID
{
    return nil;
}

- (void)startBroadcastWithHandler:(void (^)(NSError *))handler
{
    NSError *error = [NSError errorWithDomain:RPRecordingErrorDomain code:RPRecordingErrorBroadcastInvalidSession userInfo:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
    });
}

- (void)pauseBroadcast
{
}

- (void)resumeBroadcast
{
}

- (void)finishBroadcastWithHandler:(void (^)(NSError *))handler
{
    NSError *error = [NSError errorWithDomain:RPRecordingErrorDomain code:RPRecordingErrorAttemptToStopNonRecording userInfo:nil];
    handler(error);
}

@end
