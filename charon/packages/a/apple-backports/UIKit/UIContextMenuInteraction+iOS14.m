#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UIContextMenuInteraction (CharonFourteen)

- (UIContextMenuInteractionAppearance)menuAppearance
{
    return UIContextMenuInteractionAppearanceCompact;
}

- (void)updateVisibleMenuWithBlock:(UIMenu *(NS_NOESCAPE ^)(UIMenu *visibleMenu))block
{
    if (![self respondsToSelector:@selector(charon_visibleMenu)])
        return;
    UIMenu *visible = [self charon_visibleMenu];
    if (!visible)
        return;
    UIMenu *updated = block([visible copy]);
    if (updated)
        [self charon_replaceVisibleMenu:updated];
}

@end
