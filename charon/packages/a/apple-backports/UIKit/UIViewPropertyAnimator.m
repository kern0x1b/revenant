#import "CharonTimingParameters.h"
#include <math.h>
#include "../CharonBezier.h"

/* The animator runs the animation blocks through UIView's own animation, and, when
   it is interruptible, immediately stops the layers it touched and moves their time
   itself. That is what UIKit does: an interruptible animator is paused the moment it
   starts, its curve replaced by a linear one, and the real curve applied by moving
   the animation's time along it. A non-interruptible animator is left to run. */

@interface CharonAnimatorDriver : NSObject
@end

@implementation CharonAnimatorDriver {
@private
    CADisplayLink *_link;
    __weak UIViewPropertyAnimator *_animator;
}

- (instancetype)initWithAnimator:(UIViewPropertyAnimator *)animator
{
    if ((self = [super init])) {
        _animator = animator;
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(step)];
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)step
{
    UIViewPropertyAnimator *animator = _animator;
    if (!animator || !animator.isRunning) {
        [self invalidate];
        return;
    }
    [animator performSelector:@selector(_advance)];
}

- (void)invalidate
{
    [_link invalidate];
    _link = nil;
}

@end

@implementation UIViewPropertyAnimator {
@private
    NSTimeInterval _duration;
    NSTimeInterval _delay;
    NSTimeInterval _internalDuration;
    id <UITimingCurveProvider> _timingParameters;
    UIViewAnimatingState _state;
    BOOL _running;
    BOOL _reversed;
    BOOL _interruptible;
    BOOL _userInteractionEnabled;
    BOOL _manualHitTestingEnabled;
    BOOL _scrubsLinearly;
    BOOL _pausesOnCompletion;
    BOOL _blocksWaiting;
    CGFloat _fractionComplete;
    UIViewAnimatingPosition _finishingPosition;
    NSMutableArray *_animations;
    NSMutableArray *_completions;
    NSMutableArray *_layers;
    CharonAnimatorDriver *_driver;
    CFTimeInterval _startedAt;
}

+ (instancetype)runningPropertyAnimatorWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
                                            options:(UIViewAnimationOptions)options
                                         animations:(void (^)(void))animations
                                         completion:(void (^)(UIViewAnimatingPosition))completion
{
    UIViewAnimationCurve curve = (UIViewAnimationCurve)((options & 0xc0000) >> 16);
    UIViewPropertyAnimator *animator =
        [[self alloc] initWithDuration:duration
                      timingParameters:[[UICubicTimingParameters alloc] initWithAnimationCurve:curve]];
    if (animations)
        [animator addAnimations:animations];
    if (completion)
        [animator addCompletion:completion];
    [animator startAnimationAfterDelay:delay];
    return animator;
}

- (instancetype)init
{
    return [self initWithDuration:0.25 timingParameters:[UICubicTimingParameters new]];
}

