#import "CharonBarAppearance.h"

static const void *CharonStandardKey = &CharonStandardKey;
static const void *CharonCompactKey = &CharonCompactKey;
static const void *CharonScrollEdgeKey = &CharonScrollEdgeKey;
static const void *CharonActiveKey = &CharonActiveKey;
static const void *CharonAppliedKey = &CharonAppliedKey;
static const void *CharonPendingKey = &CharonPendingKey;

@interface UINavigationBar (CharonAppearances)
- (void)charon_standardChanged;
- (void)charon_applyAppearances;
@end

@implementation UINavigationBar (CharonAppearances)

- (UINavigationBarAppearance *)standardAppearance
{
    return charon_appearance_get(self, CharonStandardKey, [UINavigationBarAppearance class], @selector(charon_standardChanged));
}

- (void)setStandardAppearance:(UINavigationBarAppearance *)standardAppearance
{
    charon_appearance_set(self, CharonStandardKey, standardAppearance, @selector(charon_standardChanged));
    charon_flag_set(self, CharonActiveKey, standardAppearance != nil);
    [self charon_refreshForced:YES];
}

- (UINavigationBarAppearance *)compactAppearance
{
    return charon_appearance_peek(self, CharonCompactKey);
}

- (void)setCompactAppearance:(UINavigationBarAppearance *)compactAppearance
{
    charon_appearance_set(self, CharonCompactKey, compactAppearance, @selector(charon_otherChanged));
    [self charon_refreshForced:YES];
}

- (UINavigationBarAppearance *)scrollEdgeAppearance
{
    return charon_appearance_peek(self, CharonScrollEdgeKey);
}

- (void)setScrollEdgeAppearance:(UINavigationBarAppearance *)scrollEdgeAppearance
{
    charon_appearance_store_observed(self, CharonScrollEdgeKey, scrollEdgeAppearance, @selector(charon_otherChanged));
    [self charon_refreshForced:YES];
}

- (void)charon_standardChanged
{
    charon_flag_set(self, CharonActiveKey, YES);
    charon_schedule(self, @selector(charon_applyAppearances), CharonPendingKey);
}

- (void)charon_otherChanged
{
    charon_schedule(self, @selector(charon_applyAppearances), CharonPendingKey);
}

- (void)charon_applyAppearances
{
    [self charon_refreshForced:YES];
}

- (void)charon_refreshForced:(BOOL)force
{
    charon_track_bar(self);
    UINavigationItem *item = self.topItem;
    BOOL edge = charon_bar_at_edge(self, NO);
    BOOL modern = [self respondsToSelector:@selector(scrollEdgeAppearance)];
    UINavigationBarAppearance *own = charon_flag_get(self, CharonActiveKey) ? charon_appearance_peek(self, CharonStandardKey) : nil;
    UINavigationBarAppearance *compact = charon_appearance_peek(self, CharonCompactKey);
    UINavigationBarAppearance *scrollEdge = modern ? self.scrollEdgeAppearance : nil;
    UINavigationBarAppearance *compactScrollEdge = modern ? self.compactScrollEdgeAppearance : nil;
    UINavigationBarAppearance *itemStandard = item.standardAppearance, *itemCompact = item.compactAppearance;
    UINavigationBarAppearance *itemScrollEdge = modern ? item.scrollEdgeAppearance : nil, *itemCompactScrollEdge = modern ? item.compactScrollEdgeAppearance : nil;
    UINavigationBarAppearance *standard = edge ? charon_first_appearance(itemScrollEdge, scrollEdge, itemStandard, own, nil, nil) : charon_first_appearance(itemStandard, own, nil, nil, nil, nil);
    UINavigationBarAppearance *landscape = edge ? charon_first_appearance(itemCompactScrollEdge, compactScrollEdge, itemScrollEdge, scrollEdge, itemCompact, compact)
                                                : charon_first_appearance(itemCompact, compact, nil, nil, nil, nil);
    if (!standard && !landscape && !charon_flag_get(self, CharonAppliedKey))
        return;
    if (!charon_bar_needs_refresh(self, [NSString stringWithFormat:@"%p %p", standard, landscape]) && !force)
        return;
    charon_apply_navigation_bar(self, standard, landscape);
    charon_flag_set(self, CharonAppliedKey, standard || landscape);
}

@end
