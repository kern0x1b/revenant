#import <UIKit/UIKit.h>
#import "searchcontroller-cases.h"

static NSString *output_path;

@interface RecordDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RecordDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    return YES;
}

@end

@interface RecordScene : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RecordScene

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.frame = CGRectMake(0, 0, 320, 480);
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    NSTimer *timer = [NSTimer timerWithTimeInterval:1 target:[NSBlockOperation blockOperationWithBlock:^{
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        searchcontroller_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("%s: %s\n", name.UTF8String, value.UTF8String);
            fflush(stdout);
        });
        [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:output_path atomically:YES];
        exit(0);
    }] selector:@selector(main) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

@end

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    @autoreleasepool {
        output_path = argc > 1 ? @(argv[1]) : @"/dev/null";
        return UIApplicationMain(argc, argv, nil, @"RecordDelegate");
    }
}
