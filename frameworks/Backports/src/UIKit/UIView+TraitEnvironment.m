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
static const char RevenantTraitSnapshotKey;
static const char RevenantPendingTraitsKey;

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

static BOOL revenant_attached(UIView *view)
{
    return view.window || [view isKindOfClass:[UIWindow class]];
}

static UITraitCollection *revenant_styled(UIView *view, UITraitCollection *collection)
{
    UIUserInterfaceStyle style = revenant_view_style_override(view);
    if (style == UIUserInterfaceStyleUnspecified || !revenant_attached(view))
        return collection;
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[collection, [UITraitCollection traitCollectionWithUserInterfaceStyle:style]]];
}

static void revenant_collect_subtree(UIView *view, NSMutableArray *views)
{
    [views addObject:view];
    for (UIView *subview in view.subviews)
        revenant_collect_subtree(subview, views);
}

static NSArray *revenant_subtree_traits(UIView *view)
{
    NSMutableArray *views = [NSMutableArray array];
    revenant_collect_subtree(view, views);
    NSMutableArray *traits = [NSMutableArray arrayWithCapacity:views.count];
    for (UIView *subview in views) {
        UITraitCollection *trait = subview.traitCollection;
        objc_setAssociatedObject(subview, &RevenantTraitSnapshotKey, trait, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [traits addObject:trait];
    }
    return @[views, traits];
}

static void revenant_install_attach_hooks(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL will = @selector(willMoveToSuperview:), did = @selector(didMoveToSuperview);
        Method willMethod = class_getInstanceMethod([UIView class], will);
        Method didMethod = class_getInstanceMethod([UIView class], did);
        void (*willOriginal)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(willMethod);
        void (*didOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(didMethod);
        class_replaceMethod([UIView class], will, imp_implementationWithBlock(^(UIView *view, UIView *superview) {
            objc_setAssociatedObject(view, &RevenantPendingTraitsKey, revenant_subtree_traits(view), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            willOriginal(view, will, superview);
        }), method_getTypeEncoding(willMethod));
        class_replaceMethod([UIView class], did, imp_implementationWithBlock(^(UIView *view) {
            didOriginal(view, did);
            NSArray *pending = objc_getAssociatedObject(view, &RevenantPendingTraitsKey);
            objc_setAssociatedObject(view, &RevenantPendingTraitsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSArray *views = pending[0], *before = pending[1];
            for (NSUInteger index = 0; index < views.count; index++) {
                UIView *subview = views[index];
                UITraitCollection *previous = before[index];
                if (![previous isEqual:subview.traitCollection])
                    [subview traitCollectionDidChange:previous];
            }
        }), method_getTypeEncoding(didMethod));
    });
}

@implementation UIView (RevenantTraitEnvironment)

+ (void)load
{
    revenant_install_attach_hooks();
}

- (UITraitCollection *)traitCollection
{
    if (revenant_attached(self))
        return revenant_styled(self, revenant_limited(self, revenant_inherited(self)));
    return objc_getAssociatedObject(self, &RevenantTraitSnapshotKey) ?: revenant_limited(self, revenant_inherited(self));
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
    revenant_refresh_view_colours(self);
}

@end
