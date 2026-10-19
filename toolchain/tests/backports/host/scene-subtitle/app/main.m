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

static void checks(const char *side, id scene)
{
    report(side, "responds-subtitle", yes_no([scene respondsToSelector:@selector(subtitle)]));
    report(side, "responds-setSubtitle", yes_no([scene respondsToSelector:@selector(setSubtitle:)]));
    report(side, "title-default", [scene title]);
    report(side, "subtitle-default", [scene subtitle]);
    NSMutableString *given = [NSMutableString stringWithString:@"sub"];
    [scene setSubtitle:given];
    [given appendString:@"changed"];
    report(side, "subtitle-kept-by-reference", [scene subtitle]);
    report(side, "subtitle-same-object", yes_no([scene subtitle] == given));
    [scene setSubtitle:@""];
    report(side, "subtitle-empty", [scene subtitle]);
    [scene setSubtitle:nil];
    report(side, "subtitle-nil", [scene subtitle]);
    [scene setSubtitle:@"again"];
    report(side, "subtitle-set-again", [scene subtitle]);
    report(side, "title-unchanged", [scene title]);
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
    checks("port", [[UIScene alloc] initWithSession:nil connectionOptions:nil]);
#else
    checks("host", scene);
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
