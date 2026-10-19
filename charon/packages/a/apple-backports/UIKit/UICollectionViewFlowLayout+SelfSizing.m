#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CharonCompositionalLayout.h"

extern const CGSize UICollectionViewFlowLayoutAutomaticSize;

static const char charon_estimated_key;
static const char charon_model_key;
static const char charon_measured_key;
static const char charon_pending_key;
static const char charon_width_key;
static const char charon_applied_key;
static const char charon_reference_key;

@interface CharonFlowModel : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, UICollectionViewLayoutAttributes *> *items;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, UICollectionViewLayoutAttributes *> *headers;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, UICollectionViewLayoutAttributes *> *footers;
@property (nonatomic, assign) CGSize content;
@end

@implementation CharonFlowModel
@synthesize items, headers, footers, content;
@end

static CGSize charon_estimate(UICollectionViewFlowLayout *layout)
{
    NSValue *value = objc_getAssociatedObject(layout, &charon_estimated_key);
    CGSize size = value ? value.CGSizeValue : CGSizeZero;
    if (size.width >= CGFLOAT_MAX / 2 || size.height >= CGFLOAT_MAX / 2)
        return CGSizeMake(50, 50);
    return size;
}

static NSInteger charon_reference_kind(UICollectionViewFlowLayout *layout)
{
    return [objc_getAssociatedObject(layout, &charon_reference_key) integerValue];
}

static BOOL charon_estimating(UICollectionViewLayout *layout)
{
    if (![layout isKindOfClass:[UICollectionViewFlowLayout class]])
        return NO;
    UICollectionViewFlowLayout *flow = (UICollectionViewFlowLayout *)layout;
    NSValue *value = objc_getAssociatedObject(flow, &charon_estimated_key);
    if (!value || CGSizeEqualToSize(value.CGSizeValue, CGSizeZero))
        return NO;
    return flow.scrollDirection == UICollectionViewScrollDirectionVertical;
}

static BOOL charon_active(UICollectionViewLayout *layout)
{
    if (charon_estimating(layout))
        return YES;
    if (![layout isKindOfClass:[UICollectionViewFlowLayout class]])
        return NO;
    UICollectionViewFlowLayout *flow = (UICollectionViewFlowLayout *)layout;
    return charon_reference_kind(flow) != 0 && flow.scrollDirection == UICollectionViewScrollDirectionVertical && CGSizeEqualToSize(flow.estimatedItemSize, CGSizeZero);
}

