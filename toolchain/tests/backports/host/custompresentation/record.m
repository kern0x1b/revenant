#import <UIKit/UIKit.h>
#import "custompresentation-cases.h"

@interface RecordDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RecordDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options { return YES; }
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableDictionary *records = [NSMutableDictionary dictionary];
        printf("state %ld animations %d keywindow %d scene %ld\n", (long)[UIApplication sharedApplication].applicationState, [UIView areAnimationsEnabled], self.window.isKeyWindow, (long)self.window.windowScene.activationState);
        custompresentation_run(self.window, ^(NSString *name, NSString *value) {
            records[name] = value;
            printf("%s: %s\n", name.UTF8String, value.UTF8String);
            fflush(stdout);
        }, ^{
            [[NSJSONSerialization dataWithJSONObject:records options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:NULL] writeToFile:@(getenv("CUSTOMPRES_RECORDS")) atomically:YES];
            exit(0);
        });
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"RecordDelegate");
    }
}
