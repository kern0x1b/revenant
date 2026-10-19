#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *controller = [[UIViewController alloc] init];
    UILabel *label = [[UILabel alloc] initWithFrame:controller.view.bounds];
    label.text = @"$Name";
    label.textAlignment = NSTextAlignmentCenter;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [controller.view addSubview:label];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
