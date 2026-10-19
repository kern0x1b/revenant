#import "CharonBarAppearance.h"

static const void *CharonStandardKey = &CharonStandardKey;
static const void *CharonCompactKey = &CharonCompactKey;
static const void *CharonActiveKey = &CharonActiveKey;
static const void *CharonAppliedKey = &CharonAppliedKey;
static const void *CharonPendingKey = &CharonPendingKey;

@interface UIToolbar (CharonAppearances)
- (void)charon_standardChanged;
- (void)charon_applyAppearances;
@end

@implementation UIToolbar (CharonAppearances)

- (UIToolbarAppearance *)standardAppearance
{
    return charon_appearance_get(self, CharonStandardKey, [UIToolbarAppearance class], @selector(charon_standardChanged));
}

- (void)setStandardAppearance:(UIToolbarAppearance *)standardAppearance
{
    charon_appearance_set(self, CharonStandardKey, standardAppearance, @selector(charon_standardChanged));
    charon_flag_set(self, CharonActiveKey, standardAppearance != nil);
    [self charon_refreshForced:YES];
}

- (UIToolbarAppearance *)compactAppearance
{
    return charon_appearance_peek(self, CharonCompactKey);
}

- (void)setCompactAppearance:(UIToolbarAppearance *)compactAppearance
{
    charon_appearance_set(self, CharonCompactKey, compactAppearance, @selector(charon_otherChanged));
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
    BOOL edge = charon_bar_at_edge(self, YES);
    BOOL modern = [self respondsToSelector:@selector(scrollEdgeAppearance)];
    UIToolbarAppearance *own = charon_flag_get(self, CharonActiveKey) ? charon_appearance_peek(self, CharonStandardKey) : nil;
    UIToolbarAppearance *compact = charon_appearance_peek(self, CharonCompactKey);
    UIToolbarAppearance *scrollEdge = modern ? self.scrollEdgeAppearance : nil, *compactScrollEdge = modern ? self.compactScrollEdgeAppearance : nil;
    UIToolbarAppearance *standard = edge ? charon_first_appearance(scrollEdge, own, nil, nil, nil, nil) : own;
    UIToolbarAppearance *landscape = edge ? charon_first_appearance(compactScrollEdge, scrollEdge, compact, nil, nil, nil) : compact;
    if (!standard && !landscape && !charon_flag_get(self, CharonAppliedKey))
        return;
    if (!charon_bar_needs_refresh(self, [NSString stringWithFormat:@"%p %p", standard, landscape]) && !force)
        return;
    charon_apply_toolbar(self, standard, landscape);
    charon_flag_set(self, CharonAppliedKey, standard || landscape);
}

@end
