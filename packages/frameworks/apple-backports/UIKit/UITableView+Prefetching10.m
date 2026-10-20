#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantTablePrefetchDataSourceKey;
static const char RevenantTablePrefetchAskedKey;
static const NSInteger RevenantTablePrefetchDistance = 3;

@interface UITableView (RevenantPrefetching10)
- (void)revenant_prefetchRows;
@end

@interface UITableView (RevenantEstimatedHeights7)
- (CGFloat)revenant_estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)revenant_estimatedHeightForHeaderInSection:(NSInteger)section;
- (CGFloat)revenant_estimatedHeightForFooterInSection:(NSInteger)section;
@end

@interface RevenantTablePrefetchInstaller : NSObject
@end

@implementation RevenantTablePrefetchInstaller

+ (void)load
{
    if ([UITableView instancesRespondToSelector:@selector(prefetchDataSource)])
        return;
    Class table = [UITableView class];
    IMP original = class_getMethodImplementation(table, @selector(layoutSubviews));
    if (!original)
        return;
    class_replaceMethod(table, @selector(layoutSubviews), imp_implementationWithBlock(^(UITableView *self_) {
        ((void (*)(id, SEL))original)(self_, @selector(layoutSubviews));
        [self_ revenant_prefetchRows];
    }), "crevenant_layoutSubviews");
}

@end

@implementation UITableView (RevenantPrefetching10)

- (id<UITableViewDataSourcePrefetching>)prefetchDataSource
{
    return objc_getAssociatedObject(self, &RevenantTablePrefetchDataSourceKey);
}

- (void)setPrefetchDataSource:(id<UITableViewDataSourcePrefetching>)prefetchDataSource
{
    objc_setAssociatedObject(self, &RevenantTablePrefetchDataSourceKey, prefetchDataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (NSArray<NSIndexPath *> *)revenant_prefetchRowCandidates
{
    NSArray<NSIndexPath *> *visible = self.indexPathsForVisibleRows;
    if (!visible.count)
        return @[];
    CGFloat rowHeight = [self revenant_estimatedHeightForRowAtIndexPath:visible.firstObject];
    if (rowHeight <= 0)
        rowHeight = self.rowHeight;
    CGFloat ahead = self.bounds.size.height;
    NSInteger reach = rowHeight > 0 ? (NSInteger)ceil(ahead / rowHeight) : RevenantTablePrefetchDistance;
    reach = MAX(1, MIN(reach, 20));
    NSMutableArray<NSIndexPath *> *candidates = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seen = [NSMutableSet set];
    NSMutableDictionary<NSNumber *, NSNumber *> *distance = [NSMutableDictionary dictionary];
    for (NSIndexPath *path in visible) {
        for (NSInteger step = 1; step <= reach; step++) {
            for (NSInteger direction = -1; direction <= 1; direction += 2) {
                NSInteger row = path.row + direction * step;
                if (row < 0 || row >= [self numberOfRowsInSection:path.section])
                    continue;
                NSIndexPath *candidate = [NSIndexPath indexPathForRow:row inSection:path.section];
                NSNumber *key = @(candidate.section * 1000000 + candidate.row);
                if ([seen containsObject:key])
                    continue;
                [seen addObject:key];
                [candidates addObject:candidate];
                distance[key] = @(step);
            }
        }
    }
    return [candidates sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
        NSComparisonResult byDistance = [distance[@(a.section * 1000000 + a.row)] compare:distance[@(b.section * 1000000 + b.row)]];
        if (byDistance != NSOrderedSame)
            return byDistance;
        if (a.section != b.section)
            return a.section < b.section ? NSOrderedAscending : NSOrderedDescending;
        return a.row < b.row ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)revenant_prefetchRows
{
    id<UITableViewDataSourcePrefetching> source = self.prefetchDataSource;
    if (!source)
        return;
    NSArray<NSIndexPath *> *candidates = [self revenant_prefetchRowCandidates];
    NSMutableSet<NSIndexPath *> *wants = [NSMutableSet setWithArray:candidates];
    NSMutableSet<NSIndexPath *> *asked = objc_getAssociatedObject(self, &RevenantTablePrefetchAskedKey);
    if (!asked) {
        asked = [NSMutableSet set];
        objc_setAssociatedObject(self, &RevenantTablePrefetchAskedKey, asked, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray<NSIndexPath *> *cancelled = [asked.allObjects filteredArrayUsingPredicate:
                                         [NSPredicate predicateWithBlock:^BOOL(NSIndexPath *path, NSDictionary *bindings) {
                                             return ![wants containsObject:path];
                                         }]];
    if (cancelled.count && [source respondsToSelector:@selector(tableView:cancelPrefetchingForRowsAtIndexPaths:)])
        [source tableView:self cancelPrefetchingForRowsAtIndexPaths:cancelled];
    [asked minusSet:[NSSet setWithArray:cancelled]];
    NSArray<NSIndexPath *> *fresh = [candidates filteredArrayUsingPredicate:
                                      [NSPredicate predicateWithBlock:^BOOL(NSIndexPath *path, NSDictionary *bindings) {
                                          return ![asked containsObject:path];
                                      }]];
    if (fresh.count && [source respondsToSelector:@selector(tableView:prefetchRowsAtIndexPaths:)])
        [source tableView:self prefetchRowsAtIndexPaths:fresh];
    [asked addObjectsFromArray:fresh];
}

@end
