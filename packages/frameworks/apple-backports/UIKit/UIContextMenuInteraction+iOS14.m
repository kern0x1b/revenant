#import "RevenantMenus.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIContextMenuInteraction (RevenantFourteen)

- (UIContextMenuInteractionAppearance)menuAppearance
{
    return UIContextMenuInteractionAppearanceCompact;
}

- (void)updateVisibleMenuWithBlock:(UIMenu *(NS_NOESCAPE ^)(UIMenu *visibleMenu))block
{
    if (![self respondsToSelector:@selector(revenant_visibleMenu)])
        return;
    UIMenu *visible = [self revenant_visibleMenu];
    if (!visible)
        return;
    UIMenu *updated = block([visible copy]);
    if (updated)
        [self revenant_replaceVisibleMenu:updated];
}

@end
