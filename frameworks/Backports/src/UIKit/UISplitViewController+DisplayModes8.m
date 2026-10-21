#import "RevenantSplit.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

CGFloat const UISplitViewControllerAutomaticDimension = -1;

static const char RevenantSplitStateKey;
static const CGFloat RevenantSplitDefaultFraction = 0.38f;
static const CGFloat RevenantSplitDefaultWidth = 320;

static void (*revenant_native_set_delegate)(id, SEL, id);

@interface UISplitViewController (RevenantNativeColumn)
- (void)setMasterColumnWidth:(CGFloat)width;
@end

@interface UISplitViewController (RevenantDisplayModeAction)
- (void)revenant_displayModeButtonTapped:(id)sender;
@end

@interface RevenantSplitProxy : NSObject <UISplitViewControllerDelegate> {
@public
    __weak UISplitViewController *split;
}
@end

@implementation RevenantSplitState
@end

BOOL revenant_split_on_phone(void)
{
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
}

RevenantSplitState *revenant_split_state(UISplitViewController *split)
{
    RevenantSplitState *state = objc_getAssociatedObject(split, &RevenantSplitStateKey);
    if (!state) {
        state = [[RevenantSplitState alloc] init];
        state->preferred = UISplitViewControllerDisplayModeAutomatic;
        state->notified = -1;
        state->fraction = state->minimum = state->maximum = UISplitViewControllerAutomaticDimension;
        state->preferredWidth = state->supplementaryFraction = state->supplementaryWidth = UISplitViewControllerAutomaticDimension;
        state->supplementaryMinimum = state->supplementaryMaximum = UISplitViewControllerAutomaticDimension;
        RevenantSplitProxy *proxy = [[RevenantSplitProxy alloc] init];
        proxy->split = split;
        state->proxy = proxy;
        objc_setAssociatedObject(split, &RevenantSplitStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

BOOL revenant_split_collapsed(UISplitViewController *split)
{
    return split.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
}

static void revenant_install_proxy(UISplitViewController *split)
{
    RevenantSplitState *state = revenant_split_state(split);
    if (revenant_split_on_phone() || !revenant_native_set_delegate)
        return;
    state->proxyInstalled = YES;
    revenant_native_set_delegate(split, @selector(setDelegate:), state->proxy);
}

static CGFloat revenant_split_width(UISplitViewController *split)
{
    RevenantSplitState *state = revenant_split_state(split);
    CGFloat total = split.isViewLoaded ? split.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    if (state->preferredWidth != UISplitViewControllerAutomaticDimension) {
        CGFloat floor = state->minimum != UISplitViewControllerAutomaticDimension ? state->minimum : 0;
        CGFloat ceiling = state->maximum != UISplitViewControllerAutomaticDimension ? state->maximum : CGFLOAT_MAX;
        return MIN(MAX(state->preferredWidth, floor), MAX(ceiling, floor));
    }
    CGFloat base = (state->fraction != UISplitViewControllerAutomaticDimension ? state->fraction : RevenantSplitDefaultFraction) * total;
    CGFloat low = state->minimum != UISplitViewControllerAutomaticDimension ? state->minimum : RevenantSplitDefaultWidth;
    CGFloat high = state->maximum != UISplitViewControllerAutomaticDimension ? state->maximum : MAX(RevenantSplitDefaultWidth, low);
    high = MAX(high, low);
    return MIN(MAX(base, low), high);
}

void revenant_split_apply_width(UISplitViewController *split)
{
    if (!revenant_split_on_phone() && [split respondsToSelector:@selector(setMasterColumnWidth:)])
        [split setMasterColumnWidth:revenant_split_width(split)];
}

static UIImage *revenant_split_glyph(BOOL fullscreen)
{
    static UIImage *glyphs[2];
    if (glyphs[fullscreen])
        return glyphs[fullscreen];
    CGSize size = CGSizeMake(22, 22);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 2);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    if (fullscreen) {
        CGContextMoveToPoint(context, 4, 8);
        CGContextAddLineToPoint(context, 4, 4);
        CGContextAddLineToPoint(context, 8, 4);
        CGContextMoveToPoint(context, 4, 4);
        CGContextAddLineToPoint(context, 9, 9);
        CGContextMoveToPoint(context, 18, 14);
        CGContextAddLineToPoint(context, 18, 18);
        CGContextAddLineToPoint(context, 14, 18);
        CGContextMoveToPoint(context, 18, 18);
        CGContextAddLineToPoint(context, 13, 13);
    } else {
        CGContextMoveToPoint(context, 13, 4);
        CGContextAddLineToPoint(context, 6, 11);
        CGContextAddLineToPoint(context, 13, 18);
    }
    CGContextStrokePath(context);
    glyphs[fullscreen] = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return glyphs[fullscreen];
}

UISplitViewControllerDisplayMode revenant_split_resolve(UISplitViewController *split)
{
    if (revenant_split_collapsed(split))
        return UISplitViewControllerDisplayModeSecondaryOnly;
    RevenantSplitState *state = revenant_split_state(split);
    UIViewController *primary = split.viewControllers.firstObject;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    BOOL hidden = [(RevenantSplitProxy *)state->proxy splitViewController:split shouldHideViewController:primary inOrientation:orientation];
    if (!hidden)
        return UISplitViewControllerDisplayModeOneBesideSecondary;
    return state->popover.popoverVisible ? UISplitViewControllerDisplayModeOneOverSecondary : UISplitViewControllerDisplayModeSecondaryOnly;
}

static UISplitViewControllerDisplayMode revenant_split_target(UISplitViewController *split, UISplitViewControllerDisplayMode current)
{
    id delegate =revenant_split_state(split)->appDelegate;
    if ([delegate respondsToSelector:@selector(targetDisplayModeForActionInSplitViewController:)]) {
        UISplitViewControllerDisplayMode requested = [delegate targetDisplayModeForActionInSplitViewController:split];
        if (requested != UISplitViewControllerDisplayModeAutomatic)
            return requested;
    }
    return current == UISplitViewControllerDisplayModeSecondaryOnly ? UISplitViewControllerDisplayModeOneOverSecondary : UISplitViewControllerDisplayModeSecondaryOnly;
}

static void revenant_update_button(UISplitViewController *split)
{
    RevenantSplitState *state = revenant_split_state(split);
    UIBarButtonItem *button = state->button;
    if (!button)
        return;
    UISplitViewControllerDisplayMode current = revenant_split_resolve(split);
    UISplitViewControllerDisplayMode target = revenant_split_target(split, current);
    BOOL active = !revenant_split_collapsed(split) && target != current && state->visibility != UISplitViewControllerDisplayModeButtonVisibilityNever;
    button.enabled = active;
    button.image = active ? revenant_split_glyph(target == UISplitViewControllerDisplayModeSecondaryOnly) : nil;
    if (state->nativeButton) {
        button.target = state->nativeButton.target;
        button.action = state->nativeButton.action;
    }
}

static void revenant_notify_mode(UISplitViewController *split, UISplitViewControllerDisplayMode mode)
{
    RevenantSplitState *state = revenant_split_state(split);
    if (state->notified == (NSInteger)mode)
        return;
    state->notified = mode;
    id delegate =state->appDelegate;
    if ([delegate respondsToSelector:@selector(splitViewController:willChangeToDisplayMode:)])
        [delegate splitViewController:split willChangeToDisplayMode:mode];
    revenant_update_button(split);
}

@implementation RevenantSplitProxy

- (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    RevenantSplitState *state = revenant_split_state(svc);
    switch (state->preferred) {
    case UISplitViewControllerDisplayModeSecondaryOnly:
    case UISplitViewControllerDisplayModeOneOverSecondary:
        return YES;
    case UISplitViewControllerDisplayModeOneBesideSecondary:
        return NO;
    default:
        break;
    }
    id delegate =state->appDelegate;
    if ([delegate respondsToSelector:_cmd])
        return [delegate splitViewController:svc shouldHideViewController:vc inOrientation:orientation];
    return UIInterfaceOrientationIsPortrait(orientation);
}

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
    RevenantSplitState *state = revenant_split_state(svc);
    state->nativeButton = barButtonItem;
    state->popover = pc;
    id delegate =state->appDelegate;
    if ([delegate respondsToSelector:_cmd])
        [delegate splitViewController:svc willHideViewController:aViewController withBarButtonItem:barButtonItem forPopoverController:pc];
    revenant_notify_mode(svc, UISplitViewControllerDisplayModeSecondaryOnly);
    revenant_update_button(svc);
}

- (void)splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    RevenantSplitState *state = revenant_split_state(svc);
    id delegate =state->appDelegate;
    if ([delegate respondsToSelector:_cmd])
        [delegate splitViewController:svc willShowViewController:aViewController invalidatingBarButtonItem:barButtonItem];
    state->nativeButton = nil;
    state->popover = nil;
    revenant_notify_mode(svc, UISplitViewControllerDisplayModeOneBesideSecondary);
    revenant_update_button(svc);
}

