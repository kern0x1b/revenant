#import <ReplayKit/ReplayKit.h>

@implementation RPBroadcastHandler {
    NSExtensionContext *_extensionContext;
}

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context
{
    _extensionContext = context;
}

- (void)updateServiceInfo:(NSDictionary *)serviceInfo
{
}

- (void)updateBroadcastURL:(NSURL *)broadcastURL
{
}

@end
