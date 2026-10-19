#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char CharonTransitionKey;
static const NSTimeInterval CharonTransitionDuration = 0.35;

@interface CharonPendingLayout : NSObject
@property (nonatomic, strong) UICollectionViewLayout *layout;
@property (nonatomic, copy) void (^completion)(BOOL finished);
@end

@implementation CharonPendingLayout
@synthesize layout = _layout;
@synthesize completion = _completion;
@end

@interface CharonLayoutTransition : NSObject
@property (nonatomic, strong) UICollectionViewTransitionLayout *layout;
@property (nonatomic, strong) UICollectionViewLayout *from;
@property (nonatomic, strong) UICollectionViewLayout *to;
@property (nonatomic, copy) UICollectionViewLayoutInteractiveTransitionCompletion completion;
@property (nonatomic, strong) UICollectionView *view;
@property (nonatomic) CGFloat start;
@property (nonatomic) CGFloat target;
@property (nonatomic) BOOL finishing;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *began;
@property (nonatomic, strong) NSMutableArray<CharonPendingLayout *> *pending;
@end

@implementation CharonLayoutTransition
@synthesize layout = _layout;
@synthesize from = _from;
@synthesize to = _to;
@synthesize completion = _completion;
@synthesize view = _view;
@synthesize start = _start;
@synthesize target = _target;
@synthesize finishing = _finishing;
@synthesize timer = _timer;
@synthesize began = _began;
@synthesize pending = _pending;

- (void)tick
{
    NSTimeInterval elapsed = -[_began timeIntervalSinceNow];
    CGFloat span = _target - _start;
    CGFloat progress = elapsed >= CharonTransitionDuration ? _target
                       : _start + span * (CGFloat)(elapsed / CharonTransitionDuration);
    _layout.transitionProgress = progress;
    if (elapsed < CharonTransitionDuration)
        return;
    [_timer invalidate];
    _timer = nil;
    UICollectionView *view = _view;
    UICollectionViewLayout *settled = span >= 0 ? _to : _from;
    BOOL finished = span >= 0;
    view.collectionViewLayout = settled;
    for (CharonPendingLayout *waiting in _pending) {
        view.collectionViewLayout = waiting.layout;
        if (waiting.completion)
            waiting.completion(YES);
    }
    [_pending removeAllObjects];
    objc_setAssociatedObject(view, &CharonTransitionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_layout finalizeLayoutTransition];
    UICollectionViewLayoutInteractiveTransitionCompletion completion = _completion;
    _completion = nil;
    if (completion)
        completion(finished, YES);
}
@end

@implementation UICollectionView (CharonInteractiveTransition)

- (CharonLayoutTransition *)charon_layoutTransition
{
    return objc_getAssociatedObject(self, &CharonTransitionKey);
}

- (UICollectionViewTransitionLayout *)startInteractiveTransitionToCollectionViewLayout:(UICollectionViewLayout *)layout
                                                                            completion:(UICollectionViewLayoutInteractiveTransitionCompletion)completion
{
    if (!layout || layout == self.collectionViewLayout || [self charon_layoutTransition])
        return nil;
    UICollectionViewLayout *from = self.collectionViewLayout;
    CharonLayoutTransition *transition = [[CharonLayoutTransition alloc] init];
    transition.from = from;
    transition.to = layout;
    transition.view = self;
    transition.completion = completion;
    transition.layout = [[UICollectionViewTransitionLayout alloc] initWithCurrentLayout:from nextLayout:layout];
    transition.start = transition.layout.transitionProgress;
    transition.pending = [NSMutableArray array];
    objc_setAssociatedObject(self, &CharonTransitionKey, transition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [from prepareForTransitionToLayout:layout];
    [layout prepareForTransitionFromLayout:from];
    self.collectionViewLayout = transition.layout;
    return transition.layout;
}

- (void)charon_settleLayoutTransition:(CharonLayoutTransition *)transition target:(CGFloat)target
{
    if (transition.finishing)
        return;
    transition.finishing = YES;
    [transition.timer invalidate];
    transition.start = transition.layout.transitionProgress;
    transition.target = target;
    transition.began = [NSDate date];
    transition.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60
                                                       target:transition
                                                     selector:@selector(tick)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)finishInteractiveTransition
{
    CharonLayoutTransition *transition = [self charon_layoutTransition];
    if (!transition)
        return;
    [self charon_settleLayoutTransition:transition target:1.0];
}

- (void)cancelInteractiveTransition
{
    CharonLayoutTransition *transition = [self charon_layoutTransition];
    if (!transition)
        return;
    [self charon_settleLayoutTransition:transition target:0.0];
}

- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout animated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
    if (!layout) {
        if (completion)
            completion(NO);
        return;
    }
    if (!animated) {
        self.collectionViewLayout = layout;
        if (completion)
            completion(YES);
        return;
    }
    CharonLayoutTransition *running = [self charon_layoutTransition];
    if (running) {
        CharonPendingLayout *waiting = [[CharonPendingLayout alloc] init];
        waiting.layout = layout;
        waiting.completion = completion;
        [running.pending addObject:waiting];
        return;
    }
    UICollectionViewTransitionLayout *transition =
        [self startInteractiveTransitionToCollectionViewLayout:layout
                                                    completion:^(BOOL completed, BOOL finished) {
        if (completion)
            completion(finished);
    }];
    if (!transition) {
        self.collectionViewLayout = layout;
        if (completion)
            completion(YES);
        return;
    }
    [self finishInteractiveTransition];
}

@end
