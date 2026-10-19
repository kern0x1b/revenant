#import "RevenantBarAppearance.h"

static const void *RevenantStandardKey = &RevenantStandardKey;
static const void *RevenantActiveKey = &RevenantActiveKey;
static const void *RevenantAppliedKey = &RevenantAppliedKey;
static const void *RevenantPendingKey = &RevenantPendingKey;

@interface UITabBar (RevenantAppearances)
- (void)revenant_standardChanged;
- (void)revenant_applyAppearances;
@end

@implementation UITabBar (RevenantAppearances)

- (UITabBarAppearance *)standardAppearance
{
    return revenant_appearance_get(self, RevenantStandardKey, [UITabBarAppearance class], @selector(revenant_standardChanged));
}

- (void)setStandardAppearance:(UITabBarAppearance *)standardAppearance
{
    revenant_appearance_set(self, RevenantStandardKey, standardAppearance, @selector(revenant_standardChanged));
    revenant_flag_set(self, RevenantActiveKey, standardAppearance != nil);
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
    UITabBarItem *item = self.selectedItem;
    BOOL edge = revenant_bar_at_edge(self, YES);
    BOOL modern = [self respondsToSelector:@selector(scrollEdgeAppearance)];
    UITabBarAppearance *own = revenant_flag_get(self, RevenantActiveKey) ? revenant_appearance_peek(self, RevenantStandardKey) : nil;
    UITabBarAppearance *scrollEdge = modern ? self.scrollEdgeAppearance : nil, *itemScrollEdge = modern ? item.scrollEdgeAppearance : nil;
    UITabBarAppearance *itemStandard = item.standardAppearance;
    UITabBarAppearance *standard = edge ? revenant_first_appearance(itemScrollEdge, scrollEdge, itemStandard, own, nil, nil) : revenant_first_appearance(itemStandard, own, nil, nil, nil, nil);
    if (!standard && !revenant_flag_get(self, RevenantAppliedKey))
        return;
    if (!revenant_bar_needs_refresh(self, [NSString stringWithFormat:@"%p", standard]) && !force)
        return;
    revenant_apply_tab_bar(self, standard);
    revenant_flag_set(self, RevenantAppliedKey, standard != nil);
}

@end
