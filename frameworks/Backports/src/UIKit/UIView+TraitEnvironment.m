#import "RevenantContentSize.h"
#import "RevenantTraitStyle.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (RevenantTraitEnvironment)
+ (UITraitCollection *)revenant_traitCollectionForScreen:(UIScreen *)screen;
@end

@interface UIView (RevenantTraitEnvironment) <UITraitEnvironment>
@end

static const char RevenantMinimumCategoryKey;
static const char RevenantMaximumCategoryKey;

static UITraitCollection *revenant_limited(UIView *view, UITraitCollection *inherited)
{
    UIContentSizeCategory minimum = objc_getAssociatedObject(view, &RevenantMinimumCategoryKey);
    UIContentSizeCategory maximum = objc_getAssociatedObject(view, &RevenantMaximumCategoryKey);
    if (!minimum && !maximum)
        return inherited;
    NSArray *ordered = revenant_ordered_content_size_categories();
    UIContentSizeCategory category = inherited.preferredContentSizeCategory;
    NSUInteger index = [ordered indexOfObject:category];
    if (index == NSNotFound)
        return inherited;
    NSUInteger low = minimum ? [ordered indexOfObject:minimum] : 0, high = maximum ? [ordered indexOfObject:maximum] : ordered.count - 1;
    if (low == NSNotFound || high == NSNotFound)
        return inherited;
    NSUInteger clamped = MIN(MAX(index, low), MAX(high, low));
    if (clamped == index)
        return inherited;
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[inherited, [UITraitCollection traitCollectionWithPreferredContentSizeCategory:ordered[clamped]]]];
}

static UITraitCollection *revenant_inherited(UIView *view)
{
    UIResponder *next = view.nextResponder;
    if ([next isKindOfClass:[UIViewController class]] && ((UIViewController *)next).view == view)
        return [(UIViewController *)next traitCollection];
    if (view.superview)
        return [view.superview traitCollection];
    UIWindow *window = [view isKindOfClass:[UIWindow class]] ? (UIWindow *)view : view.window;
    return [UITraitCollection revenant_traitCollectionForScreen:window.screen];
}

static UITraitCollection *revenant_styled(UIView *view, UITraitCollection *collection)
{
    UIUserInterfaceStyle style = revenant_view_style_override(view);
    if (style == UIUserInterfaceStyleUnspecified || !view.window)
        return collection;
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[collection, [UITraitCollection traitCollectionWithUserInterfaceStyle:style]]];
}

@implementation UIView (RevenantTraitEnvironment)

- (UITraitCollection *)traitCollection
{
    return revenant_styled(self, revenant_limited(self, revenant_inherited(self)));
}

- (UIContentSizeCategory)minimumContentSizeCategory
{
    return objc_getAssociatedObject(self, &RevenantMinimumCategoryKey);
}

- (void)setMinimumContentSizeCategory:(UIContentSizeCategory)minimumContentSizeCategory
{
    objc_setAssociatedObject(self, &RevenantMinimumCategoryKey, minimumContentSizeCategory, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIContentSizeCategory)maximumContentSizeCategory
{
    return objc_getAssociatedObject(self, &RevenantMaximumCategoryKey);
}

- (void)setMaximumContentSizeCategory:(UIContentSizeCategory)maximumContentSizeCategory
{
    objc_setAssociatedObject(self, &RevenantMaximumCategoryKey, maximumContentSizeCategory, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    UIColor *background = self.backgroundColor;
    UIColor *resolved = revenant_color_for_traits(background, self.traitCollection);
    if (resolved != background)
        self.backgroundColor = resolved;
}

@end
