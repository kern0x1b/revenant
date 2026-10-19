#import "CharonMenus.h"

@implementation UITargetedPreview {
@private
    UIView *_view;
    UIPreviewParameters *_parameters;
    UIPreviewTarget *_target;
}

- (instancetype)initWithView:(UIView *)view parameters:(UIPreviewParameters *)parameters target:(UIPreviewTarget *)target
{
    if (!view)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: view != nil"];
    if (!parameters)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: parameters != nil"];
    if (!target)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: target != nil"];
    if ((self = [super init])) {
        _view = view;
        _parameters = parameters;
        _target = target;
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view parameters:(UIPreviewParameters *)parameters
{
    if (!charon_window_of(view))
        [NSException raise:NSInternalInconsistencyException format:@"This UITargetedPreview initializer requires that the view is in a window, but it is not. Either fix that, or use the other initializer that takes a target with an explicit container. (view: %@)",
                                                                   charon_short_description(view)];
    if (!parameters)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: parameters != nil"];
    UIPreviewTarget *target = [[UIPreviewTarget alloc] initWithContainer:view.superview center:view.center transform:view.transform];
    return [self initWithView:view parameters:parameters target:target];
}

- (instancetype)initWithView:(UIView *)view
{
    UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
    parameters.backgroundColor = [UIColor clearColor];
    return [self initWithView:view parameters:parameters];
}

- (UIView *)view
{
    return _view;
}

- (UIPreviewParameters *)parameters
{
    return _parameters;
}

- (UIPreviewTarget *)target
{
    return _target;
}

- (CGSize)size
{
    return _view.bounds.size;
}

- (UITargetedPreview *)retargetedPreviewWithTarget:(UIPreviewTarget *)newTarget
{
    if (!newTarget)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: newTarget != nil"];
    return [[[self class] alloc] initWithView:_view parameters:_parameters target:newTarget];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; view = %@; parameters = %@; target = %@>", [self class], self, charon_short_description(_view),
                                      charon_short_description(_parameters), charon_short_description(_target)];
}

@end
