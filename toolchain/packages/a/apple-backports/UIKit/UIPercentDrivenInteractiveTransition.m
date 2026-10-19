#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "CharonCustomTransition.h"

static void charon_copy_presentation(CALayer *layer)
{
    CALayer *shown = layer.presentationLayer;
    if (shown && shown != layer) {
        layer.bounds = shown.bounds;
        layer.position = shown.position;
        layer.anchorPoint = shown.anchorPoint;
        layer.zPosition = shown.zPosition;
        layer.transform = shown.transform;
        layer.sublayerTransform = shown.sublayerTransform;
        layer.opacity = shown.opacity;
        layer.backgroundColor = shown.backgroundColor;
        layer.cornerRadius = shown.cornerRadius;
        layer.borderWidth = shown.borderWidth;
        layer.borderColor = shown.borderColor;
        layer.contentsRect = shown.contentsRect;
        layer.shadowOpacity = shown.shadowOpacity;
        layer.shadowOffset = shown.shadowOffset;
        layer.shadowRadius = shown.shadowRadius;
        layer.shadowColor = shown.shadowColor;
    }
    for (CALayer *sublayer in layer.sublayers)
        charon_copy_presentation(sublayer);
}

static void charon_remove_animations(CALayer *layer)
{
    [layer removeAllAnimations];
    for (CALayer *sublayer in layer.sublayers)
        charon_remove_animations(sublayer);
}

@interface CharonLinkTarget : NSObject
@property (nonatomic, copy) void (^tick)(void);
@property (nonatomic) BOOL done;
- (void)fire:(CADisplayLink *)link;
@end

@implementation CharonLinkTarget
@synthesize tick = _tick;
@synthesize done = _done;

- (void)fire:(CADisplayLink *)link
{
    if (_done)
        return;
    _tick();
}
@end

@implementation UIPercentDrivenInteractiveTransition {
    id<UIViewControllerContextTransitioning> _context;
    id<UIViewControllerAnimatedTransitioning> _animator;
    CGFloat _duration;
    CGFloat _percentComplete;
    CGFloat _completionSpeed;
    UIViewAnimationCurve _completionCurve;
    BOOL _wantsInteractiveStart;
    id _timingCurve;
    CADisplayLink *_link;
    CFTimeInterval _linkStart;
    CGFloat _linkFrom, _linkTo, _linkSeconds;
    BOOL _finishing;
    BOOL _cancelling;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _completionSpeed = 1;
        _completionCurve = (UIViewAnimationCurve)7;
        _wantsInteractiveStart = YES;
    }
    return self;
}

- (CGFloat)duration
{
    return _duration;
}

- (CGFloat)percentComplete
{
    return _percentComplete;
}

- (CGFloat)completionSpeed
{
    return _completionSpeed;
}

- (void)setCompletionSpeed:(CGFloat)speed
{
    _completionSpeed = speed;
}

- (UIViewAnimationCurve)completionCurve
{
    return _completionCurve;
}

- (void)setCompletionCurve:(UIViewAnimationCurve)curve
{
    _completionCurve = curve;
}

- (BOOL)wantsInteractiveStart
{
    return _wantsInteractiveStart;
}

- (void)setWantsInteractiveStart:(BOOL)wants
{
    _wantsInteractiveStart = wants;
}

- (id<UITimingCurveProvider>)timingCurve
{
    return _timingCurve;
}

- (void)setTimingCurve:(id<UITimingCurveProvider>)curve
{
    _timingCurve = curve;
}

- (CALayer *)charon_layer
{
    return _context.containerView.layer;
}

- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    _context = transitionContext;
    _percentComplete = 0;
    _finishing = _cancelling = NO;
    if (![transitionContext respondsToSelector:@selector(charon_animator)])
        return;
    _animator = [(CharonTransitionContext *)transitionContext charon_animator];
    _duration = [_animator transitionDuration:transitionContext];
    [_animator animateTransition:transitionContext];
    CALayer *layer = [self charon_layer];
    layer.speed = 0;
    layer.timeOffset = 0;
}

- (void)charon_seek:(CGFloat)percent
{
    _percentComplete = MAX(0, MIN(1, percent));
    [self charon_layer].timeOffset = MIN(_percentComplete, 0.9999f) * _duration;
}

- (void)updateInteractiveTransition:(CGFloat)percentComplete
{
    if (!_context || _finishing || _cancelling)
        return;
    [self charon_seek:percentComplete];
    [_context updateInteractiveTransition:_percentComplete];
}

- (void)charon_runTo:(CGFloat)target completion:(void (^)(void))completion
{
    [_link invalidate];
    _linkFrom = _percentComplete;
    _linkTo = target;
    CGFloat speed = _completionSpeed > 0 ? _completionSpeed : 1;
    _linkSeconds = _duration > 0 ? fabsf(target - _linkFrom) * _duration / speed : 0;
    if (_linkSeconds <= 0.001f) {
        [self charon_seek:target];
        completion();
        return;
    }
    _linkStart = CACurrentMediaTime();
    __weak UIPercentDrivenInteractiveTransition *weak = self;
    CharonLinkTarget *linkTarget = [[CharonLinkTarget alloc] init];
    __weak CharonLinkTarget *weakTarget = linkTarget;
    linkTarget.tick = ^{
        UIPercentDrivenInteractiveTransition *strong = weak;
        if (!strong)
            return;
        CGFloat t = MIN(1, (CACurrentMediaTime() - strong->_linkStart) / strong->_linkSeconds);
        CGFloat percent = strong->_linkFrom + (strong->_linkTo - strong->_linkFrom) * t;
        strong->_percentComplete = percent;
        [strong charon_layer].timeOffset = MIN(percent, 0.9999f) * strong->_duration;
        if (t >= 1) {
            weakTarget.done = YES;
            CADisplayLink *finished = strong->_link;
            strong->_link = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [finished invalidate];
                completion();
            });
        }
    };
    _link = [CADisplayLink displayLinkWithTarget:linkTarget selector:@selector(fire:)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)finishInteractiveTransition
{
    if (!_context || _finishing || _cancelling)
        return;
    _finishing = YES;
    [_context finishInteractiveTransition];
    id<UIViewControllerContextTransitioning> context = _context;
    CALayer *layer = [self charon_layer];
    CGFloat speed = _completionSpeed > 0 ? _completionSpeed : 1;
    CFTimeInterval paused = layer.timeOffset;
    layer.speed = speed;
    layer.timeOffset = 0;
    layer.beginTime = 0;
    layer.beginTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - paused / speed;
    _percentComplete = _duration > 0 ? paused / _duration : 1;
    NSTimeInterval remaining = (_duration - paused) / speed;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((remaining + 0.6) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [context completeTransition:YES];
    });
}

- (void)cancelInteractiveTransition
{
    if (!_context || _finishing || _cancelling)
        return;
    _cancelling = YES;
    [_context cancelInteractiveTransition];
    id<UIViewControllerContextTransitioning> context = _context;
    CALayer *layer = [self charon_layer];
    [self charon_runTo:0 completion:^{
        layer.timeOffset = 0;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        charon_copy_presentation(layer);
        charon_remove_animations(layer);
        layer.speed = 1;
        layer.timeOffset = 0;
        [CATransaction commit];
        dispatch_async(dispatch_get_main_queue(), ^{
            [context completeTransition:NO];
        });
    }];
}

- (void)pauseInteractiveTransition
{
    [_link invalidate];
    _link = nil;
    [_context pauseInteractiveTransition];
}

@end
