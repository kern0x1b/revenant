#import "scrollguide-cases.h"

static BOOL near(CGFloat a, CGFloat b)
{
    return fabs(a - b) < 0.5;
}

static NSString *text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.0f,%.0f,%.0f,%.0f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

void scrollguide_run(UIWindow *window, ScrollGuideRecorder record)
{
    UIViewController *controller = [[UIViewController alloc] init];
    window.rootViewController = controller;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    [controller.view addSubview:scroll];
    UILayoutGuide *contentGuide = scroll.contentLayoutGuide;
    UILayoutGuide *frameGuide = scroll.frameLayoutGuide;
    record(@"identity", [NSString stringWithFormat:@"content=%d frame=%d ownerContent=%d ownerFrame=%d different=%d", contentGuide == scroll.contentLayoutGuide, frameGuide == scroll.frameLayoutGuide, contentGuide.owningView == scroll, frameGuide.owningView == scroll, contentGuide != frameGuide]);

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToConstant:200],
        [content.heightAnchor constraintEqualToConstant:900]
    ]];
    UIView *wide = [[UIView alloc] init];
    wide.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:wide];
    [NSLayoutConstraint activateConstraints:@[
        [wide.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor],
        [wide.heightAnchor constraintEqualToAnchor:frameGuide.heightAnchor multiplier:0.5],
        [wide.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [wide.topAnchor constraintEqualToAnchor:contentGuide.topAnchor]
    ]];
    [controller.view layoutIfNeeded];
    [scroll layoutIfNeeded];
    record(@"contentSize", [NSString stringWithFormat:@"size=%@ guide=%@", NSStringFromCGSize(scroll.contentSize), text(contentGuide.layoutFrame)]);
    record(@"frameGuideSize", [NSString stringWithFormat:@"%.0f,%.0f wide=%@", frameGuide.layoutFrame.size.width, frameGuide.layoutFrame.size.height, NSStringFromCGSize(wide.frame.size)]);

    scroll.contentOffset = CGPointMake(0, 250);
    [scroll layoutIfNeeded];
    [scroll setNeedsLayout];
    [scroll layoutIfNeeded];
    record(@"scrolled", [NSString stringWithFormat:@"offset=%@ size=%@ frameGuide=%.0f,%.0f", NSStringFromCGPoint(scroll.contentOffset), NSStringFromCGSize(scroll.contentSize), frameGuide.layoutFrame.size.width, frameGuide.layoutFrame.size.height]);

    scroll.frame = CGRectMake(0, 0, 180, 250);
    [controller.view layoutIfNeeded];
    [scroll setNeedsLayout];
    [scroll layoutIfNeeded];
    record(@"resized", [NSString stringWithFormat:@"%.0f,%.0f wide=%@ contentSize=%@", frameGuide.layoutFrame.size.width, frameGuide.layoutFrame.size.height, NSStringFromCGSize(wide.frame.size), NSStringFromCGSize(scroll.contentSize)]);

    UIScrollView *plain = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    plain.contentSize = CGSizeMake(300, 400);
    [controller.view addSubview:plain];
    UILayoutGuide *plainGuide = plain.contentLayoutGuide;
    [plain layoutIfNeeded];
    record(@"fromContentSize", [NSString stringWithFormat:@"size=%@ guide=%@", NSStringFromCGSize(plain.contentSize), text(plainGuide.layoutFrame)]);
}
