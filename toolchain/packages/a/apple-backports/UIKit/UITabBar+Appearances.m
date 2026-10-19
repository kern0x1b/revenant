#import "CharonBarAppearance.h"

static const void *CharonStandardKey = &CharonStandardKey;
static const void *CharonActiveKey = &CharonActiveKey;
static const void *CharonAppliedKey = &CharonAppliedKey;
static const void *CharonPendingKey = &CharonPendingKey;

@interface UITabBar (CharonAppearances)
- (void)charon_standardChanged;
- (void)charon_applyAppearances;
@end

@implementation UITabBar (CharonAppearances)

- (UITabBarAppearance *)standardAppearance
{
    return charon_appearance_get(self, CharonStandardKey, [UITabBarAppearance class], @selector(charon_standardChanged));
}

- (void)setStandardAppearance:(UITabBarAppearance *)standardAppearance
{
    charon_appearance_set(self, CharonStandardKey, standardAppearance, @selector(charon_standardChanged));
    charon_flag_set(self, CharonActiveKey, standardAppearance != nil);
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
    UITabBarItem *item = self.selectedItem;
    BOOL edge = charon_bar_at_edge(self, YES);
    BOOL modern = [self respondsToSelector:@selector(scrollEdgeAppearance)];
    UITabBarAppearance *own = charon_flag_get(self, CharonActiveKey) ? charon_appearance_peek(self, CharonStandardKey) : nil;
    UITabBarAppearance *scrollEdge = modern ? self.scrollEdgeAppearance : nil, *itemScrollEdge = modern ? item.scrollEdgeAppearance : nil;
    UITabBarAppearance *itemStandard = item.standardAppearance;
    UITabBarAppearance *standard = edge ? charon_first_appearance(itemScrollEdge, scrollEdge, itemStandard, own, nil, nil) : charon_first_appearance(itemStandard, own, nil, nil, nil, nil);
    if (!standard && !charon_flag_get(self, CharonAppliedKey))
        return;
    if (!charon_bar_needs_refresh(self, [NSString stringWithFormat:@"%p", standard]) && !force)
        return;
    charon_apply_tab_bar(self, standard);
    charon_flag_set(self, CharonAppliedKey, standard != nil);
}

@end
