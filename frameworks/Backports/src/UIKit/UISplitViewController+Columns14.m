#import "RevenantSplit.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static UIViewController *revenant_column_controller(UIViewController *controller)
{
    if (!controller || [controller isKindOfClass:[UINavigationController class]])
        return controller;
    return [[UINavigationController alloc] initWithRootViewController:controller];
}

static void revenant_apply_columns(UISplitViewController *split)
{
    RevenantSplitState *state = revenant_split_state(split);
    if (!state->columnPrimary)
        return;
    if (!state->columnSecondary)
        state->columnSecondary = revenant_column_controller([[UIViewController alloc] init]);
    split.viewControllers = @[state->columnPrimary, state->columnSecondary];
}

@implementation UISplitViewController (RevenantColumns14)

- (instancetype)initWithStyle:(UISplitViewControllerStyle)style
{
    if (style == UISplitViewControllerStyleTripleColumn)
        [NSException raise:NSInternalInconsistencyException format:@"-[UISplitViewController initWithStyle:] does not support UISplitViewControllerStyleTripleColumn: the iOS 6 split view controller lays out two columns"];
    if ((self = [self initWithNibName:nil bundle:nil]))
        revenant_split_state(self)->style = style;
    return self;
}

- (UISplitViewControllerStyle)style
{
    return revenant_split_state(self)->style;
}

- (void)setViewController:(UIViewController *)vc forColumn:(UISplitViewControllerColumn)column
{
    RevenantSplitState *state = revenant_split_state(self);
    switch (column) {
    case UISplitViewControllerColumnPrimary:
        state->columnPrimary = revenant_column_controller(vc);
        break;
    case UISplitViewControllerColumnSecondary:
        state->columnSecondary = revenant_column_controller(vc);
        break;
    case UISplitViewControllerColumnCompact:
        state->compact = vc;
        break;
    default:
        [NSException raise:NSInvalidArgumentException format:@"UISplitViewControllerColumnSupplementary is valid for UISplitViewControllerStyleTripleColumn only"];
    }
    revenant_apply_columns(self);
}

- (UIViewController *)viewControllerForColumn:(UISplitViewControllerColumn)column
{
    RevenantSplitState *state = revenant_split_state(self);
    switch (column) {
    case UISplitViewControllerColumnPrimary:
        return state->columnPrimary ?: self.viewControllers.firstObject;
    case UISplitViewControllerColumnSecondary:
        return state->columnSecondary ?: (self.viewControllers.count > 1 ? self.viewControllers[1] : nil);
    case UISplitViewControllerColumnCompact:
        return state->compact;
    default:
        return nil;
    }
}

- (void)hideColumn:(UISplitViewControllerColumn)column
{
    RevenantSplitState *state = revenant_split_state(self);
    if (column == UISplitViewControllerColumnCompact || column == UISplitViewControllerColumnSupplementary)
        [NSException raise:NSInvalidArgumentException format:@"-[UISplitViewController hideColumn:] does not accept this column"];
    if (column != UISplitViewControllerColumnPrimary && !revenant_split_collapsed(self))
        return;
    if (revenant_split_collapsed(self)) {
        UINavigationController *navigation = (UINavigationController *)state->primary;
        NSArray *content = [navigation isKindOfClass:[UINavigationController class]] ? revenant_split_collapsed_content(navigation) : nil;
        if (column == UISplitViewControllerColumnSecondary && content.count && navigation.topViewController == content.lastObject) {
            NSUInteger index = [navigation.viewControllers indexOfObject:content.firstObject];
            if (index != NSNotFound && index > 0)
                [navigation popToViewController:navigation.viewControllers[index - 1] animated:YES];
        }
        return;
    }
    if (revenant_split_resolve(self) != UISplitViewControllerDisplayModeSecondaryOnly)
        self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
}

