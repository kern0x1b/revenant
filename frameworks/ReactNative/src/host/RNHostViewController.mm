#import "RNHostViewController.h"
#import "RNHostRuntime.h"
#import "RNHostYoga.h"

@implementation RNHostViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(self.view.bounds, 20, 20)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.numberOfLines = 0;
    label.text = [self statusText];
    [self.view addSubview:label];
}

- (NSString *)statusText
{
    [RNHostRuntime logClassProbes];
    NSString *path = [RNHostRuntime configuredBundlePath] ?: [[[NSBundle mainBundle] pathsForResourcesOfType:@"js" inDirectory:nil] firstObject];
    NSError *error = nil;
    NSString *bundleText = path ? [RNHostRuntime evaluateBundleAtPath:path error:&error] : @"no .js bundle in app";
    if (!bundleText) bundleText = [NSString stringWithFormat:@"error: %@", error.localizedDescription];
    return [NSString stringWithFormat:@"bundle: %@\nyoga width: %g", bundleText, RNHostYogaProbeWidth()];
}

@end
