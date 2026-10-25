#import <UIKit/UIKit.h>

// Asks for the system font from inside UIApplicationMain's launch, the way an app does, and prints
// what it got. A process that dies here has lost the font path; one that prints FONT-APP-DONE has not.
@interface FontAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation FontAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    UIFont *font = [UIFont systemFontOfSize:24];
    printf("FONT-APP systemFontOfSize=%s\n", font ? "ok" : "nil");
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"Hxg" attributes:@{NSFontAttributeName: font}];
    CGSize size = [text size];
    printf("FONT-APP size=%g,%g\n", size.width, size.height);
    printf("FONT-APP-DONE\n");
    fflush(stdout);
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([FontAppDelegate class]));
    }
}