- (instancetype)initWithDuration:(NSTimeInterval)duration timingParameters:(id <UITimingCurveProvider>)parameters
{
    if ((self = [super init]))
        [self charon_setUpWithDuration:duration timingParameters:parameters animations:nil];
    return self;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve
                      animations:(void (^)(void))animations
{
    self = [self initWithDuration:duration
                 timingParameters:[[UICubicTimingParameters alloc] initWithAnimationCurve:curve]];
    if (self && animations)
        [self addAnimations:animations];
    return self;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration controlPoint1:(CGPoint)point1 controlPoint2:(CGPoint)point2
                      animations:(void (^)(void))animations
{
    self = [self initWithDuration:duration
                 timingParameters:[[UICubicTimingParameters alloc] initWithControlPoint1:point1
                                                                          controlPoint2:point2]];
    if (self && animations)
        [self addAnimations:animations];
    return self;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration dampingRatio:(CGFloat)ratio
                      animations:(void (^)(void))animations
{
    self = [self initWithDuration:duration
                 timingParameters:[[UISpringTimingParameters alloc] initWithDampingRatio:ratio]];
    if (self && animations)
        [self addAnimations:animations];
    return self;
}

- (void)charon_setUpWithDuration:(NSTimeInterval)duration timingParameters:(id <UITimingCurveProvider>)parameters
                      animations:(void (^)(void))animations
{
    _duration = duration;
    _internalDuration = duration;
    _timingParameters = [(NSObject *)parameters copy];
    _finishingPosition = UIViewAnimatingPositionEnd;
    _state = UIViewAnimatingStateInactive;
    _interruptible = YES;
    _userInteractionEnabled = YES;
    _scrubsLinearly = YES;
    _animations = [[NSMutableArray alloc] init];
    _layers = [[NSMutableArray alloc] init];
    if (animations)
        [self addAnimations:animations];
}


#pragma mark - Driving the layers

/* Where along its curve the animation stands at a fraction of its time. */
static double charon_curve_at(id <UITimingCurveProvider> parameters, double fraction)
{
    if (fraction <= 0)
        return 0;
    if (fraction >= 1)
        return 1;
    if (parameters.timingCurveType == UITimingCurveTypeSpring) {
        UISpringTimingParameters *spring = parameters.springTimingParameters;
        double ratio = spring.dampingRatio, velocity = spring.initialVelocity.dy;
        double omega = charon_spring_frequency(1, ratio, velocity);
        return charon_spring_progress(omega, ratio, velocity, fraction);
    }
    UICubicTimingParameters *cubic = parameters.cubicTimingParameters;
    CGPoint first = cubic.controlPoint1, second = cubic.controlPoint2;
    /* The cubic Bézier of Core Animation: x and y both run on the control points. */
    return charon_bezier_progress(first.x, first.y, second.x, second.y, fraction);
}

static void charon_walk(CALayer *layer, void (^visit)(CALayer *))
{
    visit(layer);
    for (CALayer *sublayer in layer.sublayers)
        charon_walk(sublayer, visit);
}

/* Which animations are on every layer of every window right now, so that what the
   blocks add can be told from what was already running. */
static NSMapTable *charon_animation_keys(void)
{
    NSMapTable *keys = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality
                                             valueOptions:NSPointerFunctionsStrongMemory];
    for (UIWindow *window in [UIApplication sharedApplication].windows)
        charon_walk(window.layer, ^(CALayer *layer) {
            NSArray *animations = layer.animationKeys;
            if (animations.count)
                [keys setObject:[NSSet setWithArray:animations] forKey:layer];
        });
    return keys;
}


#pragma mark - What the animation was asked for

- (NSTimeInterval)duration
{
    return _duration;
}

- (NSTimeInterval)delay
{
    return _delay;
}

- (NSTimeInterval)internalDuration
{
    return _internalDuration;
}

- (id <UITimingCurveProvider>)timingParameters
{
    return _timingParameters;
}

- (UIViewAnimatingState)state
{
    return _state;
}

- (BOOL)isRunning
{
    return _running;
}

- (BOOL)isInterruptible
{
    return _interruptible;
}

- (void)setInterruptible:(BOOL)interruptible
{
    if (_state == UIViewAnimatingStateActive) {
        [NSException raise:NSGenericException
                    format:@"It is not allowed to set the interruptible property of an active animator (%@)", self];
        return;
    }
    _interruptible = interruptible;
}

- (BOOL)scrubsLinearly
{
    return _scrubsLinearly;
}

- (void)setScrubsLinearly:(BOOL)scrubsLinearly
{
    if (_state == UIViewAnimatingStateActive && !_running) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot modify scrubsLinearly while animation is already paused"];
        return;
    }
    _scrubsLinearly = scrubsLinearly;
}

- (BOOL)pausesOnCompletion
{
    return _pausesOnCompletion;
}

- (void)setPausesOnCompletion:(BOOL)pausesOnCompletion
{
    _pausesOnCompletion = pausesOnCompletion;
}

- (BOOL)isUserInteractionEnabled
{
    return _userInteractionEnabled;
}

- (void)setUserInteractionEnabled:(BOOL)enabled
{
    _userInteractionEnabled = enabled;
}

- (BOOL)isManualHitTestingEnabled
{
    return _manualHitTestingEnabled;
}

- (void)setManualHitTestingEnabled:(BOOL)enabled
{
    _manualHitTestingEnabled = enabled;
}

#pragma mark - The blocks

- (void)addAnimations:(void (^)(void))animation
{
    [self addAnimations:animation delayFactor:0];
}

- (void)addAnimations:(void (^)(void))animation delayFactor:(CGFloat)delayFactor
{
    if (!animation)
        return;
    [_animations addObject:@[[animation copy], @(delayFactor)]];
    if (_state == UIViewAnimatingStateActive)
        [self charon_runBlock:animation afterFactor:delayFactor];
    else if (_state == UIViewAnimatingStateInactive)
        _blocksWaiting = YES;
}

- (void)addCompletion:(void (^)(UIViewAnimatingPosition))completion
{
    if (!completion)
        return;
    if (!_completions)
        _completions = [[NSMutableArray alloc] init];
    [_completions addObject:[completion copy]];
}

#pragma mark - Running

- (void)startAnimation
{
    NSAssert(_animations.count > 0, @"An animator (%@) must have at least one animation block to start!", self);
    if (_state == UIViewAnimatingStateActive && !_running) {
        NSAssert(_interruptible, @"An animator (%@) can be only started in the paused state if it is interruptible!", self);
        [self charon_resume];
        return;
    }
    if (_state != UIViewAnimatingStateInactive)
        return;
    [self charon_start];
}

- (void)startAnimationAfterDelay:(NSTimeInterval)delay
{
    NSAssert(!(_state == UIViewAnimatingStateActive && !_running),
             @"A paused animator (%@) cannot be started with a delay!", self);
    if (delay < 0) {
        [NSException raise:NSInvalidArgumentException format:@"The delay should be greater than or equal to zero."];
        return;
    }
    _delay = delay;
    [self startAnimation];
}

- (void)pauseAnimation
{
    NSAssert(_interruptible, @"An animator %@ that is not interruptible cannot be paused!", self);
    if (_state == UIViewAnimatingStateInactive)
        [self charon_start];
    [self willChangeValueForKey:@"fractionComplete"];
    [self charon_pause];
    [self didChangeValueForKey:@"fractionComplete"];
    [self charon_setRunning:NO];
}

- (void)stopAnimation:(BOOL)withoutFinishing
{
    NSAssert(_interruptible, @"An animator %@ that is not interruptible cannot be stopped!", self);
    NSAssert(_state != UIViewAnimatingStateStopped, @"Animator %@ is already stopped!", self);
    if (_state == UIViewAnimatingStateInactive)
        return;
    [self charon_settleAtCurrentPosition];
    [self charon_setRunning:NO];
    [self charon_setReversed:NO];
    if (!withoutFinishing) {
        [self charon_setState:UIViewAnimatingStateStopped];
        return;
    }
    _completions = nil;
    _finishingPosition = UIViewAnimatingPositionCurrent;
    [self charon_runCompletions];
    [self charon_setState:UIViewAnimatingStateInactive];
}

- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)finalPosition
{
    NSAssert(_state == UIViewAnimatingStateStopped || (_state == UIViewAnimatingStateInactive && !_blocksWaiting),
             @"finishAnimationAtPosition: should only be called on a stopped animator!");
    if (_state != UIViewAnimatingStateStopped)
        return;
    _finishingPosition = finalPosition;
    if (finalPosition != UIViewAnimatingPositionCurrent)
        [self charon_setFraction:finalPosition == UIViewAnimatingPositionEnd ? 1 : 0];
    [self charon_runCompletions];
    [self charon_setState:UIViewAnimatingStateInactive];
}

