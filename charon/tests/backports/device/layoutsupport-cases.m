#import "layoutsupport-cases.h"

void layoutsupport_run(UIWindow *window, LayoutSupportRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    [window layoutIfNeeded];
    id<UILayoutSupport> top = root.topLayoutGuide;
    id<UILayoutSupport> bottom = root.bottomLayoutGuide;
    record(@"top exists", [NSString stringWithFormat:@"%d", top != nil]);
    record(@"bottom exists", [NSString stringWithFormat:@"%d", bottom != nil]);
    record(@"top is stable", [NSString stringWithFormat:@"%d", root.topLayoutGuide == top]);
    record(@"bottom is stable", [NSString stringWithFormat:@"%d", root.bottomLayoutGuide == bottom]);
    record(@"top differs from bottom", [NSString stringWithFormat:@"%d", (id)top != (id)bottom]);
    record(@"top conforms", [NSString stringWithFormat:@"%d", [(id)top conformsToProtocol:@protocol(UILayoutSupport)]]);
    record(@"bottom conforms", [NSString stringWithFormat:@"%d", [(id)bottom conformsToProtocol:@protocol(UILayoutSupport)]]);
    record(@"top length", [NSString stringWithFormat:@"%g", top.length]);
    record(@"bottom length", [NSString stringWithFormat:@"%g", bottom.length]);
    record(@"top anchors", [NSString stringWithFormat:@"%d %d %d", top.topAnchor != nil, top.bottomAnchor != nil, top.heightAnchor != nil]);
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [root.view addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:root.view.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:root.view.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:top.bottomAnchor],
        [content.bottomAnchor constraintEqualToAnchor:bottom.topAnchor]
    ]];
    [root.view layoutIfNeeded];
    record(@"content fills the view between the guides", [NSString stringWithFormat:@"%d", CGRectEqualToRect(content.frame, root.view.bounds)]);
    record(@"content top matches the length", [NSString stringWithFormat:@"%d", fabs(content.frame.origin.y - top.length) < 0.01]);
    record(@"top guide height", [NSString stringWithFormat:@"%g", [(UILayoutGuide *)top layoutFrame].size.height]);
}
