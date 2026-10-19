#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// What a drag carries and what it looks like while it is carried. A drag item is a piece of data to
// move — an item provider — with whatever the application wants to remember about it inside its own
// process, and a preview is a still picture of a view with the parameters the lift and the drop
// animations are built from.
//
// These are the value objects, and every one of them is reachable on this release. The parameters and
// the target build on UIPreviewParameters and UIPreviewTarget, which the tree already carries for the
// peek and pop preview, and this file adds nothing to them: a drag's parameters are the same kind of
// object, which is why the header makes them a subclass rather than a new thing. What the release
// cannot do is a drag that leaves the application, and the session says so where it is asked.

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

// What the application wants to remember about this item, and which stays inside the process that
// started the drag: nothing here travels with the data.
- (id)localObject
{
    return _localObject;
}

- (void)setLocalObject:(id)localObject
{
    _localObject = localObject;
}

// A block that makes the preview for this item, for an application that wants to change the picture
// while the drag is under way. It is called when and if the preview is wanted, so it is copied here
// and not run.
- (UIDragPreview *(^)(void))previewProvider
{
    return _previewProvider;
}

- (void)setPreviewProvider:(UIDragPreview *(^)(void))previewProvider
{
    _previewProvider = [previewProvider copy];
}

@end

// A drag's preview parameters are the same kind of object as a peek's, with the same visible path and
// the same shadow, which is what the header's subclassing says; nothing of its own is added.
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

// Where a preview is aimed. A drag's target is the same kind of object as a peek's — a container, a
// centre in it and a transform — and the tree already carries that in UIPreviewTarget, down to the
// precondition it raises on when the container is not in a window. A drag's target is the drag's own
// name for it and adds nothing, exactly as its parameters add nothing to UIPreviewParameters.
@implementation UIDragPreviewTarget
@end

// The header gives a targeted drag preview no way to make one: the system hands it to the delegate
// that is asked for a preview, and an application never constructs it. So this adds nothing to the
// UITargetedPreview the tree already carries, and the one thing the header does declare is the
// retargeting, which is the superclass's own with the drag's type.
@implementation UITargetedDragPreview

- (UITargetedDragPreview *)retargetedPreviewWithTarget:(UIDragPreviewTarget *)newTarget
{
    return (UITargetedDragPreview *)[super retargetedPreviewWithTarget:newTarget];
}

@end
