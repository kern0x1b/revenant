#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface UIPopoverPresentationController ()
- (void)charon_setPresenting:(UIViewController *)presenting arrowDirection:(UIPopoverArrowDirection)direction;
@end

@implementation UIPopoverPresentationController {
    UIPopoverArrowDirection _permittedArrowDirections;
    UIView *_sourceView;
    CGRect _sourceRect;
    UIBarButtonItem *_barButtonItem;
    UIPopoverArrowDirection _arrowDirection;
    NSArray *_passthroughViews;
    UIColor *_backgroundColor;
    UIEdgeInsets _popoverLayoutMargins;
    Class _popoverBackgroundViewClass;
    BOOL _canOverlapSourceViewRect;
    UIViewController *_presenting;
}

@dynamic delegate;

- (instancetype)initWithPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting
{
    if ((self = [super initWithPresentedViewController:presented presentingViewController:presenting])) {
        _permittedArrowDirections = UIPopoverArrowDirectionAny;
        _sourceRect = CGRectNull;
        _arrowDirection = (UIPopoverArrowDirection)NSUIntegerMax;
    }
    return self;
}

- (UIViewController *)presentingViewController
{
    return _presenting ?: [super presentingViewController];
}

- (void)charon_setPresenting:(UIViewController *)presenting arrowDirection:(UIPopoverArrowDirection)direction
{
    _presenting = presenting;
    _arrowDirection = direction;
}

- (UIPopoverArrowDirection)permittedArrowDirections
{
    return _permittedArrowDirections;
}

- (void)setPermittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections
{
    _permittedArrowDirections = permittedArrowDirections;
}

- (UIView *)sourceView
{
    return _sourceView;
}

- (void)setSourceView:(UIView *)sourceView
{
    _sourceView = sourceView;
}

- (CGRect)sourceRect
{
    return _sourceRect;
}

- (void)setSourceRect:(CGRect)sourceRect
{
    _sourceRect = sourceRect;
}

- (BOOL)canOverlapSourceViewRect
{
    return _canOverlapSourceViewRect;
}

- (void)setCanOverlapSourceViewRect:(BOOL)canOverlapSourceViewRect
{
    _canOverlapSourceViewRect = canOverlapSourceViewRect;
}

- (UIBarButtonItem *)barButtonItem
{
    return _barButtonItem;
}

- (void)setBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    _barButtonItem = barButtonItem;
}

- (UIPopoverArrowDirection)arrowDirection
{
    return _arrowDirection;
}

- (NSArray *)passthroughViews
{
    return _passthroughViews;
}

- (void)setPassthroughViews:(NSArray *)passthroughViews
{
    _passthroughViews = [passthroughViews copy];
}

- (UIColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
}

- (UIEdgeInsets)popoverLayoutMargins
{
    return _popoverLayoutMargins;
}

- (void)setPopoverLayoutMargins:(UIEdgeInsets)popoverLayoutMargins
{
    _popoverLayoutMargins = popoverLayoutMargins;
}

- (Class)popoverBackgroundViewClass
{
    return _popoverBackgroundViewClass;
}

- (void)setPopoverBackgroundViewClass:(Class)popoverBackgroundViewClass
{
    _popoverBackgroundViewClass = popoverBackgroundViewClass;
}

@end
