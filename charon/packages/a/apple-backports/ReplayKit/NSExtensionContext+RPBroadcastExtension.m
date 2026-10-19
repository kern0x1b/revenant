#import <ReplayKit/ReplayKit.h>

// The two calls an extension makes on its context while the user sets up the broadcast. No extension runs on this release, so
// the setup that would answer the first never happens: its completion is never called, on the host or here, and the second
// has no request to finish and does nothing (facts/ReplayKit/NSExtensionContext+RPBroadcastExtension.md).
@implementation NSExtensionContext (RPBroadcastExtension)

- (void)loadBroadcastingApplicationInfoWithCompletion:(void (^)(NSString *, NSString *, UIImage *))handler
{
}

- (void)completeRequestWithBroadcastURL:(NSURL *)broadcastURL broadcastConfiguration:(RPBroadcastConfiguration *)broadcastConfiguration setupInfo:(NSDictionary *)setupInfo
{
}

- (void)completeRequestWithBroadcastURL:(NSURL *)broadcastURL setupInfo:(NSDictionary *)setupInfo
{
}

@end
