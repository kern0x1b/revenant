#import <ReplayKit/ReplayKit.h>

// The broadcast picker of iOS 10. The host loads a controller whatever the preferred extension is, and the port does the same:
// there is no extension to list, so the view holds a plain view and nothing the user can press. The handler is called once,
// before the load returns, with the controller and no error. This is the host's answer as measured, and it departs from the
// header, which says the controller is nil when no extension matches (facts/ReplayKit/RPBroadcastActivityViewController.md).
@implementation RPBroadcastActivityViewController

+ (void)loadBroadcastActivityViewControllerWithHandler:(void (^)(RPBroadcastActivityViewController *, NSError *))handler
{
    [self loadBroadcastActivityViewControllerWithPreferredExtension:nil handler:handler];
}

+ (void)loadBroadcastActivityViewControllerWithPreferredExtension:(NSString *)preferredExtension handler:(void (^)(RPBroadcastActivityViewController *, NSError *))handler
{
    handler([[RPBroadcastActivityViewController alloc] initWithNibName:nil bundle:nil], nil);
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
}

@end
