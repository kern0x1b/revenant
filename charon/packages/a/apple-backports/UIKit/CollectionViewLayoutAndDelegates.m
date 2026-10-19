#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The rest of what a collection view and a table view ask their layout, their controller and their
// delegate between iOS 7.0 and 12.0, where the release's own UIKit never asks.
//
// The defaults are the host's, measured in tests/backports/host/uikitscroll and not assumed: both of
// the flow layout's pinning flags are NO, `useLayoutToLayoutNavigationTransitions` is NO and
// `installsStandardGestureForInteractiveMovement` is YES, and a layout attribute's `bounds` is a real
// property beside `frame` where setting the frame moves the bounds' size and leaves its origin at
// zero.
static const char CharonHeadersPinKey;
static const char CharonFootersPinKey;
static const char CharonUseLayoutToLayoutKey;
static const char CharonInstallsGestureKey;

// The questions a collection view asks its delegate before it puts a cell on screen, and the three a
// table view asks about a height it does not have yet. The release asks none of them, so an
// application that answered them was never called.
@implementation UICollectionViewLayoutAttributes (CharonBounds7)

// bounds beside frame: the origin is the frame's and the size is the element's, and setting the frame
// moves the size without moving the origin, which is what the host answers.
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

// The layout the controller's collection view is using. It is the view's own layout, so a controller
// that is given one and a controller whose view makes one answer the same thing.
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
    // The host answers YES for a controller made by hand, so the flag is on until it is turned off.
    NSNumber *stored = objc_getAssociatedObject(self, &CharonInstallsGestureKey);
    return stored ? stored.boolValue : YES;
}

- (void)setInstallsStandardGestureForInteractiveMovement:(BOOL)installs
{
    objc_setAssociatedObject(self, &CharonInstallsGestureKey, @(installs), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

// Declared here because the installer's +load runs before this category is attached.
@interface UICollectionView (CharonDelegateQuestions9)
- (void)charon_tellDelegateAboutVisibleElements;
- (void)charon_tellDelegateWillDisplayIndexPath:(NSIndexPath *)indexPath;
- (void)charon_tellDelegateWillDisplaySupplementaryIndexPath:(NSIndexPath *)indexPath ofKind:(NSString *)kind;
- (CGPoint)charon_targetContentOffsetForProposedContentOffset:(CGPoint)proposed;
@end

// The call site: the layout pass that puts an element on screen. The implementation already there is
// captured and called, so this composes with any other wrap of the same method whichever order the
// two are installed in, instead of replacing it.
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

// Every element now on screen is told to the delegate once, and only once: the ones told are
// remembered, so a layout pass that runs again for the same cell does not ask a second time, which
// is what a delegate that configures a cell would notice.
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

// The offset a collection view should come to rest at. The layout is asked first, as it is on a
// release that has the question, and the delegate is asked after it so it keeps the last word.
- (CGPoint)charon_targetContentOffsetForProposedContentOffset:(CGPoint)proposed
{
    CGPoint target = [self.collectionViewLayout targetContentOffsetForProposedContentOffset:proposed];
    id delegate = self.delegate;
    SEL ask = @selector(collectionView:targetContentOffsetForProposedContentOffset:);
    if ([delegate respondsToSelector:ask])
        target = ((CGPoint (*)(id, SEL, id, CGPoint))objc_msgSend)(delegate, ask, self, proposed);
    return target;
}

// A cell is about to be shown, and a supplementary view with it. The release asks for neither, so an
// application that implemented them to lay a cell out as it arrives was never called; here it is,
// once per element, from the layout pass that puts the element on screen.
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

// A table view asks its delegate for an estimated height when it needs to know how far away a row is
// before it has drawn it: for scrolling, and for deciding what is about to come on screen. The
// release has no estimation of its own, so the port asks, and these are the three questions it asks.
//
// Where the port uses the answer is its own prefetch geometry in UITableView+Prefetching10.m, which
// needs to know how many rows are about to appear; that is a real use and the release's own
// scrolling does not consult the questions, which is the one thing about them this port cannot give.
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
