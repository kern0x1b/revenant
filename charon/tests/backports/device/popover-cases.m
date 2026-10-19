#import "popover-cases.h"

static NSString *edges(UIEdgeInsets insets)
{
    return [NSString stringWithFormat:@"%g,%g,%g,%g", insets.top, insets.left, insets.bottom, insets.right];
}

void popover_defaults(UIWindow *window, PopoverRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    [window layoutIfNeeded];
    UIViewController *content = [[UIViewController alloc] init];
    record(@"none before the style", [NSString stringWithFormat:@"%d", content.popoverPresentationController == nil]);
    content.modalPresentationStyle = UIModalPresentationPopover;
    record(@"style value", [NSString stringWithFormat:@"%ld", (long)content.modalPresentationStyle]);
    UIPopoverPresentationController *pc = content.popoverPresentationController;
    record(@"exists with the style", [NSString stringWithFormat:@"%d", pc != nil]);
    record(@"same object again", [NSString stringWithFormat:@"%d", content.popoverPresentationController == pc]);
    record(@"is a presentation controller", [NSString stringWithFormat:@"%d", [pc isKindOfClass:[UIPresentationController class]]]);
    record(@"presentation controller of the controller", [NSString stringWithFormat:@"%d", content.presentationController == pc]);
    record(@"presented controller", [NSString stringWithFormat:@"%d", pc.presentedViewController == content]);
    record(@"presenting controller before", [NSString stringWithFormat:@"%d", pc.presentingViewController == nil]);
    record(@"permitted arrow directions", [NSString stringWithFormat:@"%lu", (unsigned long)pc.permittedArrowDirections]);
    record(@"source view", [NSString stringWithFormat:@"%d", pc.sourceView == nil]);
    record(@"source rect", NSStringFromCGRect(pc.sourceRect));
    record(@"bar button item", [NSString stringWithFormat:@"%d", pc.barButtonItem == nil]);
    record(@"arrow direction", [NSString stringWithFormat:@"%d", pc.arrowDirection == UIPopoverArrowDirectionUnknown]);
    record(@"passthrough views", [NSString stringWithFormat:@"%d", pc.passthroughViews == nil]);
    record(@"background color", [NSString stringWithFormat:@"%d", pc.backgroundColor == nil]);
    record(@"layout margins", edges(pc.popoverLayoutMargins));
    record(@"background view class", [NSString stringWithFormat:@"%d", pc.popoverBackgroundViewClass == nil]);
    record(@"delegate", [NSString stringWithFormat:@"%d", pc.delegate == nil]);
    record(@"container view", [NSString stringWithFormat:@"%d", pc.containerView == nil]);
    record(@"presentation style", [NSString stringWithFormat:@"%ld", (long)pc.presentationStyle]);
    pc.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
    pc.sourceRect = CGRectMake(1, 2, 3, 4);
    pc.popoverLayoutMargins = UIEdgeInsetsMake(5, 6, 7, 8);
    UIView *view = [[UIView alloc] init];
    pc.sourceView = view;
    pc.passthroughViews = @[view];
    record(@"stored directions", [NSString stringWithFormat:@"%lu", (unsigned long)pc.permittedArrowDirections]);
    record(@"stored rect", NSStringFromCGRect(pc.sourceRect));
    record(@"stored margins", edges(pc.popoverLayoutMargins));
    record(@"stored source view", [NSString stringWithFormat:@"%d", pc.sourceView == view]);
    record(@"stored passthrough", [NSString stringWithFormat:@"%d", pc.passthroughViews.firstObject == view]);
    UIViewController *other = [[UIViewController alloc] init];
    record(@"none for a full screen controller", [NSString stringWithFormat:@"%d", other.popoverPresentationController == nil]);
    other.modalPresentationStyle = UIModalPresentationFormSheet;
    record(@"none for a form sheet", [NSString stringWithFormat:@"%d", other.popoverPresentationController == nil]);
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[[UIViewController alloc] init]];
    navigation.modalPresentationStyle = UIModalPresentationPopover;
    record(@"navigation controller", [NSString stringWithFormat:@"%d", navigation.popoverPresentationController != nil]);
}
