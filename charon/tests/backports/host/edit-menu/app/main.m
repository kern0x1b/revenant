#import <UIKit/UIKit.h>
#include <stdio.h>

// A bundled Mac Catalyst app with the iPad idiom (UIDeviceFamily 2) and a window, which is how an edit menu is shown. The scene delegate
// runs the checks on the host's own UIEditMenuInteraction and, in the port's build, on the port's (compiled with the class renamed, so the
// host's is still reached by name). Each check writes one "side<TAB>check<TAB>value" line to the file named by CHARON_SCENE_OUT, then the app
// quits. The delegate's calls are written in the order they happen, with a number, so the order is part of the answer. run.sh builds both
// and diffs them.

static FILE *out;
static const char *side;
static int sequence;

static void report(const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
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

// The host's own UIKit adds private interactions when one of ours is added, so the counts are host observations only: they go to the file
// named by CHARON_HOST_ONLY_OUT, and are not compared with the port's.
static FILE *hostOnly;

static void report_host(const char *check, NSString *value)
{
    if (hostOnly)
        fprintf(hostOnly, "%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static void call(NSString *what)
{
    report("delegate-call", [NSString stringWithFormat:@"%d %@", ++sequence, what]);
}

@interface CharonEditMenuDelegate : NSObject <UIEditMenuInteractionDelegate>
@property (nonatomic, strong) UIMenu *menu;
@end

@implementation CharonEditMenuDelegate

- (UIMenu *)editMenuInteraction:(UIEditMenuInteraction *)interaction menuForConfiguration:(UIEditMenuConfiguration *)configuration suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions
{
    call([NSString stringWithFormat:@"menuForConfiguration suggested=%lu identifier=%@ sourceX=%g sourceY=%g", (unsigned long)suggestedActions.count,
          configuration.identifier, configuration.sourcePoint.x, configuration.sourcePoint.y]);
    return self.menu;
}

- (CGRect)editMenuInteraction:(UIEditMenuInteraction *)interaction targetRectForConfiguration:(UIEditMenuConfiguration *)configuration
{
    call(@"targetRectForConfiguration");
    return CGRectMake(5, 6, 7, 8);
}

- (void)editMenuInteraction:(UIEditMenuInteraction *)interaction willDismissMenuForConfiguration:(UIEditMenuConfiguration *)configuration animator:(id<UIEditMenuInteractionAnimating>)animator
{
    call(@"willDismissMenuForConfiguration");
}

@end

@interface CharonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonSceneDelegate

// The host's checks, run once the window is up. The delegate is kept by the test until the end, except where a check releases it.
static void checks(UIView *view, UIEditMenuInteraction *(^make)(id<UIEditMenuInteractionDelegate>))
{
    CharonEditMenuDelegate *delegate = [[CharonEditMenuDelegate alloc] init];
    delegate.menu = [UIMenu menuWithTitle:@"menu" children:@[[UIAction actionWithTitle:@"first" image:nil identifier:nil handler:^(UIAction *action) {}]]];
    UIEditMenuInteraction *interaction = make(delegate);
    report("interaction-class", class_name(interaction));
    report("delegate-kept", yes_no(interaction.delegate == delegate));
    report("view-before-add", yes_no(interaction.view == nil));
    report("interactions-before-add", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);
    [view addInteraction:interaction];
    report_host("interactions-after-add-classes", [[view.interactions valueForKey:@"description"] componentsJoinedByString:@"|"]);
    report("view-after-add", yes_no(interaction.view == view));
    report_host("interactions-after-add", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);

    UIEditMenuConfiguration *configuration = [UIEditMenuConfiguration configurationWithIdentifier:@"identifier" sourcePoint:CGPointMake(10, 11)];
    report("configuration-class", class_name(configuration));
    report("configuration-arrow-default", [NSString stringWithFormat:@"%ld", (long)configuration.preferredArrowDirection]);
    [interaction presentEditMenuWithConfiguration:configuration];
    CGPoint location = [interaction locationInView:view];
    report("location-in-view", NSStringFromCGPoint(location));
    report("location-in-nil", NSStringFromCGPoint([interaction locationInView:nil]));
    [interaction reloadVisibleMenu];
    [interaction updateVisibleMenuPositionAnimated:NO];
    [interaction dismissMenu];
    [view removeInteraction:interaction];
    report("view-after-remove", yes_no(interaction.view == nil));
    report_host("interactions-after-remove", [NSString stringWithFormat:@"%lu", (unsigned long)view.interactions.count]);
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("CHARON_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
#ifndef CHARON_PORT_SIDE
    const char *extra = getenv("CHARON_HOST_ONLY_OUT");
    hostOnly = extra ? fopen(extra, "w") : NULL;
#endif
#ifdef CHARON_PORT_SIDE
    side = "port";
#else
    side = "host";
#endif
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    UIViewController *root = [[UIViewController alloc] init];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    [root.view addSubview:view];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    // The checks run once the window has laid out and become key: a menu is presented into a settled window, not a new one.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.window layoutIfNeeded];
        report("scene-activation-state", [NSString stringWithFormat:@"%ld", (long)self.window.windowScene.activationState]);
        report("window-key", yes_no(self.window.isKeyWindow));
        report("view-in-window", yes_no(view.window == self.window));
        {
            CharonEditMenuDelegate *gone = [[CharonEditMenuDelegate alloc] init];
            __weak id weakDelegate = gone;
            UIEditMenuInteraction *lone = [[UIEditMenuInteraction alloc] initWithDelegate:gone];
            gone = nil;
            report("delegate-weak-after-release", yes_no(lone.delegate == nil && weakDelegate == nil));
        }
        checks(view, ^UIEditMenuInteraction *(id<UIEditMenuInteractionDelegate> delegate) {
            return [[UIEditMenuInteraction alloc] initWithDelegate:delegate];
        });
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        fclose(out);
        if (hostOnly)
            fclose(hostOnly);
        exit(0);
    });
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonSceneDelegate class]));
    }
}
