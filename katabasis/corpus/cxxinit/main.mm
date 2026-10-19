#import <UIKit/UIKit.h>
#include <cstdio>
#include <string>
#include <vector>

// Plain C logging so it is safe to call from a C++ static constructor (before main).
static void Mark(const char *event)
{
    FILE *f = fopen("/private/var/charon/cxxinit.log", "a");
    if (f) { fprintf(f, "CXXINIT %s\n", event); fclose(f); }
    fprintf(stderr, "CXXINIT %s\n", event);
}

// A file-scope C++ object with a non-trivial destructor. Its destructor is registered at
// load time via __cxa_atexit -- exactly the path xkcd's Realm statics take. If the runtime
// bridge for __cxa_atexit is wrong, this crashes during static initialization, before main.
struct Global {
    std::string name;
    std::vector<int> data;
    Global() : name("cxxinit-global"), data{1, 2, 3} { Mark("cxx static ctor"); }
    ~Global() { Mark("cxx static dtor"); }
};
static Global g_global;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    Mark([NSString stringWithFormat:@"didFinishLaunching global=%s size=%zu",
                                     g_global.name.c_str(), g_global.data.size()].UTF8String);
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor greenColor];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    Mark("window shown");
    return YES;
}
@end

int main(int argc, char *argv[])
{
    Mark("main enter");
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
