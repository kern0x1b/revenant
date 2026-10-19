#import "CharonDragDrop.h"

@implementation UITableView (CharonDragDrop)

- (id<UITableViewDragDelegate>)dragDelegate
{
    return charon_drag_drop_box(self)->dragDelegate;
}

- (void)setDragDelegate:(id<UITableViewDragDelegate>)delegate
{
    charon_drag_drop_box(self)->dragDelegate = delegate;
}

- (id<UITableViewDropDelegate>)dropDelegate
{
    return charon_drag_drop_box(self)->dropDelegate;
}

- (void)setDropDelegate:(id<UITableViewDropDelegate>)delegate
{
    charon_drag_drop_box(self)->dropDelegate = delegate;
}

- (BOOL)dragInteractionEnabled
{
    return charon_drag_interaction_enabled(self);
}

- (void)setDragInteractionEnabled:(BOOL)enabled
{
    charon_set_drag_interaction_enabled(self, enabled);
}

- (BOOL)hasActiveDrag
{
    return NO;
}

- (BOOL)hasActiveDrop
{
    return NO;
}

@end
