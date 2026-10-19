#import "RevenantDragDrop.h"

@implementation UITableView (RevenantDragDrop)

- (id<UITableViewDragDelegate>)dragDelegate
{
    return revenant_drag_drop_box(self)->dragDelegate;
}

- (void)setDragDelegate:(id<UITableViewDragDelegate>)delegate
{
    revenant_drag_drop_box(self)->dragDelegate = delegate;
}

- (id<UITableViewDropDelegate>)dropDelegate
{
    return revenant_drag_drop_box(self)->dropDelegate;
}

- (void)setDropDelegate:(id<UITableViewDropDelegate>)delegate
{
    revenant_drag_drop_box(self)->dropDelegate = delegate;
}

- (BOOL)dragInteractionEnabled
{
    return revenant_drag_interaction_enabled(self);
}

- (void)setDragInteractionEnabled:(BOOL)enabled
{
    revenant_set_drag_interaction_enabled(self, enabled);
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
