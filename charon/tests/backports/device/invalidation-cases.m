#import <UIKit/UIKit.h>
#import "invalidation-cases.h"

@interface InvalidationFlow : UICollectionViewFlowLayout
@property (nonatomic) int contexts;
@property (nonatomic) int invalidations;
@property (nonatomic, strong) UICollectionViewLayoutInvalidationContext *last;
@end

@implementation InvalidationFlow
- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    self.contexts++;
    self.last = context;
    [super invalidateLayoutWithContext:context];
}
- (void)invalidateLayout
{
    self.invalidations++;
    [super invalidateLayout];
}
@end

@interface InvalidationPlain : UICollectionViewLayout
@property (nonatomic) int contexts;
@property (nonatomic) int invalidations;
@end

@implementation InvalidationPlain
- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    self.contexts++;
    [super invalidateLayoutWithContext:context];
}
- (void)invalidateLayout
{
    self.invalidations++;
    [super invalidateLayout];
}
@end

static NSString *paths_text(NSArray *paths)
{
    if (!paths)
        return @"nil";
    NSMutableArray *found = [NSMutableArray array];
    for (NSIndexPath *path in paths)
        [found addObject:[NSString stringWithFormat:@"%ld-%ld", (long)path.section, (long)path.item]];
    return [found componentsJoinedByString:@","];
}

static NSString *kinds_text(NSDictionary *kinds)
{
    if (!kinds)
        return @"nil";
    NSMutableArray *found = [NSMutableArray array];
    for (NSString *kind in [kinds.allKeys sortedArrayUsingSelector:@selector(compare:)])
        [found addObject:[NSString stringWithFormat:@"%@=%@", kind, paths_text(kinds[kind])]];
    return [found componentsJoinedByString:@";"];
}

static NSString *context_text(UICollectionViewLayoutInvalidationContext *context)
{
    return [NSString stringWithFormat:@"%@ all=%d counts=%d items=%@ supp=%@ dec=%@ offset=%@ size=%@", NSStringFromClass([context class]), context.invalidateEverything, context.invalidateDataSourceCounts, paths_text(context.invalidatedItemIndexPaths), kinds_text(context.invalidatedSupplementaryIndexPaths), kinds_text(context.invalidatedDecorationIndexPaths), NSStringFromCGPoint(context.contentOffsetAdjustment), NSStringFromCGSize(context.contentSizeAdjustment)];
}

void invalidation_run(InvalidationRecorder record)
{
    UICollectionViewLayoutInvalidationContext *base = [[UICollectionViewLayoutInvalidationContext alloc] init];
    record(@"context.base", [NSString stringWithFormat:@"%@ super=%@", context_text(base), NSStringFromClass([base superclass])]);
    UICollectionViewFlowLayoutInvalidationContext *flow = [[UICollectionViewFlowLayoutInvalidationContext alloc] init];
    record(@"context.flow", [NSString stringWithFormat:@"%@ metrics=%d attributes=%d super=%@", context_text(flow), flow.invalidateFlowLayoutDelegateMetrics, flow.invalidateFlowLayoutAttributes, NSStringFromClass([flow superclass])]);
    flow.invalidateFlowLayoutAttributes = NO;
    flow.invalidateFlowLayoutDelegateMetrics = NO;
    record(@"context.flowSet", [NSString stringWithFormat:@"metrics=%d attributes=%d", flow.invalidateFlowLayoutDelegateMetrics, flow.invalidateFlowLayoutAttributes]);

    NSIndexPath *first = [NSIndexPath indexPathForItem:1 inSection:2];
    NSIndexPath *second = [NSIndexPath indexPathForItem:0 inSection:0];
    [base invalidateItemsAtIndexPaths:@[first, second]];
    [base invalidateItemsAtIndexPaths:@[second, first]];
    record(@"context.items", context_text(base));
    NSMutableArray *mutable = [NSMutableArray arrayWithObject:first];
    UICollectionViewLayoutInvalidationContext *held = [[UICollectionViewLayoutInvalidationContext alloc] init];
    [held invalidateItemsAtIndexPaths:mutable];
    [mutable addObject:second];
    record(@"context.itemsCopied", paths_text(held.invalidatedItemIndexPaths));
    [base invalidateSupplementaryElementsOfKind:@"Header" atIndexPaths:@[first]];
    [base invalidateSupplementaryElementsOfKind:@"Header" atIndexPaths:@[second, first]];
    [base invalidateSupplementaryElementsOfKind:@"Footer" atIndexPaths:@[second]];
    [base invalidateDecorationElementsOfKind:@"Rule" atIndexPaths:@[first]];
    record(@"context.kinds", context_text(base));
    base.contentOffsetAdjustment = CGPointMake(3, 4);
    base.contentSizeAdjustment = CGSizeMake(5, 6);
    record(@"context.adjustments", context_text(base));

    record(@"class.context", [NSString stringWithFormat:@"%@ %@", NSStringFromClass([UICollectionViewLayout invalidationContextClass]), NSStringFromClass([UICollectionViewFlowLayout invalidationContextClass])]);
    UICollectionViewFlowLayout *system = [[UICollectionViewFlowLayout alloc] init];
    record(@"layout.boundsFlow", context_text([system invalidationContextForBoundsChange:CGRectMake(0, 0, 10, 10)]));
    record(@"layout.boundsBase", context_text([[[UICollectionViewLayout alloc] init] invalidationContextForBoundsChange:CGRectMake(0, 0, 10, 10)]));

    InvalidationFlow *layout = [[InvalidationFlow alloc] init];
    [layout invalidateLayout];
    record(@"flow.invalidateLayout", [NSString stringWithFormat:@"contexts=%d invalidations=%d %@", layout.contexts, layout.invalidations, context_text(layout.last)]);
    [layout invalidateLayoutWithContext:[[UICollectionViewFlowLayoutInvalidationContext alloc] init]];
    record(@"flow.withContext", [NSString stringWithFormat:@"contexts=%d invalidations=%d", layout.contexts, layout.invalidations]);
    InvalidationPlain *plain = [[InvalidationPlain alloc] init];
    [plain invalidateLayout];
    record(@"plain.invalidateLayout", [NSString stringWithFormat:@"contexts=%d invalidations=%d", plain.contexts, plain.invalidations]);
    [plain invalidateLayoutWithContext:[[UICollectionViewLayoutInvalidationContext alloc] init]];
    record(@"plain.withContext", [NSString stringWithFormat:@"contexts=%d invalidations=%d", plain.contexts, plain.invalidations]);
    [system invalidateLayout];
    [system invalidateLayoutWithContext:[[UICollectionViewFlowLayoutInvalidationContext alloc] init]];
    record(@"system.survives", @"yes");
}
