#import "toolbar-cases.h"

static BOOL near(CGFloat a, CGFloat b)
{
    return fabs(a - b) < 0.5;
}

// The toolbar class a navigation controller is asked to make, which counts the bars it makes: the controller's own `toolbar`
// getter makes one on first use, and a bar that exists is told apart from one that does not only by making it, so the
// count is read without touching the getter.
static int toolbars_made;

@interface CountedToolbar : UIToolbar
@end

@implementation CountedToolbar

- (instancetype)initWithFrame:(CGRect)frame
{
    toolbars_made++;
    return [super initWithFrame:frame];
}

@end

// Every UIToolbar below a view, found through the subview tree. Mac Catalyst keeps a navigation controller's toolbar out of it.
static int toolbars_in(UIView *view)
{
    int found = [view isKindOfClass:[UIToolbar class]] ? 1 : 0;
    for (UIView *subview in view.subviews)
        found += toolbars_in(subview);
    return found;
}

static void settle(UIWindow *window, UINavigationController *navigation, UIViewController *root)
{
    [window layoutIfNeeded];
    [navigation.view layoutIfNeeded];
    [root.view setNeedsLayout];
    [root.view layoutIfNeeded];
}

// How much of the bottom of `view` the toolbar covers, from its own frame; zero when the system keeps it out of the tree.
static CGFloat toolbar_cover(UIView *view, UIToolbar *bar)
{
    if (!bar.superview || bar.hidden || bar.alpha <= 0)
        return 0;
    CGRect covered = CGRectIntersection(view.bounds, [view convertRect:bar.bounds fromView:bar]);
    return CGRectIsNull(covered) ? 0 : CGRectGetHeight(covered);
}

void toolbar_run(UIWindow *window, ToolbarRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithNavigationBarClass:nil toolbarClass:[CountedToolbar class]];
    navigation.viewControllers = @[root];
    record(@"beforeWindow", [NSString stringWithFormat:@"hidden=%d made=%d", navigation.toolbarHidden, toolbars_made]);
    window.rootViewController = navigation;
    settle(window, navigation, root);
    UIEdgeInsets insets = root.view.safeAreaInsets;
    UIView *inner = [[UIView alloc] initWithFrame:CGRectMake(10, 30, 100, 100)];
    [root.view addSubview:inner];
    [inner layoutIfNeeded];
    UIEdgeInsets innerInsets = inner.safeAreaInsets;
    settle(window, navigation, root);
    record(@"neverAsked", [NSString stringWithFormat:@"made=%d inTree=%d", toolbars_made, toolbars_in(navigation.view)]);
    record(@"neverAskedFlag", [NSString stringWithFormat:@"hidden=%d made=%d", navigation.toolbarHidden, toolbars_made]);
    record(@"neverAskedInsets", [NSString stringWithFormat:@"bottom=%d innerBottom=%d", near(insets.bottom, 0), near(innerInsets.bottom, 0)]);

    // A translucent toolbar the view extends under: what it covers is what the safe area has to answer.
    root.wantsFullScreenLayout = YES;
    [navigation setToolbarHidden:NO animated:NO];
    UIToolbar *bar = navigation.toolbar;
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = YES;
    settle(window, navigation, root);
    insets = root.view.safeAreaInsets;
    innerInsets = inner.safeAreaInsets;
    CGFloat cover = toolbar_cover(root.view, bar);
    CGFloat innerCover = MAX(0, cover - (CGRectGetHeight(root.view.bounds) - CGRectGetMaxY(inner.frame)));
    record(@"shown", [NSString stringWithFormat:@"made=%d hidden=%d bottomIsCover=%d innerBottomIsCover=%d", toolbars_made, navigation.toolbarHidden, near(insets.bottom, cover), near(innerInsets.bottom, innerCover)]);
    record(@"measuredShown", [NSString stringWithFormat:@"cover=%d bottom=%d", (int)cover, (int)insets.bottom]);

    [navigation setToolbarHidden:YES animated:NO];
    settle(window, navigation, root);
    insets = root.view.safeAreaInsets;
    cover = toolbar_cover(root.view, bar);
    record(@"hiddenAgain", [NSString stringWithFormat:@"made=%d hidden=%d bottomIsCover=%d", toolbars_made, navigation.toolbarHidden, near(insets.bottom, cover)]);
    record(@"measuredHiddenAgain", [NSString stringWithFormat:@"cover=%d bottom=%d", (int)cover, (int)insets.bottom]);
}
