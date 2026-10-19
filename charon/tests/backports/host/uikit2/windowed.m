#import <UIKit/UIKit.h>
#import "check.h"

void charon_windowed_run(UIWindow *window);

@interface CharonWindowedDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonWindowedDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    return YES;
}

@end

@interface CharonWindowedScene : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonWindowedScene

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.frame = CGRectMake(0, 0, 320, 480);
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{
        charon_windowed_run(self.window);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        fflush(stdout);
        exit(charon_failures ? 1 : 0);
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"CharonWindowedDelegate");
    }
}
