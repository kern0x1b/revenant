#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char CharonPrefetchDataSourceKey;
static const char CharonPrefetchEnabledKey;
static const char CharonPrefetchAskedKey;
static const NSUInteger CharonPrefetchDistance = 1;

@interface UICollectionView (CharonPrefetching10)
- (void)charon_prefetch;
@end

@interface CharonPrefetchInstaller : NSObject
@end

@implementation CharonPrefetchInstaller

+ (void)load
{
    if ([UICollectionView instancesRespondToSelector:@selector(isPrefetchingEnabled)])
        return;
    [CharonPrefetchInstaller charon_install];
}

+ (void)charon_install
{
    Class view = [UICollectionView class];
    IMP original = class_getMethodImplementation(view, @selector(layoutSubviews));
    if (!original)
        return;
    class_replaceMethod(view, @selector(layoutSubviews), imp_implementationWithBlock(^(UICollectionView *self_) {
        ((void (*)(id, SEL))original)(self_, @selector(layoutSubviews));
        [self_ charon_prefetch];
    }), "ccharon_layoutSubviews");
}

@end

@implementation UICollectionView (CharonPrefetching10)

- (id<UICollectionViewDataSourcePrefetching>)prefetchDataSource
{
    return objc_getAssociatedObject(self, &CharonPrefetchDataSourceKey);
}

- (void)setPrefetchDataSource:(id<UICollectionViewDataSourcePrefetching>)prefetchDataSource
{
    objc_setAssociatedObject(self, &CharonPrefetchDataSourceKey, prefetchDataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)isPrefetchingEnabled
{
    return [objc_getAssociatedObject(self, &CharonPrefetchEnabledKey) boolValue];
}

- (void)setPrefetchingEnabled:(BOOL)prefetchingEnabled
{
    objc_setAssociatedObject(self, &CharonPrefetchEnabledKey, @(prefetchingEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSIndexPath *> *)charon_prefetchCandidates
{
    NSArray<NSIndexPath *> *visible = self.indexPathsForVisibleItems;
    if (!visible.count)
        return @[];
    NSMutableArray<NSIndexPath *> *candidates = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];
    NSMutableDictionary<NSNumber *, NSNumber *> *distance = [NSMutableDictionary dictionary];
    for (NSIndexPath *path in visible) {
        for (NSInteger step = 1; step <= (NSInteger)CharonPrefetchDistance; step++) {
            for (NSInteger direction = -1; direction <= 1; direction += 2) {
                NSInteger item = path.item + direction * step;
                if (item < 0 || item >= [self numberOfItemsInSection:path.section])
                    continue;
                NSIndexPath *candidate = [NSIndexPath indexPathForItem:item inSection:path.section];
                NSNumber *key = @(candidate.section * 1000000 + candidate.item);
                if ([seen containsObject:key])
                    continue;
                [seen addObject:key];
                [candidates addObject:candidate];
                distance[key] = @(step);
            }
        }
    }
    return [candidates sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
        NSNumber *da = distance[@(a.section * 1000000 + a.item)], *db = distance[@(b.section * 1000000 + b.item)];
        NSComparisonResult byDistance = [da compare:db];
        if (byDistance != NSOrderedSame)
            return byDistance;
        if (a.section != b.section)
            return a.section < b.section ? NSOrderedAscending : NSOrderedDescending;
        return a.item < b.item ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)charon_prefetch
{
    id<UICollectionViewDataSourcePrefetching> source = self.prefetchDataSource;
    if (!source || !self.isPrefetchingEnabled)
        return;
    NSArray<NSIndexPath *> *candidates = [self charon_prefetchCandidates];
    NSMutableSet<NSIndexPath *> *wants = [NSMutableSet setWithArray:candidates];
    NSMutableSet<NSIndexPath *> *asked = objc_getAssociatedObject(self, &CharonPrefetchAskedKey);
    if (!asked) {
        asked = [NSMutableSet set];
        objc_setAssociatedObject(self, &CharonPrefetchAskedKey, asked, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray<NSIndexPath *> *cancelled = [asked.allObjects filteredArrayUsingPredicate:
                                         [NSPredicate predicateWithBlock:^BOOL(NSIndexPath *path, NSDictionary *bindings) {
                                             return ![wants containsObject:path];
                                         }]];
    if (cancelled.count && [source respondsToSelector:@selector(collectionView:cancelPrefetchingForItemsAtIndexPaths:)])
        [source collectionView:self cancelPrefetchingForItemsAtIndexPaths:cancelled];
    [asked minusSet:[NSSet setWithArray:cancelled]];
    NSArray<NSIndexPath *> *fresh = [candidates filteredArrayUsingPredicate:
                                      [NSPredicate predicateWithBlock:^BOOL(NSIndexPath *path, NSDictionary *bindings) {
                                          return ![asked containsObject:path];
                                      }]];
    if (fresh.count && [source respondsToSelector:@selector(collectionView:prefetchItemsAtIndexPaths:)])
        [source collectionView:self prefetchItemsAtIndexPaths:fresh];
    [asked addObjectsFromArray:fresh];
}

@end
