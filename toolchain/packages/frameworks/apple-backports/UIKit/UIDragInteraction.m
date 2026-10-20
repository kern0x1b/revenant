#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "RevenantDragDrop.h"
#import "RevenantDragDrop.h"
#import "RevenantDragSession.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface UIDropInteraction (RevenantDropQuery)
- (BOOL)isEnabled;
@end

@interface UIDragInteraction () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) RevenantDragSession *session;
@property (nonatomic, strong) UIImageView *preview;
@property (nonatomic, strong) UILongPressGestureRecognizer *lift;
@property (nonatomic, strong) UIPanGestureRecognizer *carry;
@property (nonatomic, strong) NSMutableSet<UIDropInteraction *> *dropTargets;
@property (nonatomic, strong) RevenantDropSession *currentDrop;
@property (nonatomic, assign) CGPoint liftPoint;
@end

@implementation UIDragInteraction {
@private
    __weak id<UIDragInteractionDelegate> _delegate;
    BOOL _enabled;
}

+ (void)initialize
{
    if (self != [UIDragInteraction class])
        return;
    revenant_set_drag_interaction_enabled_default([UIDragInteraction isEnabledByDefault]);
}

@synthesize session = _session;
@synthesize preview = _preview;
@synthesize lift = _lift;
@synthesize carry = _carry;
@synthesize dropTargets = _dropTargets;
@synthesize currentDrop = _currentDrop;
@synthesize liftPoint = _liftPoint;

- (instancetype)initWithDelegate:(id<UIDragInteractionDelegate>)delegate
{
    if ((self = [super init])) {
        _delegate = delegate;
        _enabled = [UIDragInteraction isEnabledByDefault];
        [self revenant_installGestures];
    }
    return self;
}

- (id<UIDragInteractionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIDragInteractionDelegate>)delegate
{
    _delegate = delegate;
}

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    self.lift.enabled = enabled;
    self.carry.enabled = enabled;
}

+ (BOOL)isEnabledByDefault
{
    return YES;
}

- (UIView *)view
{
    return self.lift.view;
}

- (void)willMoveToView:(UIView *)view
{
    [self.lift.view removeGestureRecognizer:self.lift];
    [self.carry.view removeGestureRecognizer:self.carry];
}

- (void)didMoveToView:(UIView *)view
{
    if (!view) {
        [self willMoveToView:nil];
        return;
    }
    [view addGestureRecognizer:self.lift];
    [view addGestureRecognizer:self.carry];
}

- (void)revenant_installGestures
{
    if (self.lift)
        return;
    UILongPressGestureRecognizer *lift = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(revenant_lift:)];
    lift.minimumPressDuration = 0.5;
    lift.delegate = self;
    UIPanGestureRecognizer *carry = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(revenant_carry:)];
    carry.delegate = self;
    self.lift = lift;
    self.carry = carry;
    self.dropTargets = [NSMutableSet set];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return self.allowsSimultaneousRecognitionDuringLift;
}

- (void)revenant_lift:(UILongPressGestureRecognizer *)recognizer
{
    UIView *view = recognizer.view;
    if (!view)
        return;
    switch (recognizer.state) {
    case UIGestureRecognizerStateBegan: {
        CGPoint point = [recognizer locationInView:view];
        self.liftPoint = point;
        UIView *under = [view hitTest:point withEvent:nil];
        if (!under)
            return;
        RevenantDragSession *session = [[RevenantDragSession alloc] initWithItems:@[] interaction:self];
        session.location = point;
        NSArray<UIDragItem *> *items = nil;
        if ([_delegate respondsToSelector:@selector(dragInteraction:itemsForBeginningSession:)])
            items = [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self itemsForBeginningSession:session];
        else
            items = [self revenant_defaultItemsForView:under];
        (void)under;
        if (!items.count)
            return;
        session.items = [items mutableCopy];
        self.session = session;
        if ([_delegate respondsToSelector:@selector(dragInteraction:sessionAllowsMoveOperation:)])
            session.allowsMoveOperation = [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self sessionAllowsMoveOperation:session];
        UITargetedDragPreview *preview = nil;
        if ([_delegate respondsToSelector:@selector(dragInteraction:previewForLiftingItem:session:)])
            preview = [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self previewForLiftingItem:session.items.firstObject session:session];
        if (preview)
            [self revenant_showPreview:preview.view at:point inView:view];
        else
            [self revenant_showView:under at:point inView:view];
        if ([_delegate respondsToSelector:@selector(dragInteraction:sessionWillBegin:)])
            [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self sessionWillBegin:session];
        break;
    }
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        [self revenant_finishDragCancelled:recognizer.state != UIGestureRecognizerStateEnded];
        break;
    default:
        break;
    }
}

- (void)revenant_carry:(UIPanGestureRecognizer *)recognizer
{
    RevenantDragSession *session = self.session;
    if (!session)
        return;
    UIView *view = recognizer.view;
    CGPoint point = [recognizer locationInView:view];
    session.location = point;
    switch (recognizer.state) {
    case UIGestureRecognizerStateBegan:
    case UIGestureRecognizerStateChanged:
        [self revenant_movePreviewTo:point inView:view];
        [self revenant_updateDropUnder:point inView:view];
        if ([_delegate respondsToSelector:@selector(dragInteraction:sessionDidMove:)])
            [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self sessionDidMove:session];
        break;
    case UIGestureRecognizerStateEnded:
        [self revenant_finishDragCancelled:NO];
        break;
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
        [self revenant_finishDragCancelled:YES];
        break;
    default:
        break;
    }
}

