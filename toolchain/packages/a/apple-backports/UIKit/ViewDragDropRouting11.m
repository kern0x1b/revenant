#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>

#import "CharonDragDrop.h"
#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionView (CharonViewDragDrop11)

- (NSArray<UIDragItem *> *)charon_itemsForBeginningDragAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:itemsForBeginningDragSession:atIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    CharonDragSession *session = [[CharonDragSession alloc] initWithItems:@[] interaction:nil];
    return ((NSArray<UIDragItem *> * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, ask, self, session, indexPath);
}

- (UIDragPreviewParameters *)charon_dragPreviewParametersForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<UICollectionViewDragDelegate> delegate = charon_drag_drop_box(self)->dragDelegate;
    SEL ask = @selector(collectionView:dragPreviewParametersForItemAtIndexPath:);
    if (![delegate respondsToSelector:ask])
        return nil;
    return ((UIDragPreviewParameters * (*)(id, SEL, id, id))objc_msgSend)(delegate, ask, self, indexPath);
}

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
        return YES;
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
        return YES;
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