- (void)continueAnimationWithTimingParameters:(id <UITimingCurveProvider>)parameters durationFactor:(CGFloat)durationFactor
{
    NSAssert(_interruptible, @"An animator %@ that is not interruptible cannot be continued or reversed!", self);
    if (_state != UIViewAnimatingStateActive || _running)
        return;
    if (parameters)
        _timingParameters = [(NSObject *)parameters copy];
    if (durationFactor > 0)
        _internalDuration = _duration * durationFactor;
    [self charon_resume];
}

#pragma mark - Scrubbing

- (CGFloat)fractionComplete
{
    return _fractionComplete;
}

- (void)setFractionComplete:(CGFloat)fractionComplete
{
    fractionComplete = MIN(MAX(fractionComplete, 0), 1);
    if (fractionComplete == _fractionComplete)
        return;
    if (_state == UIViewAnimatingStateInactive) {
        if (!_blocksWaiting)
            return;
        [self pauseAnimation];
    } else if (_state != UIViewAnimatingStateActive) {
        return;
    }
    BOOL wasRunning = _running;
    if (wasRunning)
        [self charon_pause];
    [self willChangeValueForKey:@"fractionComplete"];
    [self charon_setFraction:fractionComplete];
    [self didChangeValueForKey:@"fractionComplete"];
    if (wasRunning)
        [self charon_resume];
}