- (void)splitViewController:(UISplitViewController *)svc popoverController:(UIPopoverController *)pc willPresentViewController:(UIViewController *)aViewController
{
    RevenantSplitState *state = revenant_split_state(svc);
    state->popover = pc;
    id delegate =state->appDelegate;
    if ([delegate respondsToSelector:_cmd])
        [delegate splitViewController:svc popoverController:pc willPresentViewController:aViewController];
    revenant_notify_mode(svc, UISplitViewControllerDisplayModeOneOverSecondary);
    revenant_update_button(svc);
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [revenant_split_state(split)->appDelegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    id delegate = revenant_split_state(split)->appDelegate;
    return [delegate respondsToSelector:selector] ? delegate : [super forwardingTargetForSelector:selector];
}

@end

@interface RevenantSplitInstaller : NSObject
@end

@implementation RevenantSplitInstaller

+ (void)load
{
    if ([UISplitViewController instancesRespondToSelector:@selector(preferredDisplayMode)])
        return;
    Class split = [UISplitViewController class];
    Method set = class_getInstanceMethod(split, @selector(setDelegate:));
    Method get = class_getInstanceMethod(split, @selector(delegate));
    if (!set || !get)
        return;
    revenant_native_set_delegate = (void (*)(id, SEL, id))method_getImplementation(set);
    method_setImplementation(set, imp_implementationWithBlock(^(UISplitViewController *controller, id delegate) {
        RevenantSplitState *state = revenant_split_state(controller);
        state->appDelegate = delegate;
        revenant_install_proxy(controller);
    }));
    method_setImplementation(get, imp_implementationWithBlock(^id(UISplitViewController *controller) {
        return revenant_split_state(controller)->appDelegate;
    }));
}

@end

@implementation UISplitViewController (RevenantDisplayModes8)

- (BOOL)isCollapsed
{
    return revenant_split_collapsed(self);
}

- (BOOL)collapsed
{
    return revenant_split_collapsed(self);
}

- (UISplitViewControllerDisplayMode)preferredDisplayMode
{
    return revenant_split_state(self)->preferred;
}

- (void)setPreferredDisplayMode:(UISplitViewControllerDisplayMode)preferredDisplayMode
{
    RevenantSplitState *state = revenant_split_state(self);
    if (state->preferred == preferredDisplayMode)
        return;
    state->preferred = preferredDisplayMode;
    if (state->proxyInstalled) {
        revenant_install_proxy(self);
        [self.view setNeedsLayout];
    }
    revenant_update_button(self);
}

- (UISplitViewControllerDisplayMode)displayMode
{
    if (!revenant_split_on_phone() && !revenant_split_state(self)->proxyInstalled)
        revenant_install_proxy(self);
    return revenant_split_resolve(self);
}

- (UIBarButtonItem *)displayModeButtonItem
{
    RevenantSplitState *state = revenant_split_state(self);
    if (!state->button) {
        revenant_install_proxy(self);
        state->button = [[UIBarButtonItem alloc] initWithImage:nil style:UIBarButtonItemStyleBordered target:self action:@selector(revenant_displayModeButtonTapped:)];
        revenant_update_button(self);
    }
    return state->button;
}

- (void)revenant_displayModeButtonTapped:(id)sender
{
    RevenantSplitState *state = revenant_split_state(self);
    UISplitViewControllerDisplayMode current = revenant_split_resolve(self);
    UISplitViewControllerDisplayMode target = revenant_split_target(self, current);
    if (target == current)
        return;
    if (target == UISplitViewControllerDisplayModeOneOverSecondary) {
        UIBarButtonItem *native = state->nativeButton;
        if (native)
            [[UIApplication sharedApplication] sendAction:native.action to:native.target from:sender forEvent:nil];
        return;
    }
    if (current == UISplitViewControllerDisplayModeOneOverSecondary && target == UISplitViewControllerDisplayModeSecondaryOnly) {
        [state->popover dismissPopoverAnimated:YES];
        return;
    }
    self.preferredDisplayMode = target;
}

- (CGFloat)preferredPrimaryColumnWidthFraction
{
    return revenant_split_state(self)->fraction;
}

- (void)setPreferredPrimaryColumnWidthFraction:(CGFloat)fraction
{
    revenant_split_state(self)->fraction = fraction;
    revenant_split_apply_width(self);
}

- (CGFloat)minimumPrimaryColumnWidth
{
    return revenant_split_state(self)->minimum;
}

- (void)setMinimumPrimaryColumnWidth:(CGFloat)minimum
{
    revenant_split_state(self)->minimum = minimum;
    revenant_split_apply_width(self);
}

- (CGFloat)maximumPrimaryColumnWidth
{
    return revenant_split_state(self)->maximum;
}

- (void)setMaximumPrimaryColumnWidth:(CGFloat)maximum
{
    revenant_split_state(self)->maximum = maximum;
    revenant_split_apply_width(self);
}

- (CGFloat)primaryColumnWidth
{
    if (revenant_split_collapsed(self))
        return self.isViewLoaded ? self.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    return revenant_split_width(self);
}

@end
