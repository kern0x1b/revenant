#import <UIKit/UIKit.h>

#import "CharonDragSession.h"
#import "UIDropCoordinators.h"

#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

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
