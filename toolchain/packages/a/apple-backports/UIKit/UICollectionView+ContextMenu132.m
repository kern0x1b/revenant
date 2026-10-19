#import "CharonListMenu.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionView (CharonContextMenu132)

- (UIContextMenuInteraction *)contextMenuInteraction
{
    return charon_list_menu_interaction(self, YES);
}

@end
