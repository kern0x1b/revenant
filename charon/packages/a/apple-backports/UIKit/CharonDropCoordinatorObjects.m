#import <UIKit/UIKit.h>
#import <objc/message.h>

#import "CharonDragSession.h"
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-property-implementation"

// What a drop delegate is handed, and the two placeholder contexts it commits through.
//
// The coordinators are protocols in the header and there is no drop on this release, so the objects
// that answer them are the port's own. What they do is the release's own work: an insertion goes
// through the data source's own callback and the view's own insert, a delete through its own delete,
// and a cell that is showing a placeholder is handed to the delegate's own block.

@implementation CharonCollectionPlaceholderContext {
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

// The index path and identifier the placeholder stands at, read out of the placeholder itself. They
// are its own properties, on a class whose header the 16.4 umbrella does not carry, so they are
// asked for by their selectors rather than written out here.
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

// The cell for the placeholder, given to the delegate's block. The 26.2 header says this is a no-op
// today and could change; it is implemented as the block being run, which is what the release's own
// comment describes the method's purpose as.
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

// The insertion, with the changes the data source made: the block is where the delegate says what it
// inserted, and the view is told afterwards, in the release's own order.
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

// The placeholder is done with, and the view is told to take it out.
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

@interface CharonTablePlaceholderContext ()
- (NSIndexPath *)insertionIndexPath;
@end

@implementation CharonTablePlaceholderContext {
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

// The two coordinators. What they do is the release's own work: an insertion goes through the data
// source's own callback and the view's own insert, so the cells, the layout and anything watching
// the data source all see one move, and a drop onto a target that is not a cell inserts nothing.
@implementation CharonCollectionDropCoordinator
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

@implementation CharonTableDropCoordinator
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
