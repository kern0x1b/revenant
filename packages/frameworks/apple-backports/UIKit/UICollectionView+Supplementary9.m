#import <UIKit/UIKit.h>

@implementation UICollectionView (RevenantSupplementary9)

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
    UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind
                                                                                             atIndexPath:indexPath];
    if (!attributes)
        return nil;
    for (UICollectionReusableView *view in [self visibleSupplementaryViewsOfKind:elementKind])
        if (CGRectEqualToRect(view.frame, attributes.frame))
            return view;
    return nil;
}

@end
