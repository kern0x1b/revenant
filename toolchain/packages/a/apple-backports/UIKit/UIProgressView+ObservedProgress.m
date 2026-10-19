#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_observed_key;
static void *const revenant_observed_context = (void *)&revenant_observed_key;

@interface RevenantProgressObserver : NSObject
@property (nonatomic, weak) UIProgressView *view;
@property (nonatomic, strong) NSProgress *progress;
- (void)stop;
@end

@implementation RevenantProgressObserver {
    BOOL _observing;
}

@synthesize view = _view, progress = _progress;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != revenant_observed_context) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    float fraction = (float)self.progress.fractionCompleted;
    if ([NSThread isMainThread]) {
        self.view.progress = fraction;
        return;
    }
    __weak RevenantProgressObserver *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.view.progress = fraction;
    });
}

- (void)start
{
    if (_observing)
        return;
    _observing = YES;
    [_progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionInitial context:revenant_observed_context];
}

- (void)stop
{
    if (!_observing)
        return;
    _observing = NO;
    [_progress removeObserver:self forKeyPath:@"fractionCompleted" context:revenant_observed_context];
}

- (void)dealloc
{
    [self stop];
}

@end

@implementation UIProgressView (RevenantObservedProgress)

- (NSProgress *)observedProgress
{
    return [(RevenantProgressObserver *)objc_getAssociatedObject(self, &revenant_observed_key) progress];
}

- (void)setObservedProgress:(NSProgress *)observedProgress
{
    RevenantProgressObserver *observer = objc_getAssociatedObject(self, &revenant_observed_key);
    if (observer.progress == observedProgress || [observer.progress isEqual:observedProgress])
        return;
    [observer stop];
    objc_setAssociatedObject(self, &revenant_observed_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!observedProgress)
        return;
    RevenantProgressObserver *fresh = [[RevenantProgressObserver alloc] init];
    fresh.view = self;
    fresh.progress = observedProgress;
    objc_setAssociatedObject(self, &revenant_observed_key, fresh, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [fresh start];
}

@end
