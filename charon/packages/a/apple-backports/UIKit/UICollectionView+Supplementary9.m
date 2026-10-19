#import <UIKit/UIKit.h>

// The supplementary views a collection view has on screen. The release's collection view lays
// supplementary views out and draws them, but never answers which of them are on screen, so an
// application that scrolls a section header away and then reads it back has nothing to read. The
// answer is built from the layout rather than from a list the view kept: the elements of that kind
// the layout draws in the visible rect, in the order it draws them, and the one at an index path is
// the element of that kind at that path, which is nil when the layout draws none there.
@implementation UICollectionView (CharonSupplementary9)

- (NSArray<NSIndexPath *> *)indexPathsForVisibleSupplementaryElementsOfKind:(NSString *)elementKind
{
    if (!elementKind)
        return @[];
    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    NSMutableSet<NSIndexPath *> *seen = [NSMutableSet set];
    for (UICollectionViewLayoutAttributes *attributes in [self.collectionViewLayout layoutAttributesForElementsInRect:self.bounds]) {
        if (![attributes.representedElementKind isEqualToString:elementKind])
            continue;
        NSIndexPath *path = attributes.indexPath;
        if (!path || [seen containsObject:path])
            continue;
        [seen addObject:path];
        [paths addObject:path];
    }
    return paths;
}

- (NSArray<UICollectionReusableView *> *)visibleSupplementaryViewsOfKind:(NSString *)elementKind
{
    if (!elementKind)
        return @[];
    NSMutableArray<UICollectionReusableView *> *views = [NSMutableArray array];
    for (NSIndexPath *path in [self indexPathsForVisibleSupplementaryElementsOfKind:elementKind]) {
        UICollectionReusableView *view = [self supplementaryViewForElementKind:elementKind atIndexPath:path];
        if (view)
            [views addObject:view];
    }
    return views;
}

- (UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if (!elementKind || !indexPath)
        return nil;
    // The layout is asked first: it is what decides whether there is a supplementary view of that
    // kind at that path at all, and a view that is not laid out is not on screen whatever the view
    // might still be holding.
    UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                                             atIndexPath:indexPath];
    if (!attributes)
        return nil;
    // Of the views of that kind the collection view holds, the one the layout draws at this path.
    for (UICollectionReusableView *view in [self visibleSupplementaryViewsOfKind:elementKind])
        if (CGRectEqualToRect(view.frame, attributes.frame))
            return view;
    return nil;
}

@end
