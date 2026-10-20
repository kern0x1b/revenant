#import "RevenantListMenu.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UITableView (RevenantContextMenu14)

- (UIContextMenuInteraction *)contextMenuInteraction
{
    return revenant_list_menu_interaction(self, YES);
}

@end
