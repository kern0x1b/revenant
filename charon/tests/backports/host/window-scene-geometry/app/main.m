#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <stdio.h>

// A bundled Mac Catalyst app with the iPad idiom and a window, so a window scene exists the way an app meets one. The scene delegate runs the
// same checks on the host's own UIWindowScene and, in the port's build, on the port's (compiled with the classes renamed, so the host's is
// still reached by name): the geometry request's refusal, and the windowing behaviours class the scene's own answer is made of. Each check
// writes one "side<TAB>check<TAB>value" line to the file named by CHARON_SCENE_OUT, then the app quits. The scene's own windowingBehaviors is
// host-only evidence (CHARON_HOST_ONLY_OUT): the port answers nil there, as iPhone and iPad do, so it is not compared.

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

// The refusal the request gives: the handler's error, and whether the handler ran before the request returned.
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
    // A nil handler is allowed, and the request still returns.
    [scene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
    report("geometry-nil-handler", @"returned");
}

// The windowing behaviours class: made at run time (its -init is unavailable to the compiler, as the header says), with both flags NO, and
// neither flag changed by a set.
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
