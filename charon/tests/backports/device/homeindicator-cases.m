#import "homeindicator-cases.h"

@interface CountingController : UIViewController
@property (nonatomic) int homeRequests;
@property (nonatomic) int edgeRequests;
@property (nonatomic) BOOL callsSuper;
@end

@implementation CountingController

- (void)setNeedsUpdateOfHomeIndicatorAutoHidden
{
    self.homeRequests++;
    if (self.callsSuper)
        [super setNeedsUpdateOfHomeIndicatorAutoHidden];
}

- (void)setNeedsUpdateOfScreenEdgesDeferringSystemGestures
{
    self.edgeRequests++;
    if (self.callsSuper)
        [super setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
}

@end

@interface HidingController : UIViewController
@end

@implementation HidingController

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return YES;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeBottom | UIRectEdgeLeft;
}

@end

@interface SuperCallingController : UIViewController
@end

@implementation SuperCallingController

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return ![super prefersHomeIndicatorAutoHidden];
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return [super preferredScreenEdgesDeferringSystemGestures] | UIRectEdgeTop;
}

@end

static NSString *counts(CountingController *controller)
{
    return [NSString stringWithFormat:@"%d/%d", controller.homeRequests, controller.edgeRequests];
}

void homeindicator_run(UIWindow *window, HomeIndicatorRecorder record)
{
    UIViewController *plain = [[UIViewController alloc] init];
    record(@"plain", [NSString stringWithFormat:@"%d %lu %d %d", plain.prefersHomeIndicatorAutoHidden, (unsigned long)plain.preferredScreenEdgesDeferringSystemGestures,
                      plain.childViewControllerForHomeIndicatorAutoHidden == nil, plain.childViewControllerForScreenEdgesDeferringSystemGestures == nil]);

    HidingController *hiding = [[HidingController alloc] init];
    record(@"override", [NSString stringWithFormat:@"%d %lu", hiding.prefersHomeIndicatorAutoHidden, (unsigned long)hiding.preferredScreenEdgesDeferringSystemGestures]);
    SuperCallingController *calling = [[SuperCallingController alloc] init];
    record(@"super", [NSString stringWithFormat:@"%d %lu", calling.prefersHomeIndicatorAutoHidden, (unsigned long)calling.preferredScreenEdgesDeferringSystemGestures]);

    UIViewController *root = [[UIViewController alloc] init];
    UIViewController *top = [[UIViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    [navigation pushViewController:top animated:NO];
    record(@"navigation", [NSString stringWithFormat:@"%d %d %d", navigation.childViewControllerForHomeIndicatorAutoHidden == top,
                           navigation.childViewControllerForHomeIndicatorAutoHidden == root, navigation.prefersHomeIndicatorAutoHidden]);
    UINavigationController *empty = [[UINavigationController alloc] init];
    record(@"navigation.empty", [NSString stringWithFormat:@"%d", empty.childViewControllerForHomeIndicatorAutoHidden == nil]);

    UIViewController *first = [[UIViewController alloc] init];
    UIViewController *second = [[UIViewController alloc] init];
    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[first, second];
    tabs.selectedIndex = 1;
    record(@"tabs", [NSString stringWithFormat:@"%d %d %d", tabs.childViewControllerForHomeIndicatorAutoHidden == second,
                     tabs.childViewControllerForScreenEdgesDeferringSystemGestures == second, tabs.childViewControllerForHomeIndicatorAutoHidden == first]);
    UITabBarController *bare = [[UITabBarController alloc] init];
    record(@"tabs.empty", [NSString stringWithFormat:@"%d", bare.childViewControllerForHomeIndicatorAutoHidden == nil]);

    CountingController *grand = [[CountingController alloc] init];
    CountingController *parent = [[CountingController alloc] init];
    CountingController *child = [[CountingController alloc] init];
    [grand addChildViewController:parent];
    [parent addChildViewController:child];
    [child setNeedsUpdateOfHomeIndicatorAutoHidden];
    record(@"chain.stops", [NSString stringWithFormat:@"%@ %@ %@", counts(child), counts(parent), counts(grand)]);
    child.callsSuper = YES;
    parent.callsSuper = YES;
    [child setNeedsUpdateOfHomeIndicatorAutoHidden];
    [child setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
    record(@"chain.goes", [NSString stringWithFormat:@"%@ %@ %@", counts(child), counts(parent), counts(grand)]);
    [grand setNeedsUpdateOfHomeIndicatorAutoHidden];
    record(@"root", counts(grand));
    UIViewController *alone = [[UIViewController alloc] init];
    [alone setNeedsUpdateOfHomeIndicatorAutoHidden];
    [alone setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
    record(@"alone", @"survived");

    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    record(@"bar.defaults", [NSString stringWithFormat:@"%d %d", bar.prefersLargeTitles, bar.largeTitleTextAttributes == nil]);
    bar.prefersLargeTitles = YES;
    record(@"bar.set", [NSString stringWithFormat:@"%d", bar.prefersLargeTitles]);
    bar.prefersLargeTitles = NO;
    record(@"bar.unset", [NSString stringWithFormat:@"%d", bar.prefersLargeTitles]);
    NSMutableDictionary *attributes = [@{ NSForegroundColorAttributeName: [UIColor redColor] } mutableCopy];
    bar.largeTitleTextAttributes = attributes;
    attributes[NSFontAttributeName] = [UIFont systemFontOfSize:20];
    record(@"bar.attributes", [NSString stringWithFormat:@"%lu %d", (unsigned long)bar.largeTitleTextAttributes.count, [bar.largeTitleTextAttributes isKindOfClass:[NSMutableDictionary class]]]);
    bar.largeTitleTextAttributes = nil;
    record(@"bar.attributes.nil", [NSString stringWithFormat:@"%d", bar.largeTitleTextAttributes == nil]);
    bar.prefersLargeTitles = YES;
    bar.largeTitleTextAttributes = @{ NSForegroundColorAttributeName: [UIColor blueColor] };
    record(@"bar.independent", [NSString stringWithFormat:@"%d %lu", bar.prefersLargeTitles, (unsigned long)bar.largeTitleTextAttributes.count]);
    bar.prefersLargeTitles = NO;
    bar.largeTitleTextAttributes = nil;
    UINavigationBar *other = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    other.prefersLargeTitles = YES;
    record(@"bar.separate", [NSString stringWithFormat:@"%d %d", bar.prefersLargeTitles, other.prefersLargeTitles]);

    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Title"];
    record(@"item.default", [NSString stringWithFormat:@"%ld", (long)item.largeTitleDisplayMode]);
    NSMutableArray *modes = [NSMutableArray array];
    for (NSInteger mode = 0; mode < 3; mode++) {
        item.largeTitleDisplayMode = (UINavigationItemLargeTitleDisplayMode)mode;
        [modes addObject:@(item.largeTitleDisplayMode)];
    }
    record(@"item.modes", [modes componentsJoinedByString:@","]);
    UINavigationItem *another = [[UINavigationItem alloc] initWithTitle:@"Other"];
    record(@"item.separate", [NSString stringWithFormat:@"%ld %ld", (long)item.largeTitleDisplayMode, (long)another.largeTitleDisplayMode]);
    record(@"values", [NSString stringWithFormat:@"%ld %ld %ld", (long)UINavigationItemLargeTitleDisplayModeAutomatic, (long)UINavigationItemLargeTitleDisplayModeAlways, (long)UINavigationItemLargeTitleDisplayModeNever]);
    root.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    record(@"item.controller", [NSString stringWithFormat:@"%ld", (long)root.navigationItem.largeTitleDisplayMode]);
}
