#import <ReplayKit/ReplayKit.h>

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
