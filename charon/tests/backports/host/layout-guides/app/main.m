#import <UIKit/UIKit.h>
#include <stdio.h>
#include <objc/message.h>

// A bundled Mac Catalyst app with a window, so the window's safe area and its layout guides exist the way an app meets them. The scene
// delegate runs the same checks on the host's own guides and, in the port's build, on the port's (the guide classes are compiled renamed, and
// the view and window categories replace the host's methods in that process, so the port's answers are the ones read). Each check writes one
// "side<TAB>check<TAB>value" line to the file named by CHARON_SCENE_OUT, then the app quits. run.sh builds both and diffs them. The host's
// class names are host-only evidence (CHARON_HOST_ONLY_OUT), since the port's classes are its own.

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

static NSString *frame_text(CGRect r)
{
    return [NSString stringWithFormat:@"%g,%g,%g,%g", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *class_named(Class cls)
{
    NSString *name = NSStringFromClass(cls);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *count_text(NSArray *items)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)items.count];
}

// A set that raises: the name of the exception, or ok.
static NSString *outcome(void (^change)(void))
{
    @try {
        change();
        return @"ok";
    } @catch (NSException *exception) {
        return exception.name;
    }
}

static void keyboard_checks(UIViewController *root)
{
    UIView *view = root.view;
    UIKeyboardLayoutGuide *keyboard = view.keyboardLayoutGuide;
    report("keyboard-class", class_name(keyboard));
    report("keyboard-superclass", class_named([[keyboard class] superclass]));
    report("keyboard-owning-view-is-view", yes_no(keyboard.owningView == view));
    report("keyboard-same-object-on-read", yes_no(view.keyboardLayoutGuide == keyboard));
    report("keyboard-follows-default", yes_no(keyboard.followsUndockedKeyboard));
    keyboard.followsUndockedKeyboard = YES;
    report("keyboard-follows-set", yes_no(keyboard.followsUndockedKeyboard));
    keyboard.followsUndockedKeyboard = NO;
    report("keyboard-follows-cleared", yes_no(keyboard.followsUndockedKeyboard));
    [view layoutIfNeeded];
    report("keyboard-frame-no-keyboard", frame_text(keyboard.layoutFrame));
    report_host("keyboard-host-class", class_name(keyboard));
}

static void tracking_checks(UIView *view)
{
    UITrackingLayoutGuide *tracking = [[UITrackingLayoutGuide alloc] init];
    [view addLayoutGuide:tracking];
    report("tracking-superclass", class_named([[tracking class] superclass]));
    report("tracking-near-default", count_text([tracking constraintsActiveWhenNearEdge:NSDirectionalRectEdgeBottom]));
    report("tracking-away-default", count_text([tracking constraintsActiveWhenAwayFromEdge:NSDirectionalRectEdgeTop]));
    NSLayoutConstraint *near = [tracking.topAnchor constraintEqualToAnchor:view.topAnchor];
    NSLayoutConstraint *away = [tracking.bottomAnchor constraintEqualToAnchor:view.bottomAnchor];
    [tracking setConstraints:@[near] activeWhenNearEdge:NSDirectionalRectEdgeBottom];
    report("tracking-near-set-count", count_text([tracking constraintsActiveWhenNearEdge:NSDirectionalRectEdgeBottom]));
    report("tracking-near-same-element", yes_no([tracking constraintsActiveWhenNearEdge:NSDirectionalRectEdgeBottom].firstObject == near));
    report("tracking-near-other-edge", count_text([tracking constraintsActiveWhenNearEdge:NSDirectionalRectEdgeTop]));
    [tracking setConstraints:@[away] activeWhenAwayFromEdge:NSDirectionalRectEdgeBottom];
    report("tracking-away-set-count", count_text([tracking constraintsActiveWhenAwayFromEdge:NSDirectionalRectEdgeBottom]));
    report("tracking-near-after-away-set", count_text([tracking constraintsActiveWhenNearEdge:NSDirectionalRectEdgeBottom]));
    report("tracking-away-other-edge", count_text([tracking constraintsActiveWhenAwayFromEdge:NSDirectionalRectEdgeTop]));
    [tracking removeAllTrackedConstraints];
    report("tracking-near-after-remove", count_text([tracking constraintsActiveWhenNearEdge:NSDirectionalRectEdgeBottom]));
    report("tracking-away-after-remove", count_text([tracking constraintsActiveWhenAwayFromEdge:NSDirectionalRectEdgeBottom]));
    report("tracking-nil-set-raises", outcome(^{ [tracking setConstraints:nil activeWhenNearEdge:NSDirectionalRectEdgeTop]; }));
}

static void aspect_checks(UIWindow *window)
{
    UILayoutGuide *fit = window.safeAreaAspectFitLayoutGuide;
    report("aspect-superclass", class_named([[fit class] superclass]));
    report("aspect-owning-view-is-window", yes_no(fit.owningView == window));
    report("aspect-same-object-on-read", yes_no(window.safeAreaAspectFitLayoutGuide == fit));
    report("aspect-responds-ratio", yes_no([fit respondsToSelector:@selector(aspectRatio)]));
    [window layoutIfNeeded];
    report("aspect-default-ratio", [NSString stringWithFormat:@"%g", ((CGFloat (*)(id, SEL))objc_msgSend)(fit, @selector(aspectRatio))]);
    report("aspect-default-frame", frame_text(fit.layoutFrame));
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(fit, @selector(setAspectRatio:), 2.0);
    report("aspect-ratio-set", [NSString stringWithFormat:@"%g", ((CGFloat (*)(id, SEL))objc_msgSend)(fit, @selector(aspectRatio))]);
    [window layoutIfNeeded];
    report("aspect-frame-ratio-2", frame_text(fit.layoutFrame));
    report("aspect-safe-frame", frame_text(window.safeAreaLayoutGuide.layoutFrame));
    report_host("aspect-host-class", class_name(fit));
}

static void checks(UIWindow *window, UIViewController *root)
{
    report("idiom", [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"pad" : @"other");
    report("window-bounds", frame_text(window.bounds));
    keyboard_checks(root);
    tracking_checks(root.view);
    aspect_checks(window);
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
    UIViewController *root = [[UIViewController alloc] init];
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
#ifdef CHARON_PORT_SIDE
    side = "port";
    checks(self.window, root);
#else
    side = "host";
    const char *extra = getenv("CHARON_HOST_ONLY_OUT");
    hostOnly = extra ? fopen(extra, "w") : NULL;
    checks(self.window, root);
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
