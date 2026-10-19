#import "CharonCompositionalLayout.h"
#import <objc/runtime.h>

static void charon_wrap_labels(UIView *view, NSMutableArray *labels)
{
    if ([view isKindOfClass:[UILabel class]])
        [labels addObject:view];
    for (UIView *sub in view.subviews)
        charon_wrap_labels(sub, labels);
}

static CGSize charon_constrained_fit(UIView *content, CGSize proposed, BOOL estimatedWidth, BOOL estimatedHeight)
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
    charon_wrap_labels(content, labels);
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

static BOOL charon_overrides_preferred(UICollectionReusableView *view)
{
    SEL selector = @selector(preferredLayoutAttributesFittingAttributes:);
    IMP mine = class_getMethodImplementation([view class], selector);
    return mine != class_getMethodImplementation([UICollectionReusableView class], selector) && mine != class_getMethodImplementation([UICollectionViewCell class], selector);
}

UICollectionViewLayoutAttributes *charon_default_preferred(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight)
{
    UIView *content = [view respondsToSelector:@selector(contentView)] ? [(UICollectionViewCell *)view contentView] : view;
    CGSize proposed = attributes.frame.size;
    CGSize size;
    if (content.constraints.count > 0) {
        size = charon_constrained_fit(content, proposed, estimatedWidth, estimatedHeight);
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

UICollectionViewLayoutAttributes *charon_preferred_attributes(UICollectionReusableView *view, UICollectionViewLayoutAttributes *attributes, BOOL estimatedWidth, BOOL estimatedHeight, CGFloat scale)
{
    UICollectionViewLayoutAttributes *preferred;
    if (charon_overrides_preferred(view)) {
        [view layoutIfNeeded];
        preferred = [view preferredLayoutAttributesFittingAttributes:attributes];
    } else {
        preferred = charon_default_preferred(view, attributes, estimatedWidth, estimatedHeight);
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

void charon_layout_perform(UICollectionViewLayout *layout, void (^work)(UICollectionViewLayout *layout))
{
    // A plain dispatch_async, not CFRunLoopPerformBlock/CFRunLoopWakeUp: the latter forces the
    // main run loop to service the block on its very next pass, ahead of whatever else the run
    // loop already had queued for that pass, including a dispatch_after fired around the same
    // deferred measurement. Every other deferred-to-main-thread spot in this package already uses
    // dispatch_async; this one was the sole outlier, and forcing it made this settle pass compete
    // for the run loop's attention with other main-queue work rather than simply taking a turn.
    __weak UICollectionViewLayout *weak = layout;
    dispatch_async(dispatch_get_main_queue(), ^{
        UICollectionViewLayout *strong = weak;
        if (strong)
            work(strong);
    });
}

@implementation UICollectionView (CharonSelfSizing)

- (void)charon_layoutSubviews
{
    [self charon_layoutSubviews];
    for (int pass = 0; pass < 4; pass++) {
        UICollectionViewLayout *layout = self.collectionViewLayout;
        if (![layout respondsToSelector:@selector(charon_settleMeasurements)] || ![layout charon_settleMeasurements])
            break;
        [self charon_layoutSubviews];
    }
}

+ (void)load
{
    SEL original = @selector(layoutSubviews), replacement = @selector(charon_layoutSubviews);
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
