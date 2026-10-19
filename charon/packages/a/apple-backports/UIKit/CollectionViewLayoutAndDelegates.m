#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char CharonHeadersPinKey;
static const char CharonFootersPinKey;
static const char CharonUseLayoutToLayoutKey;
static const char CharonInstallsGestureKey;

@implementation UICollectionViewLayoutAttributes (CharonBounds7)

- (CGRect)bounds
{
    return CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
}

- (void)setBounds:(CGRect)bounds
{
    CGRect frame = self.frame;
    frame.size = bounds.size;
    self.frame = frame;
}

@end

@implementation UICollectionViewFlowLayout (CharonPinning9)

- (BOOL)sectionHeadersPinToVisibleBounds
{
    return [objc_getAssociatedObject(self, &CharonHeadersPinKey) boolValue];
}

- (void)setSectionHeadersPinToVisibleBounds:(BOOL)pins
{
    objc_setAssociatedObject(self, &CharonHeadersPinKey, @(pins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self invalidateLayout];
}

- (BOOL)sectionFootersPinToVisibleBounds
{
    return [objc_getAssociatedObject(self, &CharonFootersPinKey) boolValue];
}

- (void)setSectionFootersPinToVisibleBounds:(BOOL)pins
{
    objc_setAssociatedObject(self, &CharonFootersPinKey, @(pins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self invalidateLayout];
}

@end

@implementation UICollectionViewController (CharonController7)

- (UICollectionViewLayout *)collectionViewLayout
{
    return self.collectionView.collectionViewLayout;
}

- (void)setCollectionViewLayout:(UICollectionViewLayout *)collectionViewLayout
{
    self.collectionView.collectionViewLayout = collectionViewLayout;
}

- (BOOL)useLayoutToLayoutNavigationTransitions
{
    return [objc_getAssociatedObject(self, &CharonUseLayoutToLayoutKey) boolValue];
}

- (void)setUseLayoutToLayoutNavigationTransitions:(BOOL)uses
{
    objc_setAssociatedObject(self, &CharonUseLayoutToLayoutKey, @(uses), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)installsStandardGestureForInteractiveMovement
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonInstallsGestureKey);
    return stored ? stored.boolValue : YES;
}

- (void)setInstallsStandardGestureForInteractiveMovement:(BOOL)installs
{
    objc_setAssociatedObject(self, &CharonInstallsGestureKey, @(installs), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface UICollectionView (CharonDelegateQuestions9)
- (void)charon_tellDelegateAboutVisibleElements;
- (void)charon_tellDelegateWillDisplayIndexPath:(NSIndexPath *)indexPath;
- (void)charon_tellDelegateWillDisplaySupplementaryIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind;
- (CGPoint)charon_targetContentOffsetForProposedContentOffset:(CGPoint)proposed;
@end

@interface CharonCollectionViewDelegateInstaller : NSObject
@end

@implementation CharonCollectionViewDelegateInstaller

+ (void)load
{
    Class view = [UICollectionView class];
    Method layout = class_getInstanceMethod(view, @selector(layoutSubviews));
    void (*previous)(id, SEL) = (void (*)(id, SEL))method_getImplementation(layout);
    class_replaceMethod(view, @selector(layoutSubviews), imp_implementationWithBlock(^(UICollectionView *self_) {
        previous(self_, @selector(layoutSubviews));
        [self_ charon_tellDelegateAboutVisibleElements];
    }), method_getTypeEncoding(layout));
}

@end

@implementation UICollectionView (CharonDelegateQuestions9)

- (void)charon_tellDelegateAboutVisibleElements
{
    static const char toldKey;
    NSMutableSet *told = objc_getAssociatedObject(self, &toldKey);
    if (!told) {
        told = [NSMutableSet set];
        objc_setAssociatedObject(self, &toldKey, told, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (NSIndexPath *indexPath in self.indexPathsForVisibleItems) {
        if ([told containsObject:indexPath])
            continue;
        [told addObject:indexPath];
        [self charon_tellDelegateWillDisplayIndexPath:indexPath];
    }
    for (NSString *kind in @[UICollectionElementKindSectionHeader, UICollectionElementKindSectionFooter]) {
        for (NSIndexPath *indexPath in [self indexPathsForVisibleSupplementaryElementsOfKind:kind]) {
            NSString *key = [NSString stringWithFormat:@"%@|%@", kind, indexPath];
            if ([told containsObject:key])
                continue;
            [told addObject:key];
            [self charon_tellDelegateWillDisplaySupplementaryIndexPath:indexPath ofKind:kind];
        }
    }
}

- (CGPoint)charon_targetContentOffsetForProposedContentOffset:(CGPoint)proposed
{
    CGPoint target = [self.collectionViewLayout targetContentOffsetForProposedContentOffset:proposed];
    id delegate = self.delegate;
    SEL ask = @selector(collectionView:targetContentOffsetForProposedContentOffset:);
    if ([delegate respondsToSelector:ask])
        target = ((CGPoint (*)(id, SEL, id, CGPoint))objc_msgSend)(delegate, ask, self, proposed);
    return target;
}

- (void)charon_tellDelegateWillDisplayIndexPath:(NSIndexPath *)indexPath
{
    id delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(collectionView:willDisplayCell:forItemAtIndexPath:)])
        return;
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
    if (cell)
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, @selector(collectionView:willDisplayCell:forItemAtIndexPath:), self, indexPath, cell);
}

- (void)charon_tellDelegateWillDisplaySupplementaryIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind
{
    id delegate = self.delegate;
    SEL ask = @selector(collectionView:willDisplaySupplementaryView:forElementKind:atIndexPath:);
    if (!kind || ![delegate respondsToSelector:ask])
        return;
    UICollectionReusableView *view = [self supplementaryViewForElementKind:kind atIndexPath:indexPath];
    if (view)
        ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(delegate, ask, self, view, kind, indexPath);
}

@end

@interface UITableView (CharonEstimatedHeights7)
- (CGFloat)charon_estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)charon_estimatedHeightForHeaderInSection:(NSInteger)section;
- (CGFloat)charon_estimatedHeightForFooterInSection:(NSInteger)section;
@end

@implementation UITableView (CharonEstimatedHeights7)

- (CGFloat)charon_estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id delegate = self.delegate;
    SEL ask = @selector(tableView:estimatedHeightForRowAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return self.rowHeight;
    return ((CGFloat (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (CGFloat)charon_estimatedHeightForHeaderInSection:(NSInteger)section
{
    id delegate = self.delegate;
    SEL ask = @selector(tableView:estimatedHeightForHeaderInSection:);
    if (![delegate respondsToSelector:ask])
        return self.sectionHeaderHeight;
    return ((CGFloat (*)(id, SEL, id, NSInteger))objc_msgSend)(delegate, ask, self, section);
}

- (CGFloat)charon_estimatedHeightForFooterInSection:(NSInteger)section
{
    id delegate = self.delegate;
    SEL ask = @selector(tableView:estimatedHeightForFooterInSection:);
    if (![delegate respondsToSelector:ask])
        return self.sectionFooterHeight;
    return ((CGFloat (*)(id, SEL, id, NSInteger))objc_msgSend)(delegate, ask, self, section);
}

@end