static NSMutableDictionary *charon_measured(UICollectionViewLayout *layout)
{
    NSMutableDictionary *measured = objc_getAssociatedObject(layout, &charon_measured_key);
    if (!measured) {
        measured = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(layout, &charon_measured_key, measured, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return measured;
}

static id charon_delegate(UICollectionViewFlowLayout *layout, SEL selector)
{
    id delegate = layout.collectionView.delegate;
    return [delegate respondsToSelector:selector] ? delegate : nil;
}

static UIEdgeInsets charon_inset(UICollectionViewFlowLayout *layout, NSInteger section)
{
    id delegate = charon_delegate(layout, @selector(collectionView:layout:insetForSectionAtIndex:));
    UIEdgeInsets inset = delegate ? [delegate collectionView:layout.collectionView layout:layout insetForSectionAtIndex:section] : layout.sectionInset;
    NSInteger reference = charon_reference_kind(layout);
    if (reference == 0)
        return inset;
    UICollectionView *view = layout.collectionView;
    UIEdgeInsets against = reference == 2 ? view.layoutMargins : view.safeAreaInsets;
    UIEdgeInsets adjusted = view.adjustedContentInset;
    inset.left = MAX(inset.left + against.left - adjusted.left, 0);
    inset.right = MAX(inset.right + against.right - adjusted.right, 0);
    return inset;
}

static CGFloat charon_line_spacing(UICollectionViewFlowLayout *layout, NSInteger section)
{
    id delegate = charon_delegate(layout, @selector(collectionView:layout:minimumLineSpacingForSectionAtIndex:));
    return delegate ? [delegate collectionView:layout.collectionView layout:layout minimumLineSpacingForSectionAtIndex:section] : layout.minimumLineSpacing;
}

static CGFloat charon_item_spacing(UICollectionViewFlowLayout *layout, NSInteger section)
{
    id delegate = charon_delegate(layout, @selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:));
    return delegate ? [delegate collectionView:layout.collectionView layout:layout minimumInteritemSpacingForSectionAtIndex:section] : layout.minimumInteritemSpacing;
}

static CGSize charon_reference(UICollectionViewFlowLayout *layout, NSInteger section, BOOL header)
{
    SEL selector = header ? @selector(collectionView:layout:referenceSizeForHeaderInSection:) : @selector(collectionView:layout:referenceSizeForFooterInSection:);
    id delegate = charon_delegate(layout, selector);
    if (delegate)
        return header ? [delegate collectionView:layout.collectionView layout:layout referenceSizeForHeaderInSection:section]
                      : [delegate collectionView:layout.collectionView layout:layout referenceSizeForFooterInSection:section];
    return header ? layout.headerReferenceSize : layout.footerReferenceSize;
}

static CGSize charon_item_size(UICollectionViewFlowLayout *layout, NSIndexPath *path)
{
    NSValue *measured = charon_measured(layout)[path];
    if (measured)
        return measured.CGSizeValue;
    id delegate = charon_delegate(layout, @selector(collectionView:layout:sizeForItemAtIndexPath:));
    if (delegate)
        return [delegate collectionView:layout.collectionView layout:layout sizeForItemAtIndexPath:path];
    return charon_estimating(layout) ? charon_estimate(layout) : layout.itemSize;
}

static UICollectionViewLayoutAttributes *charon_attributes(UICollectionViewFlowLayout *layout, NSIndexPath *path, NSString *kind, CGRect frame)
{
    Class attributesClass = [[layout class] layoutAttributesClass];
    UICollectionViewLayoutAttributes *attributes = kind ? [attributesClass layoutAttributesForSupplementaryViewOfKind:kind withIndexPath:path] : [attributesClass layoutAttributesForCellWithIndexPath:path];
    attributes.frame = frame;
    return attributes;
}

static CGFloat charon_align(CGFloat value)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    return round(value * scale) / scale;
}

static void charon_place_line(NSArray<NSNumber *> *widths, NSArray<NSValue *> *sizes, NSUInteger first, NSUInteger count, CGFloat gap, BOOL center, CGFloat left, CGFloat available, CGFloat lineY, CGFloat lineHeight, NSInteger section, UICollectionViewFlowLayout *layout, CharonFlowModel *model)
{
    CGFloat total = 0;
    for (NSUInteger index = 0; index < count; index++)
        total += widths[first + index].doubleValue;
    CGFloat x = left;
    if (center)
        x = left + MAX(0, (available - total - gap * (count - 1)) / 2);
    for (NSUInteger index = 0; index < count; index++) {
        CGSize size = sizes[first + index].CGSizeValue;
        NSIndexPath *path = [NSIndexPath indexPathForItem:first + index inSection:section];
        model.items[path] = charon_attributes(layout, path, nil, CGRectMake(charon_align(x), charon_align(lineY + (lineHeight - size.height) / 2), size.width, size.height));
        x += size.width + gap;
    }
}

