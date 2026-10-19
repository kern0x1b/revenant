#import <CallKit/CallKit.h>

// The principal class of a call directory extension, which iOS 6 never loads (facts/Foundation/CloudAndExtensions.md):
// an extension's subclass overrides the request, and the base class does nothing with it, as the host's does.
@implementation CXCallDirectoryProvider

- (void)beginRequestWithExtensionContext:(CXCallDirectoryExtensionContext *)context
{
}

@end
