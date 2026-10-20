#import <UIKit/UIKit.h>
#import <objc/message.h>

#import "RevenantDragSession.h"
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-property-implementation"

@implementation RevenantCollectionPlaceholderContext {
@private
    UICollectionViewDropPlaceholder *_placeholder;
    UIDragItem *_item;
    __weak UICollectionView *_collectionView;
}

- (instancetype)initWithPlaceholder:(UICollectionViewDropPlaceholder *)placeholder
                                item:(UIDragItem *)item
                              inView:(UICollectionView *)collectionView
{
    if ((self = [super init])) {
        _placeholder = placeholder;
        _item = item;
        _collectionView = collectionView;
    }
    return self;
}

- (UIDragItem *)dragItem
{
    return _item;
}

- (NSIndexPath *)insertionIndexPath
{
    SEL ask = @selector(insertionIndexPath);
    if ([_placeholder respondsToSelector:ask])
        return ((NSIndexPath * (*)(id, SEL))objc_msgSend)(_placeholder, ask);
    return nil;
}

- (NSString *)reuseIdentifier
{
    SEL ask = @selector(reuseIdentifier);
    if ([_placeholder respondsToSelector:ask])
        return ((NSString * (*)(id, SEL))objc_msgSend)(_placeholder, ask);
    return nil;
}

- (void)setNeedsCellUpdate
{
    if (!_collectionView || !_placeholder)
        return;
    void (^update)(__kindof UICollectionViewCell *) = _placeholder.cellUpdateHandler;
    NSIndexPath *path = self.insertionIndexPath;
    if (!update || !path)
        return;
    UICollectionViewCell *cell = [_collectionView dequeueReusableCellWithReuseIdentifier:self.reuseIdentifier
                                                                               forIndexPath:path];
    if (cell)
        update(cell);
}

- (BOOL)commitInsertionWithDataSourceUpdates:(void (NS_NOESCAPE ^)(NSIndexPath *insertionIndexPath))dataSourceUpdates
{
    if (!_collectionView || !_placeholder)
        return NO;
    NSIndexPath *path = self.insertionIndexPath;
    if (dataSourceUpdates)
        dataSourceUpdates(path);
    id dataSource = _collectionView.dataSource;
    SEL insert = @selector(collectionView:insertItemsAtIndexPaths:);
    if ([dataSource respondsToSelector:insert]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(dataSource, insert, _collectionView, @[path]);
        [_collectionView insertItemsAtIndexPaths:@[path]];
    } else {
        [_collectionView insertItemsAtIndexPaths:@[path]];
    }
    return YES;
}

- (BOOL)deletePlaceholder
{
    if (!_collectionView || !_placeholder)
        return NO;
    NSIndexPath *path = self.insertionIndexPath;
    id dataSource = _collectionView.dataSource;
    SEL remove = @selector(collectionView:deleteItemsAtIndexPaths:);
    if ([dataSource respondsToSelector:remove]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(dataSource, remove, _collectionView, @[path]);
        [_collectionView deleteItemsAtIndexPaths:@[path]];
    } else {
        [_collectionView deleteItemsAtIndexPaths:@[path]];
    }
    return YES;
}

@end

@interface RevenantTablePlaceholderContext ()
- (NSIndexPath *)insertionIndexPath;
@end

@implementation RevenantTablePlaceholderContext {
@private
    UITableViewDropPlaceholder *_placeholder;
    UIDragItem *_item;
    __weak UITableView *_tableView;
}

- (instancetype)initWithPlaceholder:(UITableViewDropPlaceholder *)placeholder
                                item:(UIDragItem *)item
                              inView:(UITableView *)tableView
{
    if ((self = [super init])) {
        _placeholder = placeholder;
        _item = item;
        _tableView = tableView;
    }
    return self;
}

- (UIDragItem *)dragItem
{
    return _item;
}