- (BOOL)isReversed
{
    return _reversed;
}

- (void)setReversed:(BOOL)reversed
{
    if (_reversed == reversed)
        return;
    BOOL wasRunning = _running;
    if (wasRunning)
        [self charon_pause];
    [self charon_setReversed:reversed];
    if (wasRunning)
        [self charon_resume];
}


#pragma mark - The private half

- (void)charon_setState:(UIViewAnimatingState)state
{
    if (_state == state)
        return;
    [self willChangeValueForKey:@"state"];
    _state = state;
    [self didChangeValueForKey:@"state"];
}

- (void)charon_setRunning:(BOOL)running
{
    if (_running == running)
        return;
    [self willChangeValueForKey:@"running"];
    _running = running;
    [self didChangeValueForKey:@"running"];
}

- (void)charon_setReversed:(BOOL)reversed
{
    if (_reversed == reversed)
        return;
    [self willChangeValueForKey:@"reversed"];
    _reversed = reversed;
    [self didChangeValueForKey:@"reversed"];
}

- (void)charon_runBlock:(void (^)(void))block afterFactor:(CGFloat)delayFactor
{
    [UIView animateWithDuration:_internalDuration * (1 - delayFactor)
                          delay:_delay + _internalDuration * delayFactor
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:block
                     completion:nil];
}

- (void)charon_start
{
    _blocksWaiting = NO;
    [self charon_setState:UIViewAnimatingStateActive];
    _finishingPosition = UIViewAnimatingPositionEnd;
    [_layers removeAllObjects];
    NSMapTable *before = charon_animation_keys();
    for (NSArray *entry in _animations)
        [self charon_runBlock:entry[0] afterFactor:[entry[1] doubleValue]];
    /* Only what these blocks added belongs to this animator. Freezing every layer
       that happens to be animating would stop animations that are not ours, and
       two animators at once would each stop the other. */
    for (UIWindow *window in [UIApplication sharedApplication].windows)
        charon_walk(window.layer, ^(CALayer *layer) {
            NSSet *was = [before objectForKey:layer];
            for (NSString *key in layer.animationKeys)
                if (![was containsObject:key])
                    [self->_layers addObject:@[layer, key]];
        });
    _startedAt = CACurrentMediaTime();
    [self charon_setRunning:YES];
    if (!_interruptible)
        return;
    /* Interruptible: the animations this animator added are stopped where they are
       and their time is moved from here on, which is what UIKit does the moment
       such an animator starts. The animation is stopped rather than the layer, so
       anything else animating the same layer keeps running. */
    [self charon_setFraction:0];
    _driver = [[CharonAnimatorDriver alloc] initWithAnimator:self];
}

