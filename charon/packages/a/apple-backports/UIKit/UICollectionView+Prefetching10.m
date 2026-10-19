#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// Prefetching: as a collection view is about to bring items on screen it asks a prefetch data
// source for them before they are asked for as cells, and tells it when it has changed its mind.
// The release's collection view has no prefetching at all, so the port asks itself: after the view
// has laid out, the items just outside what is on screen are the candidates, ordered by how far
// they are from it, and the ones that were asked for last time and are no longer candidates are
// cancelled.
//
// A prefetch data source is held weakly, as the header says, and prefetching is off until it is
// both on and set, which is what the host's own UIKit does: measured under Mac Catalyst, a freshly
// made collection view answers NO for isPrefetchingEnabled and nil for the data source.
static const char CharonPrefetchDataSourceKey;
static const char CharonPrefetchEnabledKey;
static const char CharonPrefetchAskedKey;
static const NSUInteger CharonPrefetchDistance = 1;

// Declared here because the installer's +load runs before this category is attached, and it calls
// this on the view.
@interface UICollectionView (CharonPrefetching10)
- (void)charon_prefetch;
@end

@interface CharonPrefetchInstaller : NSObject
@end

@implementation CharonPrefetchInstaller

+ (void)load
{
    // Nothing to install where the release already prefetches.
    if ([UICollectionView instancesRespondToSelector:@selector(isPrefetchingEnabled)])
        return;
    [CharonPrefetchInstaller charon_install];
}

+ (void)charon_install
{
    // One message on the class, added here rather than by a category on the class itself, because
    // +load runs before the library's own categories are attached and a method added from a
    // category would not be there yet.
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

// The index paths the view would bring on screen next: the items just past what is on screen, on
// both sides, in the sections on screen. Ordered by their distance from the visible area, nearest
// first, which is the order the header asks the data source to receive them in.
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
                // One index path is one entry however many visible cells led to it.
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
    // What was asked for last time and is no longer a candidate is called off, so a data source
    // fetching images does not keep fetching the ones scrolled past.
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
