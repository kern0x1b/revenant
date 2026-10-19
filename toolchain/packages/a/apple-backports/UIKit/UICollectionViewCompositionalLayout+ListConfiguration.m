#import "RevenantLists.h"
#import <objc/runtime.h>

static const char RevenantListConfigurationKey;
static const char RevenantNotedSectionsKey;
static const char RevenantSectionConfigurationKey;

@implementation UICollectionViewCompositionalLayout (RevenantListState)

- (UICollectionLayoutListConfiguration *)revenant_listConfiguration
{
    return objc_getAssociatedObject(self, &RevenantListConfigurationKey);
}

- (void)revenant_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration
{
    objc_setAssociatedObject(self, &RevenantListConfigurationKey, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_beginNotingSections
{
    objc_setAssociatedObject(self, &RevenantNotedSectionsKey, [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)revenant_noteSection:(NSCollectionLayoutSection *)section
{
    NSMutableArray *noted = objc_getAssociatedObject(self, &RevenantNotedSectionsKey);
    [noted addObject:section ?: (id)[NSNull null]];
}

- (UICollectionLayoutListConfiguration *)revenant_listConfigurationForSectionIndex:(NSInteger)index
{
    NSArray *noted = objc_getAssociatedObject(self, &RevenantNotedSectionsKey);
    id section = index >= 0 && (NSUInteger)index < noted.count ? noted[(NSUInteger)index] : nil;
    UICollectionLayoutListConfiguration *own = [section isKindOfClass:[NSCollectionLayoutSection class]] ? [(NSCollectionLayoutSection *)section revenant_listConfiguration] : nil;
    return own ?: [self revenant_listConfiguration];
}

@end

@implementation NSCollectionLayoutSection (RevenantLists)

- (UICollectionLayoutListConfiguration *)revenant_listConfiguration
{
    return objc_getAssociatedObject(self, &RevenantSectionConfigurationKey);
}

- (void)revenant_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration
{
    objc_setAssociatedObject(self, &RevenantSectionConfigurationKey, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UICollectionViewCell (RevenantListConfigurationLookup)

- (UICollectionLayoutListConfiguration *)revenant_layoutListConfiguration
{
    UIView *candidate = self.superview;
    while (candidate && ![candidate isKindOfClass:[UICollectionView class]])
        candidate = candidate.superview;
    UICollectionView *view = (UICollectionView *)candidate;
    UICollectionViewLayout *layout = view.collectionViewLayout;
    if (![layout isKindOfClass:[UICollectionViewCompositionalLayout class]])
        return nil;
    NSIndexPath *path = [view indexPathForCell:self];
    return [(UICollectionViewCompositionalLayout *)layout revenant_listConfigurationForSectionIndex:path ? path.section : 0];
}

@end
