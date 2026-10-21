#import "RevenantContentSize.h"
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

@implementation UIView (RevenantTraitEnvironment)

- (UITraitCollection *)traitCollection
{
    UIResponder *next = self.nextResponder;
    if ([next isKindOfClass:[UIViewController class]] && ((UIViewController *)next).view == self)
        return revenant_limited(self, [(UIViewController *)next traitCollection]);
    if (self.superview)
        return revenant_limited(self, [self.superview traitCollection]);
    UIWindow *window = [self isKindOfClass:[UIWindow class]] ? (UIWindow *)self : self.window;
    return revenant_limited(self, [UITraitCollection revenant_traitCollectionForScreen:window.screen]);
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
}

@end
