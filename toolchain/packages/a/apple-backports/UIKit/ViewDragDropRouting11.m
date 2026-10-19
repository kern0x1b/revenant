#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "RevenantDragDrop.h"
#import "RevenantDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionView (RevenantViewDragDrop11)

- (NSArray<UIDragItem *> *)revenant_itemsForBeginningDragAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:itemsForBeginningDragSession:atIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    RevenantDragSession *session = [[RevenantDragSession alloc] initWithItems:@[] interaction:nil];
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, indexPath);
}

- (UIDragPreviewParameters *)revenant_dragPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragPreviewParametersForItemAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (BOOL)revenant_dragSessionAllowsMoveOperation:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionAllowsMoveOperation:);
    if (![delegate respondsToSelector:ask])
        return session.allowsMoveOperation;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (BOOL)revenant_dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionIsRestrictedToDraggingApplication:);
    if (![delegate respondsToSelector:ask])
        return YES;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDragDelegateWillBegin:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionWillBegin:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDragDelegateDidEnd:(id<UIDragSession>)session
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (NSArray<UIDragItem *> *)revenant_itemsForAddingToDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:itemsForAddingToDragSession:atIndexPath:point:);
    if (![delegate respondsToSelector:ask] || !session)
        return nil;
    UICollectionViewLayoutAttributes *attributes = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    CGPoint point = attributes ? CGPointMake(CGRectGetMidX(attributes.frame), CGRectGetMidY(attributes.frame)) : CGPointZero;
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id, CGPoint))objc_msgSend)(delegate, ask, self, session, indexPath, point);
}

- (BOOL)revenant_canHandleDropSession:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:canHandleDropSession:);
    if (![delegate respondsToSelector:ask])
        return NO;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDropDelegateDidEnter:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidEnter:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDropDelegateDidExit:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidExit:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDropDelegateDidEnd:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (UICollectionViewDropProposal *)revenant_dropProposalForSession:(id<UIDropSession>)session
                                                atIndexPath:(NSIndexPath *)destination
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropSessionDidUpdate:withDestinationIndexPath:);
    UICollectionViewDropProposal *proposal = nil;
    if ([delegate respondsToSelector:ask])
        proposal = ((UICollectionViewDropProposal * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, destination);
    return proposal ?: [[UICollectionViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel
                                                                           intent:UICollectionViewDropIntentUnspecified];
}

- (UIDragPreviewParameters *)revenant_dropPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(collectionView:dropPreviewParametersForItemAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (void)revenant_performDropOfSession:(id<UIDropSession>)session
{
    id<UICollectionViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
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
        RevenantCollectionDropItem *drop = [[RevenantCollectionDropItem alloc] init];
        drop.item = item;
        drop.source = nil;
        drop.size = attributes ? attributes.size : CGSizeZero;
        [items addObject:drop];
    }
    UICollectionViewDropProposal *proposal = [self revenant_dropProposalForSession:session atIndexPath:destination];
    RevenantCollectionDropCoordinator *coordinator =
        [[RevenantCollectionDropCoordinator alloc] initWithView:self
                                                        items:items
                                                  destination:destination
                                                    proposal:proposal
                                                     session:session];
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, coordinator);
}

@end

@implementation UITableView (RevenantViewDragDrop11)

- (NSArray<UIDragItem *> *)revenant_itemsForBeginningDragAtIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:itemsForBeginningDragSession:atIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    RevenantDragSession *session = [[RevenantDragSession alloc] initWithItems:@[] interaction:nil];
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, indexPath);
}

- (UIDragPreviewParameters *)revenant_dragPreviewParametersForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragPreviewParametersForRowAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (BOOL)revenant_dragSessionAllowsMoveOperation:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionAllowsMoveOperation:);
    if (![delegate respondsToSelector:ask])
        return session.allowsMoveOperation;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (BOOL)revenant_dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionIsRestrictedToDraggingApplication:);
    if (![delegate respondsToSelector:ask])
        return YES;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDragDelegateWillBegin:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionWillBegin:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDragDelegateDidEnd:(id<UIDragSession>)session
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:dragSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (NSArray<UIDragItem *> *)revenant_itemsForAddingToDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDragDelegate> delegate = revenant_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(tableView:itemsForAddingToDragSession:atIndexPath:point:);
    if (![delegate respondsToSelector:ask] || !session)
        return nil;
    CGRect row = [self rectForRowAtIndexPath:indexPath];
    CGPoint point = CGPointMake(CGRectGetMidX(row), CGRectGetMidY(row));
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id, CGPoint))objc_msgSend)(delegate, ask, self, session, indexPath, point);
}

- (BOOL)revenant_canHandleDropSession:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:canHandleDropSession:);
    if (![delegate respondsToSelector:ask])
        return NO;
    return ((BOOL (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDropDelegateDidEnter:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidEnter:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDropDelegateDidExit:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidExit:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (void)revenant_tellDropDelegateDidEnd:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidEnd:);
    if ([delegate respondsToSelector:ask])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, session);
}

- (UITableViewDropProposal *)revenant_dropProposalForSession:(id<UIDropSession>)session
                                            atIndexPath:(NSIndexPath *)destination
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropSessionDidUpdate:withDestinationIndexPath:);
    UITableViewDropProposal *proposal = nil;
    if ([delegate respondsToSelector:ask])
        proposal = ((UITableViewDropProposal * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, destination);
    return proposal ?: [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel
                                                                     intent:UITableViewDropIntentUnspecified];
}

- (UIDragPreviewParameters *)revenant_dropPreviewParametersForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
    SEL ask = @selector(tableView:dropPreviewParametersForRowAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

- (void)revenant_performDropOfSession:(id<UIDropSession>)session
{
    id<UITableViewDropDelegate> delegate = revenant_drag_drop_box(self)->dropDelegate;
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
        RevenantTableDropItem *drop = [[RevenantTableDropItem alloc] init];
        drop.item = item;
        drop.source = nil;
        drop.size = row.size;
        [items addObject:drop];
    }
    UITableViewDropProposal *proposal = [self revenant_dropProposalForSession:session atIndexPath:destination];
    RevenantTableDropCoordinator *coordinator =
        [[RevenantTableDropCoordinator alloc] initWithView:self
                                                     items:items
                                               destination:destination
                                                 proposal:proposal
                                                  session:session];
    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, coordinator);
}

@end
