#import <UIKit/UIKit.h>
#include <stdlib.h>

int charon_avmovie_probe_main(int argc, const char **argv);

@interface CharonAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    const char *argv[] = {"probe", [[NSBundle mainBundle] resourcePath].UTF8String};
    int status = charon_avmovie_probe_main(2, argv);
    exit(status);
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonAppDelegate class]));
    }
}
