#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "CharonDragDrop.h"
#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The two views' own drag and drop delegates, which are not the interactions' delegates.
//
// A collection view and a table view each carry a drag delegate and a drop delegate of their own,
// and they are asked different questions from the UIDragInteraction and UIDropInteraction delegates:
// the view asks its drag delegate what an item at an index path *is*, and its drop delegate whether a
// session will be handled, what it proposes for it, and to perform it. The release's collection view
// and table view ask none of them, so an application that implemented them was never asked, and the
// drag this port already had was only ever an interaction's drag.
//
// The order and the arguments are the host's own, held by tests/backports/host/viewdragdrop. The
// sequence, for one drop, is:
//
//   canHandleDropSession:            will it be handled at all
//   dropSessionDidUpdate:withDestinationIndexPath:   what it proposes, once per move
//   performDropWithCoordinator:      the drop, with the coordinator the items move through
//   dropSessionDidEnd:               the session is over
//
// and for one drag, itemsForBeginningDragSession:atIndexPath: is asked before anything is lifted.
// A drop session is also told when it enters and leaves: dropSessionDidEnter: before the first
// update, dropSessionDidExit: when it leaves the view.
//
// The drag delegate's own session questions are asked at the points they describe:
// dragSessionWillBegin: once the items exist and before the lift animation, dragSessionDidEnd: once
// the drag is over, and the move and restriction questions whenever the answer is needed.

@implementation UICollectionView (CharonViewDragDrop11)

// ---- the drag delegate

// What an item at this index path is. The view asks its own drag delegate, and an application that
// has set one gets asked; a view with none lifts the item under the touch, which is what the
// interaction's own delegate would have been asked for.
- (NSArray<UIDragItem *> *)charon_itemsForBeginningDragAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:itemsForBeginningDragSession:atIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    CharonDragSession *session = [[CharonDragSession alloc] initWithItems:@[] interaction:nil];
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, indexPath);
}

// The preview an item is lifted with, which is the drag delegate's to choose.
- (UIDragPreviewParameters *)charon_dragPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragPreviewParametersForItemAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

// Whether a session may move its items, and whether it is confined to this application. Both are
// asked when the answer is needed rather than once, so a delegate can change its mind mid-drag.
- (BOOL)charon_dragSessionAllowsMoveOperation:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionAllowsMoveOperation:);
    if (![delegate respondsToSelector:ask])
        return session.allowsMoveOperation;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (BOOL)charon_dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionIsRestrictedToDraggingApplication:);
    if (![delegate respondsToSelector:ask])
        return YES;   // a drag on this release stays in the application that began it
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDragDelegateWillBegin:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionWillBegin:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDragDelegateDidEnd:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (NSArray<UIDragItem *> *)charon_itemsForAddingToDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:itemsForAddingToDragSession:atIndexPath:point:);
    if (![delegate respondsToSelector:ask] || !session)
        return nil;
    UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    CGPoint point = attributes ? CGPointMake(CGRectGetMidX(attributes.frame), CGRectGetMidY(attributes.frame)) : CGPointZero;
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id, CGPoint))objc_msgSend)(delegate, ask, self, session, indexPath, point);
}

// ---- the drop delegate

- (BOOL)charon_canHandleDropSession:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:canHandleDropSession:);
    if (![delegate respondsToSelector:ask])
        return NO;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDropDelegateDidEnter:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidEnter:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDropDelegateDidExit:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidExit:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDropDelegateDidEnd:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