- (NSArray<UIDragItem *> *)revenant_defaultItemsForView:(UIView *)view
{
    (void)view;
    return @[];
}

- (void)revenant_showPreview:(UIView *)preview at:(CGPoint)point inView:(UIView *)view
{
    [self revenant_showView:preview at:point inView:view];
}

- (void)revenant_showView:(UIView *)shown at:(CGPoint)point inView:(UIView *)view
{
    UIWindow *window = view.window;
    if (!window || !shown)
        return;
    UIImage *picture = [self revenant_pictureForView:shown];
    if (!picture)
        return;
    UIImageView *image = [[UIImageView alloc] initWithImage:picture];
    image.frame = CGRectMake(point.x - picture.size.width / 2, point.y - picture.size.height / 2,
                             picture.size.width, picture.size.height);
    image.layer.zPosition = 10000;
    [window addSubview:image];
    self.preview = image;
}

- (UIImage *)revenant_pictureForView:(UIView *)view
{
    if (!view || CGRectIsEmpty(view.bounds))
        return nil;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *picture = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return picture;
}

- (void)revenant_movePreviewTo:(CGPoint)point inView:(UIView *)view
{
    UIImageView *preview = self.preview;
    UIWindow *window = view.window;
    if (!preview || !window)
        return;
    CGPoint inWindow = [window convertPoint:point fromView:view];
    preview.center = inWindow;
}

- (void)revenant_updateDropUnder:(CGPoint)point inView:(UIView *)view
{
    for (UIDropInteraction *drop in self.dropTargets) {
        UIView *dropView = drop.view;
        if (!dropView || !dropView.window || ![drop isEnabled])
            continue;
        if (![dropView pointInside:[dropView convertPoint:point fromView:view] withEvent:nil])
            continue;
        RevenantDropSession *session = [[RevenantDropSession alloc] initWithDragSession:self.session interaction:drop];
        id<UIDropInteractionDelegate> delegate = drop.delegate;
        if ([delegate respondsToSelector:@selector(dropInteraction:canHandleSession:)])
            if (![(id<UIDropInteractionDelegate>)delegate dropInteraction:drop canHandleSession:session])
                continue;
        if (self.currentDrop.interaction != drop) {
            [self revenant_exitCurrentDrop];
            self.currentDrop = session;
            if ([delegate respondsToSelector:@selector(dropInteraction:sessionDidEnter:)])
                [(id<UIDropInteractionDelegate>)delegate dropInteraction:drop sessionDidEnter:session];
        }
        if ([delegate respondsToSelector:@selector(dropInteraction:sessionDidUpdate:)])
            [(id<UIDropInteractionDelegate>)delegate dropInteraction:drop sessionDidUpdate:session];
        return;
    }
    [self revenant_exitCurrentDrop];
}

- (void)revenant_exitCurrentDrop
{
    RevenantDropSession *current = self.currentDrop;
    if (!current)
        return;
    id<UIDropInteractionDelegate> delegate = current.interaction.delegate;
    if ([delegate respondsToSelector:@selector(dropInteraction:sessionDidExit:)])
        [(id<UIDropInteractionDelegate>)delegate dropInteraction:current.interaction sessionDidExit:current];
    self.currentDrop = nil;
}

- (void)revenant_finishDragCancelled:(BOOL)cancelled
{
    RevenantDragSession *session = self.session;
    if (!session)
        return;
    UIDropOperation operation = UIDropOperationCancel;
    RevenantDropSession *drop = self.currentDrop;
    if (drop && !cancelled) {
        id<UIDropInteractionDelegate> delegate = drop.interaction.delegate;
        if ([delegate respondsToSelector:@selector(dropInteraction:performDrop:)])
            [(id<UIDropInteractionDelegate>)delegate dropInteraction:drop.interaction performDrop:drop];
        if ([delegate respondsToSelector:@selector(dropInteraction:concludeDrop:)])
            [(id<UIDropInteractionDelegate>)delegate dropInteraction:drop.interaction concludeDrop:drop];
        if ([delegate respondsToSelector:@selector(dropInteraction:sessionDidEnd:)])
            [(id<UIDropInteractionDelegate>)delegate dropInteraction:drop.interaction sessionDidEnd:drop];
        operation = UIDropOperationMove;
    }
    if ([_delegate respondsToSelector:@selector(dragInteraction:session:willEndWithOperation:)])
        [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self session:session willEndWithOperation:operation];
    [self.preview removeFromSuperview];
    self.preview = nil;
    self.currentDrop = nil;
    self.session = nil;
    if ([_delegate respondsToSelector:@selector(dragInteraction:session:didEndWithOperation:)])
        [(id<UIDragInteractionDelegate>)_delegate dragInteraction:self session:session didEndWithOperation:operation];
}

@end

@interface UIDropInteraction () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UILongPressGestureRecognizer *accept;
@end
