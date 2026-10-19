#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <UIKit/UICollectionView.h>

#import "CharonDragDrop.h"
#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The collection view's half of a drag and drop, in its own object from the table view's: an object
// carries the API of one release, and the two views differ in the item class and in which of the
// release's own hit tests gives the index path.

@interface UICollectionView (CharonDragDropIntegration11)
- (NSArray<UIDragInteraction *> *)charon_dragInteractions;
- (NSArray<id<UICollectionViewDropItem>> *)charon_dropItemsAtPoint:(CGPoint)point session:(id<UIDropSession>)session;
@end

@implementation UICollectionView (CharonDragDropIntegration11)

// The drag interactions this view has, which is what hasActiveDrag reports on.
- (NSArray<UIDragInteraction *> *)charon_dragInteractions
{
    NSMutableArray *found = [NSMutableArray array];
    for (id<UIInteraction> interaction in self.interactions)
        if ([interaction isKindOfClass:[UIDragInteraction class]])
            [found addObject:(UIDragInteraction *)interaction];
    return found;
}

// Whether a drag is under way here: one of this view's own interactions is carrying something.
- (BOOL)hasActiveDrag
{
    for (UIDragInteraction *drag in [self charon_dragInteractions])
        if (drag.session)
            return YES;
    return NO;
}

// Whether a drop is under way here: a session of this view's own drop interaction is under the
// finger, which is the session the interaction was handed.
- (BOOL)hasActiveDrop
{
    for (id<UIInteraction> interaction in self.interactions) {
        if (![interaction isKindOfClass:[UIDropInteraction class]])
            continue;
        if (((UIDropInteraction *)interaction).currentDrop)
            return YES;
    }
    return NO;
}

// A drop over this view: the items under the point, where they would land and how big they would be
// drawn. The destination is the release's own hit test and the size is the one the release's own
// layout gives that item, so a preview is the size the item will be.
- (NSArray<id<UICollectionViewDropItem>> *)charon_dropItemsAtPoint:(CGPoint)point session:(id<UIDropSession>)session
{
    NSMutableArray *items = [NSMutableArray array];
    for (id<UIInteraction> interaction in self.interactions) {
        if (![interaction isKindOfClass:[UIDropInteraction class]])
            continue;
        id<UIDropInteractionDelegate> delegate = ((UIDropInteraction *)interaction).delegate;
        if (![delegate respondsToSelector:@selector(dropInteraction:sessionDidUpdate:)])
            continue;
        NSIndexPath *destination = [self indexPathForItemAtPoint:[self convertPoint:point fromView:nil]];
        if (!destination)
            continue;
        UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:destination];
        for (UIDragItem *item in session.items) {
            CharonCollectionDropItem *drop = [[CharonCollectionDropItem alloc] init];
            drop.item = item;
            drop.source = nil;
            drop.size = attributes ? attributes.size : CGSizeZero;
            [items addObject:drop];
        }
        return items;
    }
    return items;
}

@end
