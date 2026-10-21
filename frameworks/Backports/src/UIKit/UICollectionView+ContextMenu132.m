#import "RevenantListMenu.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionView (RevenantContextMenu132)

- (UIContextMenuInteraction *)contextMenuInteraction
{
    return revenant_list_menu_interaction(self, YES);
}

@end