- (BOOL)commitInsertionWithDataSourceUpdates:(void (NS_NOESCAPE ^)(NSIndexPath *insertionIndexPath))dataSourceUpdates
{
    if (!_tableView || !_placeholder)
        return NO;
    NSIndexPath *path = self.insertionIndexPath;
    if (dataSourceUpdates)
        dataSourceUpdates(path);
    id dataSource = _tableView.dataSource;
    SEL insert = @selector(tableView:insertRowsAtIndexPaths:withRowAnimation:);
    if ([dataSource respondsToSelector:insert]) {
        ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(dataSource, insert, _tableView, @[path], UITableViewRowAnimationAutomatic);
        [_tableView insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [_tableView insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    return YES;
}

- (BOOL)deletePlaceholder
{
    if (!_tableView || !_placeholder)
        return NO;
    NSIndexPath *path = self.insertionIndexPath;
    id dataSource = _tableView.dataSource;
    SEL remove = @selector(tableView:deleteRowsAtIndexPaths:withRowAnimation:);
    if ([dataSource respondsToSelector:remove]) {
        ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(dataSource, remove, _tableView, @[path], UITableViewRowAnimationAutomatic);
        [_tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [_tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    return YES;
}

@end

@implementation RevenantCollectionDropCoordinator
@synthesize dropItems = _dropItems;
@synthesize destination = _destination;
@synthesize dropProposal = _dropProposal;
@synthesize dropSession = _dropSession;
@synthesize collectionView = _collectionView;

- (instancetype)initWithView:(UICollectionView *)view
                        items:(NSArray *)items
                  destination:(NSIndexPath *)destination
                    proposal:(UICollectionViewDropProposal *)proposal
                     session:(id<UIDropSession>)session
{
    if ((self = [super init])) {
        _collectionView = view;
        _dropItems = items;
        _destination = destination;
        _dropProposal = proposal;
        _dropSession = session;
    }
    return self;
}

- (NSArray<id<UICollectionViewDropItem>> *)items
{
    return _dropItems;
}

- (NSIndexPath *)destinationIndexPath
{
    return _destination;
}

- (UICollectionViewDropProposal *)proposal
{
    return _dropProposal;
}

- (id<UIDropSession>)session
{
    return _dropSession;
}

- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem toItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionView *view = _collectionView;
    if (!view || !indexPath)
        return nil;
    id dataSource = view.dataSource;
    SEL insert = @selector(collectionView:insertItemsAtIndexPaths:);
    if ([dataSource respondsToSelector:insert]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(dataSource, insert, view, @[indexPath]);
        [view insertItemsAtIndexPaths:@[indexPath]];
    } else {
        [view insertItemsAtIndexPaths:@[indexPath]];
    }
    return nil;
}

- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem intoItemAtIndexPath:(NSIndexPath *)indexPath rect:(CGRect)rect
{
    UICollectionView *view = _collectionView;
    if (!view || !indexPath)
        return nil;
    UICollectionViewLayoutAttributes *attributes = [view.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (attributes && !CGRectIsEmpty(rect)) {
        attributes.frame = CGRectOffset(attributes.frame, rect.origin.x, rect.origin.y);
        [view.collectionViewLayout invalidateLayout];
    }
    return [self dropItem:dragItem toItemAtIndexPath:indexPath];
}

- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem toTarget:(UIView *)target
{
    (void)dragItem;
    (void)target;
    return nil;
}

@end

@implementation RevenantTableDropCoordinator
@synthesize dropItems = _dropItems;
@synthesize destination = _destination;
@synthesize dropProposal = _dropProposal;
@synthesize dropSession = _dropSession;
@synthesize tableView = _tableView;

- (instancetype)initWithView:(UITableView *)view
                        items:(NSArray *)items
                  destination:(NSIndexPath *)destination
                    proposal:(UITableViewDropProposal *)proposal
                     session:(id<UIDropSession>)session
{
    if ((self = [super init])) {
        _tableView = view;
        _dropItems = items;
        _destination = destination;
        _dropProposal = proposal;
        _dropSession = session;
    }
    return self;
}

- (NSArray<id<UITableViewDropItem>> *)items
{
    return _dropItems;
}

- (NSIndexPath *)destinationIndexPath
{
    return _destination;
}

- (UITableViewDropProposal *)proposal
{
    return _dropProposal;
}

- (id<UIDropSession>)session
{
    return _dropSession;
}

- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem toRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableView *view = _tableView;
    if (!view || !indexPath)
        return nil;
    id dataSource = view.dataSource;
    SEL insert = @selector(tableView:insertRowsAtIndexPaths:withRowAnimation:);
    if ([dataSource respondsToSelector:insert]) {
        ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(dataSource, insert, view, @[indexPath], UITableViewRowAnimationAutomatic);
        [view insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [view insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    return nil;
}

- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem intoRowAtIndexPath:(NSIndexPath *)indexPath rect:(CGRect)rect
{
    UITableView *view = _tableView;
    if (!view || !indexPath)
        return nil;
    CGRect row = [view rectForRowAtIndexPath:indexPath];
    UITableViewCell *cell = [view cellForRowAtIndexPath:indexPath];
    if (cell && !CGRectIsEmpty(rect))
        cell.frame = CGRectOffset(row, rect.origin.x, rect.origin.y);
    return [self dropItem:dragItem toRowAtIndexPath:indexPath];
}

- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem toTarget:(UIView *)target
{
    (void)dragItem;
    (void)target;
    return nil;
}

@end
