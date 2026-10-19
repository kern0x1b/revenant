#import "layoutguide-cases.h"

static NSString *frame_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.0f,%.0f,%.0f,%.0f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

void layoutguide_run(UIWindow *window, LayoutGuideRecorder record)
{
    UIViewController *controller = [[UIViewController alloc] init];
    window.rootViewController = controller;
    UIView *parent = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    [controller.view addSubview:parent];

    UILayoutGuide *guide = [[UILayoutGuide alloc] init];
    [parent addLayoutGuide:guide];
    UIView *sub = [[UIView alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:sub];

    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:guide attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:parent attribute:NSLayoutAttributeLeading multiplier:1 constant:10];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:guide attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:parent attribute:NSLayoutAttributeTop multiplier:1 constant:20];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:guide attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:100];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:guide attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:50];
    NSLayoutConstraint *subLeft = [NSLayoutConstraint constraintWithItem:sub attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:guide attribute:NSLayoutAttributeLeading multiplier:1 constant:0];
    NSLayoutConstraint *subTop = [NSLayoutConstraint constraintWithItem:sub attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:guide attribute:NSLayoutAttributeBottom multiplier:1 constant:5];
    NSLayoutConstraint *subWidth = [NSLayoutConstraint constraintWithItem:sub attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:guide attribute:NSLayoutAttributeWidth multiplier:0.5 constant:0];
    NSLayoutConstraint *subHeight = [NSLayoutConstraint constraintWithItem:sub attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:30];
    NSArray *all = @[left, top, width, height, subLeft, subTop, subWidth, subHeight];
    [NSLayoutConstraint activateConstraints:all];
    [parent layoutIfNeeded];
    BOOL allActive = YES;
    for (NSLayoutConstraint *constraint in all)
        allActive = allActive && constraint.isActive;
    record(@"itemsFrames", [NSString stringWithFormat:@"guide=%@ sub=%@ active=%d", frame_text(guide.layoutFrame), frame_text(sub.frame), allActive]);
    record(@"owner", [NSString stringWithFormat:@"owning=%d", guide.owningView == parent]);
    [NSLayoutConstraint deactivateConstraints:all];
    BOOL noneActive = YES;
    for (NSLayoutConstraint *constraint in all)
        noneActive = noneActive && !constraint.isActive;
    record(@"deactivated", [NSString stringWithFormat:@"none=%d", noneActive]);

    UILayoutGuide *loose = [[UILayoutGuide alloc] init];
    NSLayoutConstraint *ownerless = [NSLayoutConstraint constraintWithItem:loose attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:10];
    ownerless.active = YES;
    record(@"ownerless", [NSString stringWithFormat:@"active=%d", ownerless.isActive]);
    [parent addLayoutGuide:loose];
    UIView *other = [[UIView alloc] init];
    other.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:other];
    NSLayoutConstraint *related = [NSLayoutConstraint constraintWithItem:other attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:loose attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
    NSLayoutConstraint *otherHeight = [NSLayoutConstraint constraintWithItem:other attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:7];
    NSLayoutConstraint *looseWidth = [NSLayoutConstraint constraintWithItem:loose attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44];
    [NSLayoutConstraint activateConstraints:@[related, otherHeight, looseWidth]];
    [parent layoutIfNeeded];
    record(@"twoGuideViews", [NSString stringWithFormat:@"width=%.0f height=%.0f", other.frame.size.width, other.frame.size.height]);
}
