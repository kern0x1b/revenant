#import <UIKit/UIKit.h>
#include <stdio.h>

// A bundled Mac Catalyst app with the iPad idiom and a window. The scene delegate runs the same checks on the host's focus effects and focus
// groups and, in the port's build, on the port's (the effect classes are compiled renamed, and the view and view-controller categories have
// the host's method names, so in that process they replace the host's and the checks read the port's answers). Each check writes one
// "side<TAB>check<TAB>value" line to the file named by CHARON_SCENE_OUT, then the app quits. The focus engine itself is not measured here: no
// halo is drawn and no focus moves, which the port does not build.

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

static NSString *class_named(Class cls)
{
    NSString *name = NSStringFromClass(cls);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *number(NSInteger value)
{
    return [NSString stringWithFormat:@"%ld", (long)value];
}

static void effect_checks(void)
{
    UIFocusEffect *effect = [UIFocusEffect effect];
    report("effect-class", class_name(effect));
    report("effect-superclass", class_named([[effect class] superclass]));
    report("effect-copy-same", yes_no([effect copy] == effect));
    UIFocusHaloEffect *halo = [UIFocusHaloEffect effectWithRect:CGRectMake(0, 0, 40, 40)];
    report("halo-class", class_name(halo));
    report("halo-superclass", class_named([[halo class] superclass]));
    report("halo-is-effect", yes_no([halo isKindOfClass:[UIFocusEffect class]]));
    report("halo-container-default", halo.containerView ? @"set" : @"nil");
    report("halo-reference-default", halo.referenceView ? @"set" : @"nil");
    report("halo-position-default", number(halo.position));
    halo.position = UIFocusHaloEffectPositionOutside;
    report("halo-position-outside", number(halo.position));
    halo.position = UIFocusHaloEffectPositionInside;
    report("halo-position-inside", number(halo.position));
    halo.position = UIFocusHaloEffectPositionAutomatic;
    report("halo-position-automatic", number(halo.position));
    UIView *container = [[UIView alloc] init];
    halo.containerView = container;
    report("halo-container-kept", yes_no(halo.containerView == container));
    report("halo-copy-same", yes_no([halo copy] == halo));
    report("halo-rounded-class", class_name([UIFocusHaloEffect effectWithRoundedRect:CGRectMake(0, 0, 40, 40) cornerRadius:4 curve:(CALayerCornerCurve)@"continuous"]));
    report("halo-path-class", class_name([UIFocusHaloEffect effectWithPath:[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 9, 9)]]));
}

static void view_checks(UIView *view, UIViewController *root)
{
    report("view-effect-default-class", class_name(view.focusEffect));
    report("view-effect-default-same-on-reads", yes_no(view.focusEffect == view.focusEffect));
    UIFocusHaloEffect *halo = [UIFocusHaloEffect effectWithRect:CGRectMake(0, 0, 40, 40)];
    view.focusEffect = halo;
    report("view-effect-set-same", yes_no(view.focusEffect == halo));
    report("view-effect-set-class", class_name(view.focusEffect));
    view.focusEffect = nil;
    report("view-effect-cleared-class", class_name(view.focusEffect));

    report("view-priority-default", number(view.focusGroupPriority));
    view.focusGroupPriority = UIFocusGroupPriorityPrioritized;
    report("view-priority-prioritized", number(view.focusGroupPriority));
    view.focusGroupPriority = UIFocusGroupPriorityPreviouslyFocused;
    report("view-priority-previously", number(view.focusGroupPriority));
    view.focusGroupPriority = 42;
    report("view-priority-42", number(view.focusGroupPriority));
    report("constant-currently-focused", number(UIFocusGroupPriorityCurrentlyFocused));
    report("constant-ignored", number(UIFocusGroupPriorityIgnored));

    report("view-group-default", view.focusGroupIdentifier ?: @"nil");
    view.focusGroupIdentifier = @"group";
    report("view-group-set", view.focusGroupIdentifier ?: @"nil");
    view.focusGroupIdentifier = nil;
    report("view-group-cleared", view.focusGroupIdentifier ?: @"nil");

    report("vc-group-default", root.focusGroupIdentifier ?: @"nil");
    root.focusGroupIdentifier = @"controller";
    report("vc-group-set", root.focusGroupIdentifier ?: @"nil");
    root.focusGroupIdentifier = nil;
    report("vc-group-cleared", root.focusGroupIdentifier ?: @"nil");
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
    effect_checks();
    view_checks(root.view, root);
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