- (void)showColumn:(UISplitViewControllerColumn)column
{
    RevenantSplitState *state = revenant_split_state(self);
    if (column == UISplitViewControllerColumnCompact || column == UISplitViewControllerColumnSupplementary)
        [NSException raise:NSInvalidArgumentException format:@"-[UISplitViewController showColumn:] does not accept this column"];
    if (revenant_split_collapsed(self)) {
        UINavigationController *navigation = (UINavigationController *)state->primary;
        if (![navigation isKindOfClass:[UINavigationController class]])
            return;
        if (column == UISplitViewControllerColumnPrimary)
            [navigation popToRootViewControllerAnimated:YES];
        else
            revenant_split_collapse_again(self);
        return;
    }
    if (column == UISplitViewControllerColumnSecondary || revenant_split_resolve(self) != UISplitViewControllerDisplayModeSecondaryOnly)
        return;
    self.preferredDisplayMode = self.splitBehavior == UISplitViewControllerSplitBehaviorOverlay ? UISplitViewControllerDisplayModeOneOverSecondary : UISplitViewControllerDisplayModeOneBesideSecondary;
}

- (UISplitViewControllerSplitBehavior)preferredSplitBehavior
{
    return revenant_split_state(self)->behavior;
}

- (void)setPreferredSplitBehavior:(UISplitViewControllerSplitBehavior)preferredSplitBehavior
{
    revenant_split_state(self)->behavior = preferredSplitBehavior;
}

- (UISplitViewControllerSplitBehavior)splitBehavior
{
    UISplitViewControllerSplitBehavior preferred = revenant_split_state(self)->behavior;
    if (preferred == UISplitViewControllerSplitBehaviorOverlay)
        return preferred;
    if (preferred != UISplitViewControllerSplitBehaviorAutomatic)
        return UISplitViewControllerSplitBehaviorTile;
    CGSize size = self.isViewLoaded ? self.view.bounds.size : [UIScreen mainScreen].bounds.size;
    return size.width > size.height ? UISplitViewControllerSplitBehaviorTile : UISplitViewControllerSplitBehaviorOverlay;
}

- (BOOL)showsSecondaryOnlyButton
{
    return revenant_split_state(self)->showsSecondaryOnlyButton;
}

- (void)setShowsSecondaryOnlyButton:(BOOL)showsSecondaryOnlyButton
{
    revenant_split_state(self)->showsSecondaryOnlyButton = showsSecondaryOnlyButton;
}

- (UISplitViewControllerDisplayModeButtonVisibility)displayModeButtonVisibility
{
    return revenant_split_state(self)->visibility;
}

- (void)setDisplayModeButtonVisibility:(UISplitViewControllerDisplayModeButtonVisibility)displayModeButtonVisibility
{
    revenant_split_state(self)->visibility = displayModeButtonVisibility;
    if (revenant_split_state(self)->button)
        [self displayModeButtonItem];
    [self.view setNeedsLayout];
}

- (CGFloat)preferredPrimaryColumnWidth
{
    return revenant_split_state(self)->preferredWidth;
}

- (void)setPreferredPrimaryColumnWidth:(CGFloat)preferredPrimaryColumnWidth
{
    revenant_split_state(self)->preferredWidth = preferredPrimaryColumnWidth;
    revenant_split_apply_width(self);
}

- (CGFloat)preferredSupplementaryColumnWidthFraction
{
    return revenant_split_state(self)->supplementaryFraction;
}

- (void)setPreferredSupplementaryColumnWidthFraction:(CGFloat)fraction
{
    revenant_split_state(self)->supplementaryFraction = fraction;
}

- (CGFloat)preferredSupplementaryColumnWidth
{
    return revenant_split_state(self)->supplementaryWidth;
}

- (void)setPreferredSupplementaryColumnWidth:(CGFloat)width
{
    revenant_split_state(self)->supplementaryWidth = width;
}

- (CGFloat)minimumSupplementaryColumnWidth
{
    return revenant_split_state(self)->supplementaryMinimum;
}

- (void)setMinimumSupplementaryColumnWidth:(CGFloat)width
{
    revenant_split_state(self)->supplementaryMinimum = width;
}

- (CGFloat)maximumSupplementaryColumnWidth
{
    return revenant_split_state(self)->supplementaryMaximum;
}

- (void)setMaximumSupplementaryColumnWidth:(CGFloat)width
{
    revenant_split_state(self)->supplementaryMaximum = width;
}

- (CGFloat)supplementaryColumnWidth
{
    return 0;
}

@end
