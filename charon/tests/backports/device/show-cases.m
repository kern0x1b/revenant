#import "show-cases.h"

@interface ShowLeaf : UIViewController
@property (nonatomic, copy) NSString *label;
@end

@implementation ShowLeaf

@synthesize label;

- (NSString *)description
{
    return self.label ?: NSStringFromClass([self class]);
}

@end

@interface ShowOverrider : ShowLeaf
@property (nonatomic, strong) NSMutableArray *shown;
@end

@implementation ShowOverrider

@synthesize shown;

- (void)showViewController:(UIViewController *)controller sender:(id)sender
{
    [self.shown addObject:controller];
}

@end

static ShowLeaf *leaf(NSString *label)
{
    ShowLeaf *controller = [[ShowLeaf alloc] init];
    controller.label = label;
    return controller;
}

static NSString *name(id object)
{
    if (!object)
        return @"nil";
    return [object isKindOfClass:[ShowLeaf class]] ? [object description] : NSStringFromClass([object class]);
}

static void settle(void)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.9]];
}

static UIWindow *fresh(UIWindow *old)
{
    UIWindow *window = nil;
    SEL scene = NSSelectorFromString(@"windowScene");
    if ([old respondsToSelector:scene] && [old performSelector:scene])
        window = [[UIWindow alloc] initWithWindowScene:[old performSelector:scene]];
    else
        window = [[UIWindow alloc] initWithFrame:old.frame];
    window.frame = old.frame;
    old.hidden = YES;
    [window makeKeyAndVisible];
    return window;
}

static void dismiss(NSArray *controllers)
{
    for (UIViewController *controller in controllers) {
        if (controller.presentedViewController) {
            [controller dismissViewControllerAnimated:NO completion:nil];
            settle();
            return;
        }
    }
}

void show_run(UIWindow *window, ShowRecorder record)
{
    ShowLeaf *alone = leaf(@"alone");
    window.rootViewController = alone;
    [window layoutIfNeeded];
    settle();
    ShowLeaf *modal = leaf(@"modal");
    [alone showViewController:modal sender:nil];
    settle();
    record(@"show without a container presents", [NSString stringWithFormat:@"%@", name(alone.presentedViewController)]);
    record(@"target from a plain controller", name([alone targetViewControllerForAction:@selector(showViewController:sender:) sender:nil]));
    dismiss(@[alone]);
    window = fresh(window);

    ShowLeaf *first = leaf(@"first");
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:first];
    window.rootViewController = navigation;
    [window layoutIfNeeded];
    settle();
    ShowLeaf *pushed = leaf(@"pushed");
    [first showViewController:pushed sender:nil];
    settle();
    record(@"show in a navigation controller pushes", [NSString stringWithFormat:@"%lu %@ %@", (unsigned long)navigation.viewControllers.count, name(navigation.topViewController), name(navigation.presentedViewController)]);
    ShowLeaf *child = leaf(@"child");
    [pushed addChildViewController:child];
    [pushed.view addSubview:child.view];
    [child didMoveToParentViewController:pushed];
    [child beginAppearanceTransition:YES animated:NO];
    [child endAppearanceTransition];
    ShowLeaf *fromChild = leaf(@"from child");
    [child showViewController:fromChild sender:nil];
    settle();
    record(@"show from a child pushes on the navigation controller", [NSString stringWithFormat:@"%lu %@", (unsigned long)navigation.viewControllers.count, name(navigation.topViewController)]);
    record(@"target for show from a child", name([child targetViewControllerForAction:@selector(showViewController:sender:) sender:nil]));
    record(@"target for show from the top", name([fromChild targetViewControllerForAction:@selector(showViewController:sender:) sender:nil]));
    record(@"target for show from the navigation controller", name([navigation targetViewControllerForAction:@selector(showViewController:sender:) sender:nil]));
    record(@"target for another action", name([child targetViewControllerForAction:@selector(showDetailViewController:sender:) sender:nil]));
    record(@"target for an action nobody has", name([child targetViewControllerForAction:@selector(charonNobodyHas:) sender:nil]));
    record(@"responder target for show", name([child targetForAction:@selector(showViewController:sender:) withSender:nil]));
    record(@"responder target for an action nobody has", name([child targetForAction:@selector(charonNobodyHas:) withSender:nil]));
    ShowLeaf *detail = leaf(@"detail");
    [child showDetailViewController:detail sender:nil];
    settle();
    record(@"show detail without a split view presents", [NSString stringWithFormat:@"%@ | %lu", name(child.presentedViewController ?: pushed.presentedViewController ?: navigation.presentedViewController), (unsigned long)navigation.viewControllers.count]);
    dismiss(@[navigation]);
    window = fresh(window);

    ShowOverrider *overrider = [[ShowOverrider alloc] init];
    overrider.label = @"overrider";
    overrider.shown = [NSMutableArray array];
    ShowLeaf *inside = leaf(@"inside");
    [overrider addChildViewController:inside];
    [overrider.view addSubview:inside.view];
    [inside didMoveToParentViewController:overrider];
    [inside beginAppearanceTransition:YES animated:NO];
    [inside endAppearanceTransition];
    window.rootViewController = overrider;
    [window layoutIfNeeded];
    settle();
    ShowLeaf *asked = leaf(@"asked");
    [inside showViewController:asked sender:nil];
    settle();
    record(@"show reaches an overriding parent", [NSString stringWithFormat:@"%@ | %@", name(overrider.shown.firstObject), name(overrider.presentedViewController)]);
    record(@"target is the overriding parent", name([inside targetViewControllerForAction:@selector(showViewController:sender:) sender:nil]));

    UITabBarController *tabs = [[UITabBarController alloc] init];
    ShowLeaf *tab = leaf(@"tab");
    tabs.viewControllers = @[tab];
    window.rootViewController = tabs;
    [window layoutIfNeeded];
    settle();
    [tab showViewController:leaf(@"from tab") sender:nil];
    settle();
    record(@"show in a tab presents", name(tab.presentedViewController ?: tabs.presentedViewController));
    record(@"target from a tab", name([tab targetViewControllerForAction:@selector(showViewController:sender:) sender:nil]));
    dismiss(@[tabs]);
}
