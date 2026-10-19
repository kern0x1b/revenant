#import <UIKit/UIKit.h>

#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// What a drop is given to do: the items it carries, where they would land, what it proposes, and the
// session they came from — and the four ways a delegate can move one of them. The coordinators, the
// drop items and the placeholder contexts are protocols in the header, not classes, so the port
// supplies the objects that answer them; the release has none, because it has no drop at all.
//
// Moving an item is a real move: the destination is where the item goes, a placeholder is where it
// will be, and a target is the view it is dropped onto. What the data is comes from the item's own
// provider and is loaded by the delegate; nothing here copies a payload.

@implementation CharonCollectionDropItem
@synthesize item = _item;
@synthesize source = _source;
@synthesize size = _size;

- (UIDragItem *)dragItem
{
    return _item;
}

- (NSIndexPath *)sourceIndexPath
{
    return _source;
}

- (CGSize)previewSize
{
    return _size;
}
@end

@implementation CharonTableDropItem
@synthesize item = _item;
@synthesize source = _source;
@synthesize size = _size;

- (UIDragItem *)dragItem
{
    return _item;
}

- (NSIndexPath *)sourceIndexPath
{
    return _source;
}

- (CGSize)previewSize
{
    return _size;
}
@end

// A proposal that also says where the item would land: into a section, at an index path, or
// wherever the delegate means by "unspecified", which is what it says when it has not decided.
@implementation UICollectionViewDropProposal {
@private
    UICollectionViewDropIntent _intent;
}

- (instancetype)initWithDropOperation:(UIDropOperation)operation intent:(UICollectionViewDropIntent)intent
{
    if ((self = [super initWithDropOperation:operation]))
        _intent = intent;
    return self;
}

- (UICollectionViewDropIntent)intent
{
    return _intent;
}

@end

@implementation UITableViewDropProposal {
@private
    UITableViewDropIntent _intent;
}

- (instancetype)initWithDropOperation:(UIDropOperation)operation intent:(UITableViewDropIntent)intent
{
    if ((self = [super initWithDropOperation:operation]))
        _intent = intent;
    return self;
}

- (UITableViewDropIntent)intent
{
    return _intent;
}

@end

// A placeholder: where an item will be once the data source has been told about it. It knows the
// index path it stands at and can hand the cell it is standing in to a block, which is how a
// delegate draws a cell for a row that does not exist yet.
@implementation UICollectionViewPlaceholder {
@private
    NSIndexPath *_insertionIndexPath;
    NSString *_reuseIdentifier;
    void (^_cellUpdateHandler)(__kindof UICollectionViewCell *);
}

- (instancetype)initWithInsertionIndexPath:(NSIndexPath *)insertionIndexPath reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super init])) {
        _insertionIndexPath = insertionIndexPath;
        _reuseIdentifier = [reuseIdentifier copy];
    }
    return self;
}

- (NSIndexPath *)insertionIndexPath
{
    return _insertionIndexPath;
}

- (NSString *)reuseIdentifier
{
    return _reuseIdentifier;
}

- (void (^)(__kindof UICollectionViewCell *))cellUpdateHandler
{
    return _cellUpdateHandler;
}

- (void)setCellUpdateHandler:(void (^)(__kindof UICollectionViewCell *))cellUpdateHandler
{
    _cellUpdateHandler = [cellUpdateHandler copy];
}

@end

@implementation UITableViewPlaceholder {
@private
    NSIndexPath *_insertionIndexPath;
    NSString *_reuseIdentifier;
    CGFloat _rowHeight;
    void (^_cellUpdateHandler)(__kindof UITableViewCell *);
}

- (instancetype)initWithInsertionIndexPath:(NSIndexPath *)insertionIndexPath reuseIdentifier:(NSString *)reuseIdentifier rowHeight:(CGFloat)rowHeight
{
    if ((self = [super init])) {
        _insertionIndexPath = insertionIndexPath;
        _reuseIdentifier = [reuseIdentifier copy];
        _rowHeight = rowHeight;
    }
    return self;
}

- (NSIndexPath *)insertionIndexPath
{
    return _insertionIndexPath;
}

- (NSString *)reuseIdentifier
{
    return _reuseIdentifier;
}

- (CGFloat)rowHeight
{
    return _rowHeight;
}

- (void (^)(__kindof UITableViewCell *))cellUpdateHandler
{
    return _cellUpdateHandler;
}

- (void)setCellUpdateHandler:(void (^)(__kindof UITableViewCell *))cellUpdateHandler
{
    _cellUpdateHandler = [cellUpdateHandler copy];
}

@end

// A placeholder that is a drop target: the same placeholder, plus the preview parameters its preview
// is built from.
@implementation UICollectionViewDropPlaceholder {
@private
    UIDragPreviewParameters *(^_previewParametersProvider)(__kindof UICollectionViewCell *);
}

- (instancetype)initWithInsertionIndexPath:(NSIndexPath *)insertionIndexPath reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithInsertionIndexPath:insertionIndexPath reuseIdentifier:reuseIdentifier]))
        ;
    return self;
}

- (UIDragPreviewParameters *(^)(__kindof UICollectionViewCell *))previewParametersProvider
{
    return _previewParametersProvider;
}

- (void)setPreviewParametersProvider:(UIDragPreviewParameters *(^)(__kindof UICollectionViewCell *))previewParametersProvider
{
    _previewParametersProvider = [previewParametersProvider copy];
}

@end

@implementation UITableViewDropPlaceholder {
@private
    UIDragPreviewParameters *(^_previewParametersProvider)(__kindof UITableViewCell *);
}

- (instancetype)initWithInsertionIndexPath:(NSIndexPath *)insertionIndexPath reuseIdentifier:(NSString *)reuseIdentifier rowHeight:(CGFloat)rowHeight
{
    if ((self = [super initWithInsertionIndexPath:insertionIndexPath reuseIdentifier:reuseIdentifier rowHeight:rowHeight]))
        ;
    return self;
}

- (UIDragPreviewParameters *(^)(__kindof UITableViewCell *))previewParametersProvider
{
    return _previewParametersProvider;
}

- (void)setPreviewParametersProvider:(UIDragPreviewParameters *(^)(__kindof UITableViewCell *))previewParametersProvider
{
    _previewParametersProvider = [previewParametersProvider copy];
}

@end
