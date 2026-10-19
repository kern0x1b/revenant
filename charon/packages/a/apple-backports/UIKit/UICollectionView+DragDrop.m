#import "CharonDragDrop.h"

@implementation UICollectionView (CharonDragDrop)

- (id<UICollectionViewDragDelegate>)dragDelegate
{
    return charon_drag_drop_box(self)->dragDelegate;
}

- (void)setDragDelegate:(id<UICollectionViewDragDelegate>)delegate
{
    charon_drag_drop_box(self)->dragDelegate = delegate;
}

- (id<UICollectionViewDropDelegate>)dropDelegate
{
    return charon_drag_drop_box(self)->dropDelegate;
}

- (void)setDropDelegate:(id<UICollectionViewDropDelegate>)delegate
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