- (void)charon_pause
{
    [_driver invalidate];
    _driver = nil;
}

- (void)charon_resume
{
    if (_state != UIViewAnimatingStateActive)
        return;
    _startedAt = CACurrentMediaTime() - (_reversed ? (1 - _fractionComplete) : _fractionComplete) * _internalDuration;
    [self charon_setRunning:YES];
    if (!_driver)
        _driver = [[CharonAnimatorDriver alloc] initWithAnimator:self];
}

/* An animation already on a layer cannot be changed in place, so the one to show
   is built afresh and put back under the same key - which is what UIKit's own
   animation factory does. The animation is held still by its own speed, not the
   layer's, so it is the only thing this animator moves. */
- (void)charon_setFraction:(CGFloat)fraction
{
    _fractionComplete = MIN(MAX(fraction, 0), 1);
    [self charon_show:_scrubsLinearly ? _fractionComplete : charon_curve_at(_timingParameters, _fractionComplete)];
}

- (void)charon_show:(CGFloat)progress
{
    for (NSArray *tracked in _layers) {
        CALayer *layer = tracked[0];
        NSString *key = tracked[1];
        CAAnimation *animation = [[layer animationForKey:key] copy];
        if (!animation)
            continue;
        animation.speed = 0;
        animation.timeOffset = progress * _internalDuration;
        animation.fillMode = kCAFillModeBoth;
        animation.removedOnCompletion = NO;
        [layer addAnimation:animation forKey:key];
    }
}

- (void)_advance
{
    double elapsed = (CACurrentMediaTime() - _startedAt) / (_internalDuration > 0 ? _internalDuration : 1);
    if (_reversed)
        elapsed = 1 - elapsed;
    double bounded = MIN(MAX(elapsed, 0.0), 1.0);
    double progress = charon_curve_at(_timingParameters, bounded);
    _fractionComplete = _scrubsLinearly ? progress : bounded;
    [self charon_show:progress];
    if ((!_reversed && elapsed < 1) || (_reversed && elapsed > 0))
        return;
    [self charon_setRunning:NO];
    [_driver invalidate];
    _driver = nil;
    if (_pausesOnCompletion)
        return;
    _finishingPosition = _reversed ? UIViewAnimatingPositionStart : UIViewAnimatingPositionEnd;
    [self charon_settleAtCurrentPosition];
    [self charon_runCompletions];
    [self charon_setState:UIViewAnimatingStateInactive];
}

- (void)charon_settleAtCurrentPosition
{
    [_driver invalidate];
    _driver = nil;
    for (NSArray *tracked in _layers)
        [tracked[0] removeAnimationForKey:tracked[1]];
}

- (void)charon_runCompletions
{
    NSArray *completions = _completions;
    _completions = nil;
    for (void (^completion)(UIViewAnimatingPosition) in completions)
        completion(_finishingPosition);
    [_layers removeAllObjects];
}

/* A copy carries what the animation was asked for, not what it is doing: the
   blocks, the completions and the state are left behind. */
- (id)copyWithZone:(NSZone *)zone
{
    UIViewPropertyAnimator *copy = [[[self class] allocWithZone:zone] init];
    [copy charon_setUpWithDuration:self.duration timingParameters:self.timingParameters animations:nil];
    copy.userInteractionEnabled = self.isUserInteractionEnabled;
    copy.interruptible = self.isInterruptible;
    return copy;
}

#pragma mark - Describing

- (NSString *)_stateAsString
{
    switch (_state) {
        case UIViewAnimatingStateInactive: return @"inactive";
        case UIViewAnimatingStateStopped: return @"stopped";
        case UIViewAnimatingStateActive: return @"active";
        default: return @"unknown";
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@(%p) [%@]%@%@%@>", [self class], self, [self _stateAsString],
                                      _running ? @" running" : @"", _reversed ? @" reversed" : @"",
                                      _interruptible ? @" interruptible" : @""];
}

@end
