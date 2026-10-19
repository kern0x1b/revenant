#import "uirest.h"

// The overrideUserInterfaceStyle of a controller and of a view, through the trait collection the system answers: what
// a controller and the view under it read as their style, and how many traitCollectionDidChange: calls each override
// makes. The same calls run on the system's classes for the expected answers (darkstyle_system.m) and on the port's
// (darkstyle_test.m), so the two must agree line for line.

@interface DarkStyleController : UIViewController
@property (nonatomic) int changes;
@end

@implementation DarkStyleController

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    self.changes++;
}

@end

@interface DarkStyleView : UIView
@property (nonatomic) int changes;
@end

@implementation DarkStyleView

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    self.changes++;
}

@end

static NSArray *darkstyle_scenario(UIWindow *window)
{
    NSMutableArray *lines = [NSMutableArray array];
    DarkStyleController *root = [[DarkStyleController alloc] init];
    DarkStyleController *child = [[DarkStyleController alloc] init];
    DarkStyleView *inner = [[DarkStyleView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    window.rootViewController = root;
    [root addChildViewController:child];
    [root.view addSubview:child.view];
    [child didMoveToParentViewController:root];
    [child.view addSubview:inner];
    DarkStyleView *grand = [[DarkStyleView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
    [inner addSubview:grand];

    [lines addObject:ur_line(@"unset is not dark", ur_yes(root.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    NSInteger childBefore = child.changes, innerBefore = inner.changes;
    root.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [lines addObject:ur_line(@"root reads dark", ur_yes(root.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    [lines addObject:ur_line(@"child inherits dark", ur_yes(child.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    [lines addObject:ur_line(@"view inherits dark", ur_yes(inner.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    [lines addObject:ur_line(@"dark changes to child", @(child.changes - childBefore))];
    [lines addObject:ur_line(@"dark changes to view", @(inner.changes - innerBefore))];

    innerBefore = inner.changes;
    NSInteger grandBefore = grand.changes;
    inner.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    [lines addObject:ur_line(@"view keeps its own dark", ur_yes(inner.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    [lines addObject:ur_line(@"view under light is light", ur_yes(grand.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight))];
    [lines addObject:ur_line(@"child still dark", ur_yes(child.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    [lines addObject:ur_line(@"light changes to view", @(inner.changes - innerBefore))];
    [lines addObject:ur_line(@"light changes to view under", @(grand.changes - grandBefore))];

    childBefore = child.changes;
    root.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    [lines addObject:ur_line(@"unset child is not dark", ur_yes(child.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))];
    [lines addObject:ur_line(@"view under light stays light", ur_yes(grand.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight))];
    [lines addObject:ur_line(@"unset changes to child", @(child.changes - childBefore))];
    [lines addObject:ur_line(@"read back root", @(root.overrideUserInterfaceStyle))];
    [lines addObject:ur_line(@"read back view", @(inner.overrideUserInterfaceStyle))];
    return lines;
}
