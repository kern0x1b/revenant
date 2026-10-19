#import <UIKit/UIKit.h>
#include <stdio.h>
#include <objc/message.h>

// A bundled Mac Catalyst app with the iPad idiom and a window. The scene delegate runs the same checks on the host's pointer interaction, the
// button's pointer members and the pointer lock state, and, in the port's build, on the port's (the interaction and the lock state are compiled
// renamed, and the button and scene and view-controller categories have the host's method names, so in that process they replace the host's
// and the checks read the port's answers). Each check writes one "side<TAB>check<TAB>value" line to the file named by CHARON_SCENE_OUT, then the
// app quits. The host has a pointing device, which a bundled application cannot drive: no hover, no region and no animator are measured.

static FILE *out;
static const char *side;

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
    if (!object)
        return @"nil";
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

// A delegate for the interaction, which the test holds weakly and then lets go.
@interface CharonPointerDelegate : NSObject <UIPointerInteractionDelegate>
@end

@implementation CharonPointerDelegate
@end

static void interaction_checks(UIView *view)
{
    CharonPointerDelegate *delegate = [[CharonPointerDelegate alloc] init];
    UIPointerInteraction *interaction = [[UIPointerInteraction alloc] initWithDelegate:delegate];
    report("interaction-class", class_name(interaction));
    report("interaction-enabled-default", yes_no(interaction.enabled));
    interaction.enabled = NO;
    report("interaction-enabled-set-no", yes_no(interaction.enabled));
    interaction.enabled = YES;
    report("interaction-enabled-set-yes", yes_no(interaction.enabled));
    report("interaction-delegate-kept", yes_no(interaction.delegate == delegate));
    report("interaction-view-before-add", interaction.view ? @"set" : @"nil");
    [view addInteraction:interaction];
    report("interaction-view-after-add", yes_no(interaction.view == view));
    report("interaction-listed-after-add", yes_no([view.interactions containsObject:interaction]));
    [view removeInteraction:interaction];
    report("interaction-view-after-remove", interaction.view ? @"set" : @"nil");
    report("interaction-listed-after-remove", yes_no([view.interactions containsObject:interaction]));
    @autoreleasepool {
        CharonPointerDelegate *lone = [[CharonPointerDelegate alloc] init];
        UIPointerInteraction *held = [[UIPointerInteraction alloc] initWithDelegate:lone];
        lone = nil;
        report("interaction-delegate-weak", held.delegate ? @"held" : @"nil");
    }
}

static void button_checks(UIViewController *root)
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [root.view addSubview:button];
    report("button-enabled-default", yes_no(button.isPointerInteractionEnabled));
    report("button-provider-default", button.pointerStyleProvider ? @"set" : @"nil");
    button.pointerInteractionEnabled = YES;
    report("button-enabled-set-yes", yes_no(button.pointerInteractionEnabled));
    button.pointerInteractionEnabled = NO;
    report("button-enabled-set-no", yes_no(button.pointerInteractionEnabled));
    button.pointerStyleProvider = ^UIPointerStyle *(UIButton *b, UIPointerEffect *effect, UIPointerShape *shape) {
        return nil;
    };
    report("button-provider-set", button.pointerStyleProvider ? @"set" : @"nil");
    report("button-enabled-after-provider", yes_no(button.pointerInteractionEnabled));
    button.pointerStyleProvider = nil;
    report("button-provider-cleared", button.pointerStyleProvider ? @"set" : @"nil");
}

static void lock_checks(UIViewController *root)
{
    // +new and -init are unavailable to the compiler, as the header says; the runtime answers them.
    UIPointerLockState *made = ((id (*)(id, SEL))objc_msgSend)(UIPointerLockState.class, @selector(new));
    report("lock-class", class_name(made));
    id initialised = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(UIPointerLockState.class, @selector(alloc)), @selector(init));
    report("lock-init-class", class_name(initialised));
    report("lock-locked-default", yes_no(made.locked));
    UIPointerLockState *state = root.view.window.windowScene.pointerLockState;
    report("scene-lock-class", class_name(state));
    report("scene-lock-same-on-read", yes_no(root.view.window.windowScene.pointerLockState == state));
    report("scene-lock-locked-default", yes_no(state.locked));
    report("vc-prefers-locked-default", yes_no(root.prefersPointerLocked));
    report("vc-child-for-lock-default", root.childViewControllerForPointerLock ? @"set" : @"nil");
    [root setNeedsUpdateOfPrefersPointerLocked];
    report("vc-prefers-locked-after-update", yes_no(root.prefersPointerLocked));
    report("scene-lock-locked-after-update", yes_no(state.locked));
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
#else
    side = "host";
#endif
    report("idiom", [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"pad" : @"other");
    interaction_checks(root.view);
    button_checks(root);
    lock_checks(root);
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
