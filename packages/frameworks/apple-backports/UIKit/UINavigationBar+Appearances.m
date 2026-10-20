#import "RevenantBarAppearance.h"

static const void *RevenantStandardKey = &RevenantStandardKey;
static const void *RevenantCompactKey = &RevenantCompactKey;
static const void *RevenantScrollEdgeKey = &RevenantScrollEdgeKey;
static const void *RevenantActiveKey = &RevenantActiveKey;
static const void *RevenantAppliedKey = &RevenantAppliedKey;
static const void *RevenantPendingKey = &RevenantPendingKey;

@interface UINavigationBar (RevenantAppearances)
- (void)revenant_standardChanged;
- (void)revenant_applyAppearances;
@end

@implementation UINavigationBar (RevenantAppearances)

- (UINavigationBarAppearance *)standardAppearance
{
    return revenant_appearance_get(self, RevenantStandardKey, [UINavigationBarAppearance class], @selector(revenant_standardChanged));
}

- (void)setStandardAppearance:(UINavigationBarAppearance *)standardAppearance
{
    revenant_appearance_set(self, RevenantStandardKey, standardAppearance, @selector(revenant_standardChanged));
    revenant_flag_set(self, RevenantActiveKey, standardAppearance != nil);
    [self revenant_refreshForced:YES];
}

- (UINavigationBarAppearance *)compactAppearance
{
    return revenant_appearance_peek(self, RevenantCompactKey);
}

- (void)setCompactAppearance:(UINavigationBarAppearance *)compactAppearance
{
    revenant_appearance_set(self, RevenantCompactKey, compactAppearance, @selector(revenant_otherChanged));
    [self revenant_refreshForced:YES];
}

- (UINavigationBarAppearance *)scrollEdgeAppearance
{
    return revenant_appearance_peek(self, RevenantScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UINavigationBarAppearance *)scrollEdgeAppearance
{
    revenant_appearance_store_observed(self, RevenantScrollEdgeKey, scrollEdgeAppearance, @selector(revenant_otherChanged));
    [self revenant_refreshForced:YES];
}

- (void)revenant_standardChanged
{
    revenant_flag_set(self, RevenantActiveKey, YES);
    revenant_schedule(self, @selector(revenant_applyAppearances), RevenantPendingKey);
}

- (void)revenant_otherChanged
{
    revenant_schedule(self, @selector(revenant_applyAppearances), RevenantPendingKey);
}

- (void)revenant_applyAppearances
{
    [self revenant_refreshForced:YES];
}

- (void)revenant_refreshForced:(BOOL)force
{
    revenant_track_bar(self);
    UINavigationItem *item = self.topItem;
    BOOL edge = revenant_bar_at_edge(self, NO);
    BOOL modern = [self respondsToSelector:@selector(scrollEdgeAppearance)];
    UINavigationBarAppearance *own = revenant_flag_get(self, RevenantActiveKey) ? revenant_appearance_peek(self, RevenantStandardKey) : nil;
    UINavigationBarAppearance *compact = revenant_appearance_peek(self, RevenantCompactKey);
    UINavigationBarAppearance *scrollEdge = modern ? self.scrollEdgeAppearance : nil;
    UINavigationBarAppearance *compactScrollEdge = modern ? self.compactScrollEdgeAppearance : nil;
    UINavigationBarAppearance *itemStandard = item.standardAppearance, *itemCompact = item.compactAppearance;
    UINavigationBarAppearance *itemScrollEdge = modern ? item.scrollEdgeAppearance : nil, *itemCompactScrollEdge = modern ? item.compactScrollEdgeAppearance : nil;
    UINavigationBarAppearance *standard = edge ? revenant_first_appearance(itemScrollEdge, scrollEdge, itemStandard, own, nil, nil) : revenant_first_appearance(itemStandard, own, nil, nil, nil, nil);
    UINavigationBarAppearance *landscape = edge ? revenant_first_appearance(itemCompactScrollEdge, compactScrollEdge, itemScrollEdge, scrollEdge, itemCompact, compact)
                                                : revenant_first_appearance(itemCompact, compact, nil, nil, nil, nil);
    if (!standard && !landscape && !revenant_flag_get(self, RevenantAppliedKey))
        return;
    if (!revenant_bar_needs_refresh(self, [NSString stringWithFormat:@"%p %p", standard, landscape]) && !force)
        return;
    revenant_apply_navigation_bar(self, standard, landscape);
    revenant_flag_set(self, RevenantAppliedKey, standard || landscape);
}

@end
