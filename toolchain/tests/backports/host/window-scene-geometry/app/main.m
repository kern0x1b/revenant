#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <stdio.h>

static FILE *out;
static FILE *hostOnly;
static const char *side;

static void report(const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static void report_host(const char *check, NSString *value)
{
    if (hostOnly)
        fprintf(hostOnly, "host\t%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static void geometry_checks(id scene, UIWindowSceneGeometryPreferencesIOS *preferences)
{
    report("geometry-responds", yes_no([scene respondsToSelector:@selector(requestGeometryUpdateWithPreferences:errorHandler:)]));
    __block int calls = 0;
    __block NSError *seen = nil;
    [scene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError *error) {
        calls++;
        seen = error;
    }];
    report("geometry-handler-before-return", yes_no(calls == 1));
    report("geometry-handler-calls", [NSString stringWithFormat:@"%d", calls]);
    report("geometry-error-domain", seen.domain);
    report("geometry-error-code", [NSString stringWithFormat:@"%ld", (long)seen.code]);
    report("geometry-error-description", seen.localizedDescription);
    [scene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
    report("geometry-nil-handler", @"returned");
}

static void windowing_checks(void)
{
    Class behaviours = [UISceneWindowingBehaviors class];
    report("windowing-class", class_name(behaviours));
    id made = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(behaviours, @selector(alloc)), @selector(init));
    report("windowing-made-class", made ? class_name(made) : @"nil");
    report("windowing-closable-default", yes_no(((BOOL (*)(id, SEL))objc_msgSend)(made, @selector(isClosable))));
    report("windowing-miniaturizable-default", yes_no(((BOOL (*)(id, SEL))objc_msgSend)(made, @selector(isMiniaturizable))));
    ((void (*)(id, SEL, BOOL))objc_msgSend)(made, @selector(setClosable:), YES);
    report("windowing-closable-after-set-yes", yes_no(((BOOL (*)(id, SEL))objc_msgSend)(made, @selector(isClosable))));
    ((void (*)(id, SEL, BOOL))objc_msgSend)(made, @selector(setMiniaturizable:), YES);
    report("windowing-miniaturizable-after-set-yes", yes_no(((BOOL (*)(id, SEL))objc_msgSend)(made, @selector(isMiniaturizable))));
}

static void checks(id scene)
{
    report("idiom", [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"pad" : @"other");
    UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
    geometry_checks(scene, preferences);
    windowing_checks();
}

@interface CharonAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CharonAppDelegate

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    return [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
}

@end

@interface CharonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("CHARON_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    [self.window makeKeyAndVisible];
#ifdef CHARON_PORT_SIDE
    side = "port";
    checks([[UIWindowScene alloc] initWithSession:nil connectionOptions:nil]);
#else
    side = "host";
    const char *extra = getenv("CHARON_HOST_ONLY_OUT");
    hostOnly = extra ? fopen(extra, "w") : NULL;
    checks(scene);
    report_host("scene-windowing-behaviors", self.window.windowScene.windowingBehaviors ? class_name(self.window.windowScene.windowingBehaviors) : @"nil");
    if (hostOnly)
        fclose(hostOnly);
#endif
    fclose(out);
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonAppDelegate class]));
    }
}
