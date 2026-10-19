#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation UIScribbleInteraction {
@private
    __weak id<UIScribbleInteractionDelegate> _delegate;
    __weak UIView *_view;
}

+ (BOOL)isPencilInputExpected
{
    return NO;
}

- (instancetype)initWithDelegate:(id<UIScribbleInteractionDelegate>)delegate
{
    if ((self = [super init]))
        _delegate = delegate;
    return self;
}

- (instancetype)init
{
    return [super init];
}

- (id<UIScribbleInteractionDelegate>)delegate
{
    return _delegate;
}

- (BOOL)isHandlingWriting
{
    return NO;
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (view)
        charon_menus_say_once(@"scribble", @"UIScribbleInteraction: this release has no Apple Pencil and no handwriting, so the interaction is attached and its delegate is never called; pencilInputExpected is NO");
}

@end

@implementation UIIndirectScribbleInteraction {
@private
    __weak id<UIIndirectScribbleInteractionDelegate> _delegate;
    __weak UIView *_view;
}

- (instancetype)initWithDelegate:(id<UIIndirectScribbleInteractionDelegate>)delegate
{
    if ((self = [super init]))
        _delegate = delegate;
    return self;
}

- (instancetype)init
{
    return [super init];
}

- (id<UIIndirectScribbleInteractionDelegate>)delegate
{
    return _delegate;
}

- (BOOL)isHandlingWriting
{
    return NO;
}

- (UIView *)view
{
    return _view;
}

- (void)willMoveToView:(UIView *)view
{
}

- (void)didMoveToView:(UIView *)view
{
    _view = view;
    if (view)
        charon_menus_say_once(@"indirect-scribble", @"UIIndirectScribbleInteraction: this release has no Apple Pencil and no handwriting, so the interaction is attached and its delegate is never asked for an element");
}

@end
