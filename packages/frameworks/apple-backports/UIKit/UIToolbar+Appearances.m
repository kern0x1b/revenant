#import "RevenantBarAppearance.h"

static const void *RevenantStandardKey = &RevenantStandardKey;
static const void *RevenantCompactKey = &RevenantCompactKey;
static const void *RevenantActiveKey = &RevenantActiveKey;
static const void *RevenantAppliedKey = &RevenantAppliedKey;
static const void *RevenantPendingKey = &RevenantPendingKey;

@interface UIToolbar (RevenantAppearances)
- (void)revenant_standardChanged;
- (void)revenant_applyAppearances;
@end

@implementation UIToolbar (RevenantAppearances)

- (UIToolbarAppearance *)standardAppearance
{
    return revenant_appearance_get(self, RevenantStandardKey, [UIToolbarAppearance class], @selector(revenant_standardChanged));
}

- (void)setStandardAppearance:(UIToolbarAppearance *)standardAppearance
{
    revenant_appearance_set(self, RevenantStandardKey, standardAppearance, @selector(revenant_standardChanged));
    revenant_flag_set(self, RevenantActiveKey, standardAppearance != nil);
    [self revenant_refreshForced:YES];
}

- (UIToolbarAppearance *)compactAppearance
{
    return revenant_appearance_peek(self, RevenantCompactKey);
}

- (void)setCompactAppearance:(UIToolbarAppearance *)compactAppearance
{
    revenant_appearance_set(self, RevenantCompactKey, compactAppearance, @selector(revenant_otherChanged));
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
    BOOL edge = revenant_bar_at_edge(self, YES);
    BOOL modern = [self respondsToSelector:@selector(scrollEdgeAppearance)];
    UIToolbarAppearance *own = revenant_flag_get(self, RevenantActiveKey) ? revenant_appearance_peek(self, RevenantStandardKey) : nil;
    UIToolbarAppearance *compact = revenant_appearance_peek(self, RevenantCompactKey);
    UIToolbarAppearance *scrollEdge = modern ? self.scrollEdgeAppearance : nil, *compactScrollEdge = modern ? self.compactScrollEdgeAppearance : nil;
    UIToolbarAppearance *standard = edge ? revenant_first_appearance(scrollEdge, own, nil, nil, nil, nil) : own;
    UIToolbarAppearance *landscape = edge ? revenant_first_appearance(compactScrollEdge, scrollEdge, compact, nil, nil, nil) : compact;
    if (!standard && !landscape && !revenant_flag_get(self, RevenantAppliedKey))
        return;
    if (!revenant_bar_needs_refresh(self, [NSString stringWithFormat:@"%p %p", standard, landscape]) && !force)
        return;
    revenant_apply_toolbar(self, standard, landscape);
    revenant_flag_set(self, RevenantAppliedKey, standard || landscape);
}

@end
