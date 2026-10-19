#import "RevenantCompositionalLayout.h"
#import <objc/runtime.h>

static void revenant_wrap_labels(UIView *view, NSMutableArray *labels)
{
    if ([view isKindOfClass:[UILabel class]])
        [labels addObject:view];
    for (UIView *sub in view.subviews)
        revenant_wrap_labels(sub, labels);
}

static CGSize revenant_constrained_fit(UIView *content, CGSize proposed, BOOL estimatedWidth, BOOL estimatedHeight)
{
    BOOL translates = content.translatesAutoresizingMaskIntoConstraints;
    CGRect frame = content.frame;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableArray *pins = [NSMutableArray array];
    if (!estimatedWidth)
        [pins addObject:[NSLayoutConstraint constraintWithItem:content attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1
                                                       constant:proposed.width]];
    if (!estimatedHeight)
        [pins addObject:[NSLayoutConstraint constraintWithItem:content attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1
                                                       constant:proposed.height]];
    [content addConstraints:pins];
    CGSize size = [content systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    if (!estimatedWidth)
        size.width = proposed.width;
    if (!estimatedHeight)
        size.height = proposed.height;
    content.frame = CGRectMake(0, 0, size.width, size.height);
    [content setNeedsLayout];
    [content layoutIfNeeded];
    NSMutableArray *labels = [NSMutableArray array];
    revenant_wrap_labels(content, labels);
    BOOL wrapped = NO;
    for (UILabel *label in labels) {
        CGFloat width = label.bounds.size.width;
        if (label.numberOfLines != 1 && fabs(label.preferredMaxLayoutWidth - width) > 0.01) {
            label.preferredMaxLayoutWidth = width;
            wrapped = YES;
        }
    }
    if (wrapped) {
        size = [content systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        if (!estimatedWidth)
            size.width = proposed.width;
        if (!estimatedHeight)
            size.height = proposed.height;
    }
    [content removeConstraints:pins];
    content.translatesAutoresizingMaskIntoConstraints = translates;
    content.frame = frame;
    return size;
}

static BOOL revenant_overrides_preferred(UICollectionReusableView *view)
{
    SEL selector = @selector(preferredLayoutAttributesFittingAttributes:);
    IMP mine = class_getMethodImplementation([view class], selector);
    return mine != class_getMethodImplementation([UICollectionReusableView class], selector) && mine != class_getMethodImplementation([UICollectionViewCell class], selector);
}

UICollectionViewLayoutAttributes *revenant_default_preferred(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight)
{
    UIView *content = [view respondsToSelector:@selector(contentView)] ? [(UICollectionViewCell *)view contentView] : view;
    CGSize proposed = attributes.frame.size;
    CGSize size;
    if (content.constraints.count > 0) {
        size = revenant_constrained_fit(content, proposed, estimatedWidth, estimatedHeight);
    } else {
        CGRect frame = view.frame;
        view.frame = CGRectMake(0, 0, proposed.width, proposed.height);
        [view layoutIfNeeded];
        size = [view sizeThatFits:proposed];
        view.frame = frame;
    }
    UICollectionViewLayoutAttributes *preferred = [attributes copy];
    CGRect frame = preferred.frame;
    frame.size = size;
    preferred.frame = frame;
    return preferred;
}

UICollectionViewLayoutAttributes *revenant_preferred_attributes(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight, CGFloat scale)
{
    UICollectionViewLayoutAttributes *preferred;
    if (revenant_overrides_preferred(view)) {
        [view layoutIfNeeded];
        preferred = [view preferredLayoutAttributesFittingAttributes:attributes];
    } else {
        preferred = revenant_default_preferred(view, attributes, estimatedWidth, estimatedHeight);
    }
    CGSize proposed = attributes.frame.size;
    CGSize size = preferred.frame.size;
    if (!(size.width > 0) || !(size.height > 0) || !isfinite(size.width) || !isfinite(size.height))
        size = proposed;
    else if (scale > 0) {
        size.width = ceil(size.width * scale - 0.001) / scale;
        size.height = ceil(size.height * scale - 0.001) / scale;
    }
    UICollectionViewLayoutAttributes *result = [attributes copy];
    CGRect frame = result.frame;
    frame.size = CGSizeMake(estimatedWidth ? size.width : proposed.width, estimatedHeight ? size.height : proposed.height);
    result.frame = frame;
    return result;
}

void revenant_layout_perform(UICollectionViewLayout *layout, void (^work)(UICollectionViewLayout *layout))
{
    __weak UICollectionViewLayout *weak = layout;
    dispatch_async(dispatch_get_main_queue(), ^{
        UICollectionViewLayout *strong = weak;
        if (strong)
            work(strong);
    });
}

@implementation UICollectionView (RevenantSelfSizing)

- (void)revenant_layoutSubviews
{
    [self revenant_layoutSubviews];
    for (int pass = 0; pass < 4; pass++) {
        UICollectionViewLayout *layout = self.collectionViewLayout;
        if (![layout respondsToSelector:@selector(revenant_settleMeasurements)] || ![layout revenant_settleMeasurements])
            break;
        [self revenant_layoutSubviews];
    }
}

+ (void)load
{
    SEL original = @selector(layoutSubviews), replacement = @selector(revenant_layoutSubviews);
    Method own = class_getInstanceMethod([UICollectionView class], replacement);
    IMP replaced = method_getImplementation(own);
    const char *types = method_getTypeEncoding(own);
    Method inherited = class_getInstanceMethod([UICollectionView class], original);
    if (!inherited)
        return;
    if (class_addMethod([UICollectionView class], original, replaced, types))
        class_replaceMethod([UICollectionView class], replacement, method_getImplementation(inherited), types);
    else
        method_exchangeImplementations(inherited, own);
}

@end
