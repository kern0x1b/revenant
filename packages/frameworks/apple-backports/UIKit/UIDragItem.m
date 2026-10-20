#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation UIDragItem {
@private
    NSItemProvider *_itemProvider;
    id _localObject;
    UIDragPreview *(^_previewProvider)(void);
}

- (instancetype)initWithItemProvider:(NSItemProvider *)itemProvider
{
    if ((self = [super init]))
        _itemProvider = itemProvider;
    return self;
}

- (NSItemProvider *)itemProvider
{
    return _itemProvider;
}

- (id)localObject
{
    return _localObject;
}

- (void)setLocalObject:(id)localObject
{
    _localObject = localObject;
}

- (UIDragPreview *(^)(void))previewProvider
{
    return _previewProvider;
}

- (void)setPreviewProvider:(UIDragPreview *(^)(void))previewProvider
{
    _previewProvider = [previewProvider copy];
}

@end

@implementation UIDragPreviewParameters
@end

@implementation UIDragPreview {
@private
    UIView *_view;
    UIDragPreviewParameters *_parameters;
}

- (instancetype)initWithView:(UIView *)view parameters:(UIDragPreviewParameters *)parameters
{
    if ((self = [super init])) {
        _view = view;
        _parameters = parameters;
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view
{
    return [self initWithView:view parameters:[[UIDragPreviewParameters alloc] init]];
}

- (UIView *)view
{
    return _view;
}

- (UIDragPreviewParameters *)parameters
{
    return _parameters;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithView:_view parameters:_parameters];
}

@end

@implementation UIDragPreviewTarget
@end

@implementation UITargetedDragPreview

- (UITargetedDragPreview *)retargetedPreviewWithTarget:(UIDragPreviewTarget *)newTarget
{
    return (UITargetedDragPreview *)[super retargetedPreviewWithTarget:newTarget];
}

@end
