#import "safeguide-cases.h"

static BOOL near(CGFloat a, CGFloat b)
{
    return fabs(a - b) < 0.5;
}

static NSString *guide_relation(UIView *view, UILayoutGuide *guide)
{
    [view.superview layoutIfNeeded];
    [view layoutIfNeeded];
    UIEdgeInsets insets = view.safeAreaInsets;
    CGRect expected = UIEdgeInsetsInsetRect(view.bounds, insets);
    CGRect frame = guide.layoutFrame;
    BOOL same = near(frame.origin.x, expected.origin.x) && near(frame.origin.y, expected.origin.y) && near(frame.size.width, expected.size.width) && near(frame.size.height, expected.size.height);
    return [NSString stringWithFormat:@"guideIsInsetBounds=%d", same];
}

void safeguide_run(UIWindow *window, SafeGuideRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    window.rootViewController = navigation;
    [window layoutIfNeeded];
    UIView *view = root.view;
    UILayoutGuide *guide = view.safeAreaLayoutGuide;
    record(@"identity", [NSString stringWithFormat:@"same=%d owning=%d class=%d", guide == view.safeAreaLayoutGuide, guide.owningView == view, [guide isKindOfClass:[UILayoutGuide class]]]);
    record(@"controllerView", guide_relation(view, guide));

    UIView *sub = [[UIView alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:sub];
    [NSLayoutConstraint activateConstraints:@[
        [sub.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [sub.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [sub.heightAnchor constraintEqualToConstant:20]
    ]];
    [view layoutIfNeeded];
    UIEdgeInsets insets = view.safeAreaInsets;
    record(@"pinned", [NSString stringWithFormat:@"top=%d left=%d width=%d", near(sub.frame.origin.y, insets.top), near(sub.frame.origin.x, insets.left), near(sub.frame.size.width, view.bounds.size.width - insets.left - insets.right)]);

    [navigation setNavigationBarHidden:YES animated:NO];
    [window layoutIfNeeded];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    insets = view.safeAreaInsets;
    record(@"barHidden", [NSString stringWithFormat:@"%@ subTop=%d", guide_relation(view, guide), near(sub.frame.origin.y, insets.top)]);
    [navigation setNavigationBarHidden:NO animated:NO];
    [window layoutIfNeeded];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    insets = view.safeAreaInsets;
    record(@"barShown", [NSString stringWithFormat:@"%@ subTop=%d", guide_relation(view, guide), near(sub.frame.origin.y, insets.top)]);

    UIView *inner = [[UIView alloc] initWithFrame:CGRectMake(10, 30, 100, 100)];
    [view addSubview:inner];
    UILayoutGuide *innerGuide = inner.safeAreaLayoutGuide;
    [inner layoutIfNeeded];
    record(@"innerView", guide_relation(inner, innerGuide));

    UIView *loose = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    UILayoutGuide *looseGuide = loose.safeAreaLayoutGuide;
    [loose layoutIfNeeded];
    record(@"outsideWindow", [NSString stringWithFormat:@"%@ owning=%d", guide_relation(loose, looseGuide), looseGuide.owningView == loose]);

    UIViewController *tabbed = [[UIViewController alloc] init];
    UINavigationController *inner_navigation = [[UINavigationController alloc] initWithRootViewController:tabbed];
    UIViewController *other = [[UIViewController alloc] init];
    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[inner_navigation, other];
    window.rootViewController = tabs;
    [window layoutIfNeeded];
    UILayoutGuide *tabbedGuide = tabbed.view.safeAreaLayoutGuide;
    record(@"tabBar", guide_relation(tabbed.view, tabbedGuide));
    UIView *tabPinned = [[UIView alloc] init];
    tabPinned.translatesAutoresizingMaskIntoConstraints = NO;
    [tabbed.view addSubview:tabPinned];
    [NSLayoutConstraint activateConstraints:@[
        [tabPinned.bottomAnchor constraintEqualToAnchor:tabbedGuide.bottomAnchor],
        [tabPinned.leadingAnchor constraintEqualToAnchor:tabbedGuide.leadingAnchor],
        [tabPinned.widthAnchor constraintEqualToConstant:30],
        [tabPinned.heightAnchor constraintEqualToConstant:10]
    ]];
    [tabbed.view layoutIfNeeded];
    UIEdgeInsets tabInsets = tabbed.view.safeAreaInsets;
    record(@"tabPinned", [NSString stringWithFormat:@"bottom=%d", near(CGRectGetMaxY(tabPinned.frame), tabbed.view.bounds.size.height - tabInsets.bottom)]);
    tabbed.hidesBottomBarWhenPushed = NO;
    [inner_navigation setNavigationBarHidden:YES animated:NO];
    [window layoutIfNeeded];
    [tabbed.view setNeedsLayout];
    [tabbed.view layoutIfNeeded];
    record(@"tabNoBar", guide_relation(tabbed.view, tabbedGuide));
}
