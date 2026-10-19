//
//  app/main.m
//  The AVMovie probe (tests/backports/host/avf-movie4/probe.m) as an application on the emulated 6.1.3 device. The
//  application's bundle holds the movies the host's AVAssetWriter made (run-app.sh copies them in), and the probe reads
//  them from there. Its output is the application's standard output: the table of rows, then "rows: N".
//
#import <UIKit/UIKit.h>
#include <stdlib.h>

// probe.m, built with CHARON_AVMOVIE_APP, under this name instead of main.
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
