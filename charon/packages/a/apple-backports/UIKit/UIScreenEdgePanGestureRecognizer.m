#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

static const CGFloat CharonEdgeWidth = 20;

@implementation UIScreenEdgePanGestureRecognizer

@synthesize edges = _edges;

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self)
        self.maximumNumberOfTouches = 1;
    return self;
}

+ (BOOL)charon_point:(CGPoint)point isNearEdges:(UIRectEdge)edges inBounds:(CGRect)bounds
{
    if ((edges & UIRectEdgeLeft) && point.x - CGRectGetMinX(bounds) <= CharonEdgeWidth)
        return YES;
    if ((edges & UIRectEdgeRight) && CGRectGetMaxX(bounds) - point.x <= CharonEdgeWidth)
        return YES;
    if ((edges & UIRectEdgeTop) && point.y - CGRectGetMinY(bounds) <= CharonEdgeWidth)
        return YES;
    if ((edges & UIRectEdgeBottom) && CGRectGetMaxY(bounds) - point.y <= CharonEdgeWidth)
        return YES;
    return NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateFailed || !self.edges) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    UITouch *touch = [touches anyObject];
    UIView *space = self.view.window.rootViewController.view ?: self.view.window ?: self.view;
    CGPoint point = [touch locationInView:space];
    if (![UIScreenEdgePanGestureRecognizer charon_point:point isNearEdges:self.edges inBounds:space.bounds])
        self.state = UIGestureRecognizerStateFailed;
}

@end
