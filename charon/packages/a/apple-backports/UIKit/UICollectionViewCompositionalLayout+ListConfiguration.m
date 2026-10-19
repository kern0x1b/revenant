#import "CharonLists.h"
#import <objc/runtime.h>

static const char CharonListConfigurationKey;
static const char CharonNotedSectionsKey;
static const char CharonSectionConfigurationKey;

@implementation UICollectionViewCompositionalLayout (CharonListState)

- (UICollectionLayoutListConfiguration *)charon_listConfiguration
{
    return objc_getAssociatedObject(self, &CharonListConfigurationKey);
}

- (void)charon_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration
{
    objc_setAssociatedObject(self, &CharonListConfigurationKey, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_beginNotingSections
{
    objc_setAssociatedObject(self, &CharonNotedSectionsKey, [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_noteSection:(NSCollectionLayoutSection *)section
{
    NSMutableArray *noted = objc_getAssociatedObject(self, &CharonNotedSectionsKey);
    [noted addObject:section ?: (id)[NSNull null]];
}

- (UICollectionLayoutListConfiguration *)charon_listConfigurationForSectionIndex:(NSInteger)index
{
    NSArray *noted = objc_getAssociatedObject(self, &CharonNotedSectionsKey);
    id section = index >= 0 && (NSUInteger)index < noted.count ? noted[(NSUInteger)index] : nil;
    UICollectionLayoutListConfiguration *own = [section isKindOfClass:[NSCollectionLayoutSection class]] ? [(NSCollectionLayoutSection *)section charon_listConfiguration] : nil;
    return own ?: [self charon_listConfiguration];
}

@end

@implementation NSCollectionLayoutSection (CharonLists)

- (UICollectionLayoutListConfiguration *)charon_listConfiguration
{
    return objc_getAssociatedObject(self, &CharonSectionConfigurationKey);
}

- (void)charon_setListConfiguration:(UICollectionLayoutListConfiguration *)configuration
{
    objc_setAssociatedObject(self, &CharonSectionConfigurationKey, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UICollectionViewCell (CharonListConfigurationLookup)

- (UICollectionLayoutListConfiguration *)charon_layoutListConfiguration
{
    UIView *candidate = self.superview;
    while (candidate && ![candidate isKindOfClass:[UICollectionView class]])
        candidate = candidate.superview;
    UICollectionView *view = (UICollectionView *)candidate;
    UICollectionViewLayout *layout = view.collectionViewLayout;
    if (![layout isKindOfClass:[UICollectionViewCompositionalLayout class]])
        return nil;
    NSIndexPath *path = [view indexPathForCell:self];
    return [(UICollectionViewCompositionalLayout *)layout charon_listConfigurationForSectionIndex:path ? path.section : 0];
}

@end
