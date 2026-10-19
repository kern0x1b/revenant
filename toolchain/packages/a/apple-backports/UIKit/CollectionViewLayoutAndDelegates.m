#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantHeadersPinKey;
static const char RevenantFootersPinKey;
static const char RevenantUseLayoutToLayoutKey;
static const char RevenantInstallsGestureKey;

@implementation UICollectionViewLayoutAttributes (RevenantBounds7)

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

@implementation UICollectionViewFlowLayout (RevenantPinning9)

- (BOOL)sectionHeadersPinToVisibleBounds
{
    return [objc_getAssociatedObject(self, &RevenantHeadersPinKey) boolValue];
}

- (void)setSectionHeadersPinToVisibleBounds:(BOOL)pins
{
    objc_setAssociatedObject(self, &RevenantHeadersPinKey, @(pins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self invalidateLayout];
}

- (BOOL)sectionFootersPinToVisibleBounds
{
    return [objc_getAssociatedObject(self, &RevenantFootersPinKey) boolValue];
}

- (void)setSectionFootersPinToVisibleBounds:(BOOL)pins
{
    objc_setAssociatedObject(self, &RevenantFootersPinKey, @(pins), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self invalidateLayout];
}

@end

@implementation UICollectionViewController (RevenantController7)

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
    return [objc_getAssociatedObject(self, &RevenantUseLayoutToLayoutKey) boolValue];
}

- (void)setUseLayoutToLayoutNavigationTransitions:(BOOL)uses
{
    objc_setAssociatedObject(self, &RevenantUseLayoutToLayoutKey, @(uses), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)installsStandardGestureForInteractiveMovement
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantInstallsGestureKey);
    return stored ? stored.boolValue : YES;
}

- (void)setInstallsStandardGestureForInteractiveMovement:(BOOL)installs
{
    objc_setAssociatedObject(self, &RevenantInstallsGestureKey, @(installs), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface UICollectionView (RevenantDelegateQuestions9)
- (void)revenant_tellDelegateAboutVisibleElements;
- (void)revenant_tellDelegateWillDisplayIndexPath:(NSIndexPath *)indexPath;
- (void)revenant_tellDelegateWillDisplaySupplementaryIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind;
- (CGPoint)revenant_targetContentOffsetForProposedContentOffset:(CGPoint)proposed;
@end

@interface RevenantCollectionViewDelegateInstaller : NSObject
@end

@implementation RevenantCollectionViewDelegateInstaller

+ (void)load
{
    Class view = [UICollectionView class];
    Method layout = class_getInstanceMethod(view, @selector(layoutSubviews));
    void (*previous)(id, SEL) = (void (*)(id, SEL))method_getImplementation(layout);
    class_replaceMethod(view, @selector(layoutSubviews), imp_implementationWithBlock(^(UICollectionView *self_) {
        previous(self_, @selector(layoutSubviews));
        [self_ revenant_tellDelegateAboutVisibleElements];
    }), method_getTypeEncoding(layout));
}

@end

@implementation UICollectionView (RevenantDelegateQuestions9)

- (void)revenant_tellDelegateAboutVisibleElements
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
        [self revenant_tellDelegateWillDisplayIndexPath:indexPath];
    }
    for (NSString *kind in @[UICollectionElementKindSectionHeader, UICollectionElementKindSectionFooter]) {
        for (NSIndexPath *indexPath in [self indexPathsForVisibleSupplementaryElementsOfKind:kind]) {
            NSString *key = [NSString stringWithFormat:@"%@|%@", kind, indexPath];
            if ([told containsObject:key])
                continue;
            [told addObject:key];
            [self revenant_tellDelegateWillDisplaySupplementaryIndexPath:indexPath ofKind:kind];
        }
    }
}

- (CGPoint)revenant_targetContentOffsetForProposedContentOffset:(CGPoint)proposed
{
    CGPoint target = [self.collectionViewLayout targetContentOffsetForProposedContentOffset:proposed];
    id delegate = self.delegate;
    SEL ask = @selector(collectionView:targetContentOffsetForProposedContentOffset:);
    if ([delegate respondsToSelector:ask])
        target = ((CGPoint (*)(id, SEL, id, CGPoint))objc_msgSend)(delegate, ask, self, proposed);
    return target;
}

- (void)revenant_tellDelegateWillDisplayIndexPath:(NSIndexPath *)indexPath
{
    id delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(collectionView:willDisplayCell:forItemAtIndexPath:)])
        return;
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
    if (cell)
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(delegate, @selector(collectionView:willDisplayCell:forItemAtIndexPath:), self, indexPath, cell);
}

- (void)revenant_tellDelegateWillDisplaySupplementaryIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind
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

@interface UITableView (RevenantEstimatedHeights7)
- (CGFloat)revenant_estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)revenant_estimatedHeightForHeaderInSection:(NSInteger)section;
- (CGFloat)revenant_estimatedHeightForFooterInSection:(NSInteger)section;
@end

@implementation UITableView (RevenantEstimatedHeights7)

- (CGFloat)revenant_estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id delegate = self.delegate;
    SEL ask = @selector(tableView:estimatedHeightForRowAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return self.rowHeight;
    return ((CGFloat (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (CGFloat)revenant_estimatedHeightForHeaderInSection:(NSInteger)section
{
    id delegate = self.delegate;
    SEL ask = @selector(tableView:estimatedHeightForHeaderInSection:);
    if (![delegate respondsToSelector:ask])
        return self.sectionHeaderHeight;
    return ((CGFloat (*)(id, SEL, id, NSInteger))objc_msgSend)(delegate, ask, self, section);
}

- (CGFloat)revenant_estimatedHeightForFooterInSection:(NSInteger)section
{
    id delegate = self.delegate;
    SEL ask = @selector(tableView:estimatedHeightForFooterInSection:);
    if (![delegate respondsToSelector:ask])
        return self.sectionFooterHeight;
    return ((CGFloat (*)(id, SEL, id, NSInteger))objc_msgSend)(delegate, ask, self, section);
}

@end
