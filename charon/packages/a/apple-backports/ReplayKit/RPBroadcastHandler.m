#import <ReplayKit/ReplayKit.h>

// The base of the extension handlers. The system makes a handler in an extension process this release does not run, so the
// port's handler is the class an application subclasses and calls, and its methods answer what the host's show from outside.
// The request start keeps the context and calls nothing on it: the host crashes on a fresh context, inside its own base
// method, and this release has no app extension to make the call that would follow (facts/ReplayKit/RPBroadcastSampleHandler.md).
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