static void charon_build(UICollectionViewFlowLayout *layout)
{
    UICollectionView *view = layout.collectionView;
    CharonFlowModel *model = [[CharonFlowModel alloc] init];
    model.items = [NSMutableDictionary dictionary];
    model.headers = [NSMutableDictionary dictionary];
    model.footers = [NSMutableDictionary dictionary];
    UIEdgeInsets adjustment = view.adjustedContentInset;
    CGFloat width = view.bounds.size.width - adjustment.left - adjustment.right;
    CGFloat y = 0;
    for (NSInteger section = 0; section < view.numberOfSections; section++) {
        NSIndexPath *sectionPath = [NSIndexPath indexPathForItem:0 inSection:section];
        UIEdgeInsets inset = charon_inset(layout, section);
        CGFloat lineSpacing = charon_line_spacing(layout, section);
        CGFloat itemSpacing = charon_item_spacing(layout, section);
        CGSize header = charon_reference(layout, section, YES);
        if (header.height > 0) {
            model.headers[sectionPath] = charon_attributes(layout, sectionPath, UICollectionElementKindSectionHeader, CGRectMake(0, y, width, header.height));
            y += header.height;
        }
        y += inset.top;
        CGFloat available = width - inset.left - inset.right;
        NSInteger count = [view numberOfItemsInSection:section];
        NSMutableArray<NSValue *> *sizes = [NSMutableArray arrayWithCapacity:count];
        NSMutableArray<NSNumber *> *widths = [NSMutableArray arrayWithCapacity:count];
        BOOL uniform = YES;
        for (NSInteger item = 0; item < count; item++) {
            CGSize size = charon_item_size(layout, [NSIndexPath indexPathForItem:item inSection:section]);
            [sizes addObject:[NSValue valueWithCGSize:size]];
            [widths addObject:@(size.width)];
            if (item && size.width != sizes[0].CGSizeValue.width)
                uniform = NO;
        }
        NSUInteger uniformPerLine = 0;
        if (uniform && count) {
            CGFloat itemWidth = sizes[0].CGSizeValue.width;
            uniformPerLine = MAX(1, (NSUInteger)floor((available + itemSpacing) / (itemWidth + itemSpacing)));
        }
        NSUInteger first = 0;
        while (first < (NSUInteger)count) {
            NSUInteger n = 1;
            if (uniform) {
                n = MIN(uniformPerLine, (NSUInteger)count - first);
            } else {
                CGFloat used = widths[first].doubleValue;
                while (first + n < (NSUInteger)count && used + itemSpacing + widths[first + n].doubleValue <= available + 0.001) {
                    used += itemSpacing + widths[first + n].doubleValue;
                    n++;
                }
            }
            CGFloat lineHeight = 0, total = 0;
            for (NSUInteger index = 0; index < n; index++) {
                lineHeight = MAX(lineHeight, sizes[first + index].CGSizeValue.height);
                total += widths[first + index].doubleValue;
            }
            BOOL last = first + n >= (NSUInteger)count;
            CGFloat gap = itemSpacing;
            BOOL center = NO;
            if (uniform) {
                gap = uniformPerLine > 1 ? MAX(itemSpacing, (available - uniformPerLine * widths[0].doubleValue) / (uniformPerLine - 1)) : 0;
                center = uniformPerLine == 1;
            } else if (!last) {
                gap = n > 1 ? (available - total) / (n - 1) : 0;
                center = n == 1;
            } else if (n == 1) {
                center = 2 * total + itemSpacing > available;
            }
            if (n == 1 && total > available)
                center = NO;
            charon_place_line(widths, sizes, first, n, gap, center, inset.left, available, y, lineHeight, section, layout, model);
            y += lineHeight;
            first += n;
            if (first < (NSUInteger)count)
                y += lineSpacing;
        }
        y += inset.bottom;
        CGSize footer = charon_reference(layout, section, NO);
        if (footer.height > 0) {
            model.footers[sectionPath] = charon_attributes(layout, sectionPath, UICollectionElementKindSectionFooter, CGRectMake(0, y, width, footer.height));
            y += footer.height;
        }
    }
    model.content = CGSizeMake(width, y);
    objc_setAssociatedObject(layout, &charon_model_key, model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static CharonFlowModel *charon_model(UICollectionViewLayout *layout)
{
    return objc_getAssociatedObject(layout, &charon_model_key);
}

static void charon_install_layout_hooks(void);
static void charon_install_cell_hook(void);

@implementation UICollectionViewFlowLayout (CharonSelfSizing)

- (CGSize)estimatedItemSize
{
    NSValue *value = objc_getAssociatedObject(self, &charon_estimated_key);
    return value ? value.CGSizeValue : CGSizeZero;
}

- (void)setEstimatedItemSize:(CGSize)estimatedItemSize
{
    charon_install_layout_hooks();
    charon_install_cell_hook();
    objc_setAssociatedObject(self, &charon_estimated_key, [NSValue valueWithCGSize:estimatedItemSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [charon_measured(self) removeAllObjects];
    [self invalidateLayout];
}

- (UICollectionViewFlowLayoutSectionInsetReference)sectionInsetReference
{
    return (UICollectionViewFlowLayoutSectionInsetReference)charon_reference_kind(self);
}

- (void)setSectionInsetReference:(UICollectionViewFlowLayoutSectionInsetReference)reference
{
    charon_install_layout_hooks();
    objc_setAssociatedObject(self, &charon_reference_key, @(reference), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UICollectionViewLayout (CharonPreferredAttributes)

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes
{
    return !CGSizeEqualToSize(preferredAttributes.size, originalAttributes.size);
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes
{
    UICollectionViewLayoutInvalidationContext *context = [[[[self class] invalidationContextClass] alloc] init];
    if (originalAttributes.representedElementCategory == UICollectionElementCategoryCell && originalAttributes.indexPath)
        [context invalidateItemsAtIndexPaths:@[originalAttributes.indexPath]];
    context.contentSizeAdjustment = CGSizeMake(preferredAttributes.size.width - originalAttributes.size.width, preferredAttributes.size.height - originalAttributes.size.height);
    return context;
}

@end

@implementation UICollectionReusableView (CharonPreferredAttributes)

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    UIView *owner = self.superview;
    while (owner && ![owner isKindOfClass:[UICollectionView class]])
        owner = owner.superview;
    UICollectionViewLayout *layout = [(UICollectionView *)owner collectionViewLayout];
    if ([layout respondsToSelector:@selector(charon_estimatedAxesForAttributes:)]) {
        NSUInteger axes = [layout charon_estimatedAxesForAttributes:layoutAttributes];
        if (axes)
            return charon_default_preferred(self, layoutAttributes, (axes & 1) != 0, (axes & 2) != 0);
    }
    UICollectionViewLayoutAttributes *preferred = [layoutAttributes copy];
    UIView *target = [self isKindOfClass:[UICollectionViewCell class]] ? [(UICollectionViewCell *)self contentView] : self;
    CGSize fitted = [target systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    CGRect frame = preferred.frame;
    CGFloat scale = [UIScreen mainScreen].scale;
    if (fitted.width > 0)
        frame.size.width = ceil(fitted.width * scale) / scale;
    if (fitted.height > 0)
        frame.size.height = ceil(fitted.height * scale) / scale;
    preferred.frame = frame;
    return preferred;
}

@end

static void charon_schedule_invalidation(UICollectionViewFlowLayout *layout, UICollectionViewLayoutInvalidationContext *context)
{
    NSMutableArray *pending = objc_getAssociatedObject(layout, &charon_pending_key);
    if (pending) {
        [pending addObject:context];
        return;
    }
    pending = [NSMutableArray arrayWithObject:context];
    objc_setAssociatedObject(layout, &charon_pending_key, pending, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_layout_perform(layout, ^(UICollectionViewLayout *strong) {
        NSArray *contexts = objc_getAssociatedObject(strong, &charon_pending_key);
        objc_setAssociatedObject(strong, &charon_pending_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UICollectionViewLayoutInvalidationContext *item in contexts)
            [strong invalidateLayoutWithContext:item];
    });
}

static void charon_measure(UICollectionViewCell *cell, UICollectionViewLayoutAttributes *attributes)
{
    UIView *superview = cell.superview;
    while (superview && ![superview isKindOfClass:[UICollectionView class]])
        superview = superview.superview;
    UICollectionView *view = (UICollectionView *)superview;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)view.collectionViewLayout;
    if (!view || !charon_estimating(layout) || !attributes.indexPath || attributes.representedElementCategory != UICollectionElementCategoryCell)
        return;
    UICollectionViewLayoutAttributes *preferred = [cell preferredLayoutAttributesFittingAttributes:attributes];
    if (!preferred)
        return;
    NSValue *known = charon_measured(layout)[attributes.indexPath];
    if (known && CGSizeEqualToSize(known.CGSizeValue, preferred.size) && CGSizeEqualToSize(attributes.size, preferred.size))
        return;
    if (![layout shouldInvalidateLayoutForPreferredLayoutAttributes:preferred withOriginalAttributes:attributes])
        return;
    charon_measured(layout)[attributes.indexPath] = [NSValue valueWithCGSize:preferred.size];
    charon_schedule_invalidation(layout, [layout invalidationContextForPreferredLayoutAttributes:preferred withOriginalAttributes:attributes]);
}

static void charon_install_cell_hook(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method method = class_getInstanceMethod([UICollectionViewCell class], @selector(applyLayoutAttributes:));
        void (*original)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(method);
        class_replaceMethod([UICollectionViewCell class], @selector(applyLayoutAttributes:), imp_implementationWithBlock(^(UICollectionViewCell *self_, UICollectionViewLayoutAttributes *attributes) {
            original(self_, @selector(applyLayoutAttributes:), attributes);
            objc_setAssociatedObject(self_, &charon_applied_key, attributes, OBJC_ASSOCIATION_COPY_NONATOMIC);
            charon_measure(self_, attributes);
        }), method_getTypeEncoding(method));
        Method moved = class_getInstanceMethod([UICollectionReusableView class], @selector(didMoveToSuperview));
        void (*movedOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(moved);
        class_replaceMethod([UICollectionReusableView class], @selector(didMoveToSuperview), imp_implementationWithBlock(^(UICollectionReusableView *self_) {
            movedOriginal(self_, @selector(didMoveToSuperview));
            UICollectionViewLayoutAttributes *attributes = objc_getAssociatedObject(self_, &charon_applied_key);
            if (attributes && self_.superview && [self_ isKindOfClass:[UICollectionViewCell class]])
                charon_measure((UICollectionViewCell *)self_, attributes);
        }), method_getTypeEncoding(moved));
        Method reload = class_getInstanceMethod([UICollectionView class], @selector(reloadData));
        void (*reloadOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(reload);
        class_replaceMethod([UICollectionView class], @selector(reloadData), imp_implementationWithBlock(^(UICollectionView *self_) {
            if (charon_active(self_.collectionViewLayout))
                [charon_measured(self_.collectionViewLayout) removeAllObjects];
            reloadOriginal(self_, @selector(reloadData));
        }), method_getTypeEncoding(reload));
    });
}

static void charon_install_layout_hooks(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class flow = [UICollectionViewFlowLayout class];
        Method prepare = class_getInstanceMethod(flow, @selector(prepareLayout));
        void (*prepareOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(prepare);
        class_replaceMethod(flow, @selector(prepareLayout), imp_implementationWithBlock(^(UICollectionViewFlowLayout *self_) {
            prepareOriginal(self_, @selector(prepareLayout));
            if (!charon_active(self_))
                return;
            CGFloat width = self_.collectionView.bounds.size.width;
            NSNumber *last = objc_getAssociatedObject(self_, &charon_width_key);
            if (last && fabs(last.doubleValue - width) > 0.001)
                [charon_measured(self_) removeAllObjects];
            objc_setAssociatedObject(self_, &charon_width_key, @(width), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            charon_build(self_);
        }), method_getTypeEncoding(prepare));

        Method content = class_getInstanceMethod(flow, @selector(collectionViewContentSize));
        CGSize (*contentOriginal)(id, SEL) = (CGSize (*)(id, SEL))method_getImplementation(content);
        class_replaceMethod(flow, @selector(collectionViewContentSize), imp_implementationWithBlock(^CGSize(UICollectionViewFlowLayout *self_) {
            if (charon_active(self_) && charon_model(self_))
                return charon_model(self_).content;
            return contentOriginal(self_, @selector(collectionViewContentSize));
        }), method_getTypeEncoding(content));

        Method rectMethod = class_getInstanceMethod(flow, @selector(layoutAttributesForElementsInRect:));
        NSArray *(*rectOriginal)(id, SEL, CGRect) = (NSArray * (*)(id, SEL, CGRect))method_getImplementation(rectMethod);
        class_replaceMethod(flow, @selector(layoutAttributesForElementsInRect:), imp_implementationWithBlock(^NSArray *(UICollectionViewFlowLayout *self_, CGRect rect) {
            CharonFlowModel *model = charon_model(self_);
            if (!charon_active(self_) || !model)
                return rectOriginal(self_, @selector(layoutAttributesForElementsInRect:), rect);
            NSMutableArray *result = [NSMutableArray array];
            for (NSDictionary *group in @[model.headers, model.items, model.footers]) {
                NSArray *keys = [group.allKeys sortedArrayUsingSelector:@selector(compare:)];
                for (NSIndexPath *key in keys) {
                    UICollectionViewLayoutAttributes *attributes = group[key];
                    if (CGRectIntersectsRect(rect, attributes.frame))
                        [result addObject:[attributes copy]];
                }
            }
            return result;
        }), method_getTypeEncoding(rectMethod));

        Method itemMethod = class_getInstanceMethod(flow, @selector(layoutAttributesForItemAtIndexPath:));
        id (*itemOriginal)(id, SEL, id) = (id (*)(id, SEL, id))method_getImplementation(itemMethod);
        class_replaceMethod(flow, @selector(layoutAttributesForItemAtIndexPath:), imp_implementationWithBlock(^id(UICollectionViewFlowLayout *self_, NSIndexPath *path) {
            CharonFlowModel *model = charon_model(self_);
            if (!charon_active(self_) || !model)
                return itemOriginal(self_, @selector(layoutAttributesForItemAtIndexPath:), path);
            return [model.items[path] copy];
        }), method_getTypeEncoding(itemMethod));

        Method supplementaryMethod = class_getInstanceMethod(flow, @selector(layoutAttributesForSupplementaryViewOfKind:atIndexPath:));
        id (*supplementaryOriginal)(id, SEL, id, id) = (id (*)(id, SEL, id, id))method_getImplementation(supplementaryMethod);
        class_replaceMethod(flow, @selector(layoutAttributesForSupplementaryViewOfKind:atIndexPath:), imp_implementationWithBlock(^id(UICollectionViewFlowLayout *self_, NSString *kind, NSIndexPath *path) {
            CharonFlowModel *model = charon_model(self_);
            if (!charon_active(self_) || !model)
                return supplementaryOriginal(self_, @selector(layoutAttributesForSupplementaryViewOfKind:atIndexPath:), kind, path);
            NSIndexPath *key = [NSIndexPath indexPathForItem:0 inSection:path.section];
            return [([kind isEqualToString:UICollectionElementKindSectionHeader] ? model.headers : model.footers)[key] copy];
        }), method_getTypeEncoding(supplementaryMethod));

        Method bounds = class_getInstanceMethod(flow, @selector(shouldInvalidateLayoutForBoundsChange:));
        BOOL (*boundsOriginal)(id, SEL, CGRect) = (BOOL (*)(id, SEL, CGRect))method_getImplementation(bounds);
        class_replaceMethod(flow, @selector(shouldInvalidateLayoutForBoundsChange:), imp_implementationWithBlock(^BOOL(UICollectionViewFlowLayout *self_, CGRect newBounds) {
            if (charon_active(self_) && fabs(newBounds.size.width - self_.collectionView.bounds.size.width) > 0.001)
                return YES;
            return boundsOriginal(self_, @selector(shouldInvalidateLayoutForBoundsChange:), newBounds);
        }), method_getTypeEncoding(bounds));
    });
}