// What a session would do at this point. The destination is the item under the finger, from the
// release's own hit test, and a delegate that answers nothing has the session cancelled rather than
// moved, so nothing is dropped that the delegate did not agree to.
- (UICollectionViewDropProposal *)charon_dropProposalForSession:(id<UIDropSession>)session
                                                atIndexPath:(NSIndexPath *)destination
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidUpdate:withDestinationIndexPath:);
    UICollectionViewDropProposal *proposal = nil;
    if ([delegate respondsToSelector:ask])
        proposal = ((UICollectionViewDropProposal * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, destination);
    return proposal ?: [[UICollectionViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel
                                                                           intent:UICollectionViewDropIntentUnspecified];
}

- (UIDragPreviewParameters *)charon_dropPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropPreviewParametersForItemAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

// The drop itself, with the coordinator the delegate moves the items through: the items, where they
// would land, what was proposed and the session. The destination is the item under the finger, and
// the item sizes are the ones the layout gives that item, so a preview is the size it will be drawn.
- (void)charon_performDropOfSession:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:performDropWithCoordinator:);
    if (![delegate respondsToSelector:ask])
        return;
    CGPoint point = [session locationInView:self];
    NSIndexPath *destination = [self indexPathForItemAtPoint:point];
    if (!destination)
        return;
    NSMutableArray *items = [NSMutableArray array];
    UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:destination];
    for (UIDragItem *item in session.items) {
        CharonCollectionDropItem *drop = [[CharonCollectionDropItem alloc] init];
        drop.item = item;
        drop.source = nil;
        drop.size = attributes ? attributes.size : CGSizeZero;
        [items addObject:drop];
    }
    UICollectionViewDropProposal *proposal = [self charon_dropProposalForSession:session atIndexPath:destination];
    CharonCollectionDropCoordinator *coordinator =
        [[CharonCollectionDropCoordinator alloc] initWithView:self
                                                        items:items
                                                  destination:destination
                                                    proposal:proposal
                                                     session:session];
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, coordinator);
}

@end

@implementation UITableView (CharonViewDragDrop11)

// ---- the drag delegate

- (NSArray<UIDragItem *> *)charon_itemsForBeginningDragAtIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:itemsForBeginningDragSession:atIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    CharonDragSession *session = [[CharonDragSession alloc] initWithItems:@[] interaction:nil];
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, indexPath);
}

- (UIDragPreviewParameters *)charon_dragPreviewParametersForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragPreviewParametersForRowAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (BOOL)charon_dragSessionAllowsMoveOperation:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionAllowsMoveOperation:);
    if (![delegate respondsToSelector:ask])
        return session.allowsMoveOperation;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (BOOL)charon_dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionIsRestrictedToDraggingApplication:);
    if (![delegate respondsToSelector:ask])
        return YES;   // a drag on this release stays in the application that began it
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDragDelegateWillBegin:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionWillBegin:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDragDelegateDidEnd:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (NSArray<UIDragItem *> *)charon_itemsForAddingToDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:itemsForAddingToDragSession:atIndexPath:point:);
    if (![delegate respondsToSelector:ask] || !session)
        return nil;
    CGRect row = [self rectForRowAtIndexPath:indexPath];
    CGPoint point = CGPointMake(CGRectGetMidX(row), CGRectGetMidY(row));
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id, CGPoint))objc_msgSend)(delegate, ask, self, session, indexPath, point);
}

// ---- the drop delegate

- (BOOL)charon_canHandleDropSession:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:canHandleDropSession:);
    if (![delegate respondsToSelector:ask])
        return NO;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDropDelegateDidEnter:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidEnter:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDropDelegateDidExit:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidExit:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)charon_tellDropDelegateDidEnd:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (UITableViewDropProposal *)charon_dropProposalForSession:(id<UIDropSession>)session
                                            atIndexPath:(NSIndexPath *)destination
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidUpdate:withDestinationIndexPath:);
    UITableViewDropProposal *proposal = nil;
    if ([delegate respondsToSelector:ask])
        proposal = ((UITableViewDropProposal * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, destination);
    return proposal ?: [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel
                                                                     intent:UITableViewDropIntentUnspecified];
}

- (UIDragPreviewParameters *)charon_dropPreviewParametersForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropPreviewParametersForRowAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (void)charon_performDropOfSession:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = charon_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:performDropWithCoordinator:);
    if (![delegate respondsToSelector:ask])
        return;
    CGPoint point = [session locationInView:self];
    NSIndexPath *destination = [self indexPathForRowAtPoint:point];
    if (!destination)
        return;
    NSMutableArray *items = [NSMutableArray array];
    CGRect row = [self rectForRowAtIndexPath:destination];
    for (UIDragItem *item in session.items) {
        CharonTableDropItem *drop = [[CharonTableDropItem alloc] init];
        drop.item = item;
        drop.source = nil;
        drop.size = row.size;
        [items addObject:drop];
    }
    UITableViewDropProposal *proposal = [self charon_dropProposalForSession:session atIndexPath:destination];
    CharonTableDropCoordinator *coordinator =
        [[CharonTableDropCoordinator alloc] initWithView:self
                                                     items:items
                                               destination:destination
                                                 proposal:proposal
                                                  session:session];
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, coordinator);
}

@end
