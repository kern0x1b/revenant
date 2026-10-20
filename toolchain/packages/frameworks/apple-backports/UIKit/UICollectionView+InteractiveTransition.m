#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantTransitionKey;
static const NSTimeInterval RevenantTransitionDuration = 0.35;

@interface RevenantPendingLayout : NSObject
@property (nonatomic, strong) UICollectionViewLayout *layout;
@property (nonatomic, copy) void (^completion)(BOOL finished);
@end

@implementation RevenantPendingLayout
@synthesize layout = _layout;
@synthesize completion = _completion;
@end

@interface RevenantLayoutTransition : NSObject
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
@property (nonatomic, strong) NSMutableArray<RevenantPendingLayout *> *pending;
@end

@implementation RevenantLayoutTransition
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
    CGFloat progress = elapsed >= RevenantTransitionDuration ? _target
                       : _start + span * (CGFloat)(elapsed / RevenantTransitionDuration);
    _layout.transitionProgress = progress;
    if (elapsed < RevenantTransitionDuration)
        return;
    [_timer invalidate];
    _timer = nil;
    UICollectionView *view = _view;
    UICollectionViewLayout *settled = span >= 0 ? _to : _from;
    BOOL finished = span >= 0;
    view.collectionViewLayout = settled;
    for (RevenantPendingLayout *waiting in _pending) {
        view.collectionViewLayout = waiting.layout;
        if (waiting.completion)
            waiting.completion(YES);
    }
    [_pending removeAllObjects];
    objc_setAssociatedObject(view, &RevenantTransitionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_layout finalizeLayoutTransition];
    UICollectionViewLayoutInteractiveTransitionCompletion completion = _completion;
    _completion = nil;
    if (completion)
        completion(finished, YES);
}
@end

@implementation UICollectionView (RevenantInteractiveTransition)

- (RevenantLayoutTransition *)revenant_layoutTransition
{
    return objc_getAssociatedObject(self, &RevenantTransitionKey);
}

- (UICollectionViewTransitionLayout *)startInteractiveTransitionToCollectionViewLayout:(UICollectionViewLayout *)layout
                                                                            completion:(UICollectionViewLayoutInteractiveTransitionCompletion)completion
{
    if (!layout || layout == self.collectionViewLayout || [self revenant_layoutTransition])
        return nil;
    UICollectionViewLayout *from = self.collectionViewLayout;
    RevenantLayoutTransition *transition = [[RevenantLayoutTransition alloc] init];
    transition.from = from;
    transition.to = layout;
    transition.view = self;
    transition.completion = completion;
    transition.layout = [[UICollectionViewTransitionLayout alloc] initWithCurrentLayout:from nextLayout:layout];
    transition.start = transition.layout.transitionProgress;
    transition.pending = [NSMutableArray array];
    objc_setAssociatedObject(self, &RevenantTransitionKey, transition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [from prepareForTransitionToLayout:layout];
    [layout prepareForTransitionFromLayout:from];
    self.collectionViewLayout = transition.layout;
    return transition.layout;
}

- (void)revenant_settleLayoutTransition:(RevenantLayoutTransition *)transition target:(CGFloat)target
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
    RevenantLayoutTransition *transition = [self revenant_layoutTransition];
    if (!transition)
        return;
    [self revenant_settleLayoutTransition:transition target:1.0];
}

- (void)cancelInteractiveTransition
{
    RevenantLayoutTransition *transition = [self revenant_layoutTransition];
    if (!transition)
        return;
    [self revenant_settleLayoutTransition:transition target:0.0];
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
    RevenantLayoutTransition *running = [self revenant_layoutTransition];
    if (running) {
        RevenantPendingLayout *waiting = [[RevenantPendingLayout alloc] init];
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
