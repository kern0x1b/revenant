//
//  tests/backports/emulate/edgegesture/app/main.m
//  A plain application with one white window, for measuring which gestures from the screen edges the release answers
//  before the application sees them (facts/UIKit/HomeIndicator.md). It draws nothing that a system gesture could be
//  confused with, and it logs that it is frontmost, so the snapshots that xmake emulate takes show the release's own
//  reaction to a drag and nothing of the application's.
//

#import <UIKit/UIKit.h>
#include <stdio.h>

@interface CharonEdgeProbeDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation CharonEdgeProbeDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    printf("edge probe: the window is up\n");
    fflush(stdout);
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonEdgeProbeDelegate class]));
    }
}
