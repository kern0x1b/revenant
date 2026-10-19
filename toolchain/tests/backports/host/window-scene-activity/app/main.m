#import <UIKit/UIKit.h>
#include <stdio.h>

static FILE *out;

static void report(const char *side, const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

@interface RevenantActivityProvider : NSObject <UIActivityItemsConfigurationProviding>
@end

@implementation RevenantActivityProvider

- (UIActivityItemsConfiguration *)activityItemsConfiguration
{
    return nil;
}

@end

static void checks(const char *side, UIWindowScene *scene)
{
    report(side, "responds-source", yes_no([scene respondsToSelector:@selector(activityItemsConfigurationSource)]));
    report(side, "responds-set-source", yes_no([scene respondsToSelector:@selector(setActivityItemsConfigurationSource:)]));
    report(side, "source-default", scene.activityItemsConfigurationSource ? @"set" : @"nil");

    @autoreleasepool {
        RevenantActivityProvider *provider = [[RevenantActivityProvider alloc] init];
        scene.activityItemsConfigurationSource = provider;
        report(side, "source-set-same-object", yes_no(scene.activityItemsConfigurationSource == provider));
        report(side, "source-set-is-provider", yes_no(scene.activityItemsConfigurationSource == provider));
    }
    report(side, "source-after-provider-gone", scene.activityItemsConfigurationSource ? @"set" : @"nil");

    RevenantActivityProvider *kept = [[RevenantActivityProvider alloc] init];
    scene.activityItemsConfigurationSource = kept;
    report(side, "source-kept-while-held", yes_no(scene.activityItemsConfigurationSource == kept));
    scene.activityItemsConfigurationSource = nil;
    report(side, "source-cleared", scene.activityItemsConfigurationSource ? @"set" : @"nil");
    report(side, "kept-after-clear", yes_no(kept != nil));
}

@interface RevenantAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RevenantAppDelegate

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    return [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
}

@end

@interface RevenantSceneDelegate : UIResponder <UIWindowSceneDelegate>
@end

@implementation RevenantSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("REVENANT_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
#ifdef REVENANT_PORT_SIDE
    checks("port", [[UIWindowScene alloc] initWithSession:nil connectionOptions:nil]);
#else
    checks("host", (UIWindowScene *)scene);
#endif
    fclose(out);
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantAppDelegate class]));
    }
}
