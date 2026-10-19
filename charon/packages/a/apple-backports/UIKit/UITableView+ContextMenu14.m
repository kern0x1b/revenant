#import "CharonListMenu.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UITableView (CharonContextMenu14)

- (UIContextMenuInteraction *)contextMenuInteraction
{
    return charon_list_menu_interaction(self, YES);
}

@end
