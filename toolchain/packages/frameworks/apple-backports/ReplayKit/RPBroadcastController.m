#import <ReplayKit/ReplayKit.h>

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
