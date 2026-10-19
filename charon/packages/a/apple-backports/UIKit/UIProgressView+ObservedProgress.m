#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_observed_key;
static void *const charon_observed_context = (void *)&charon_observed_key;

@interface CharonProgressObserver : NSObject
@property (nonatomic, weak) UIProgressView *view;
@property (nonatomic, strong) NSProgress *progress;
- (void)stop;
@end

@implementation CharonProgressObserver {
    BOOL _observing;
}

@synthesize view = _view, progress = _progress;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != charon_observed_context) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    float fraction = (float)self.progress.fractionCompleted;
    if ([NSThread isMainThread]) {
        self.view.progress = fraction;
        return;
    }
    __weak CharonProgressObserver *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.view.progress = fraction;
    });
}

- (void)start
{
    if (_observing)
        return;
    _observing = YES;
    [_progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionInitial context:charon_observed_context];
}

- (void)stop
{
    if (!_observing)
        return;
    _observing = NO;
    [_progress removeObserver:self forKeyPath:@"fractionCompleted" context:charon_observed_context];
}

- (void)dealloc
{
    [self stop];
}

@end

@implementation UIProgressView (CharonObservedProgress)

- (NSProgress *)observedProgress
{
    return [(CharonProgressObserver *)objc_getAssociatedObject(self, &charon_observed_key) progress];
}

- (void)setObservedProgress:(NSProgress *)observedProgress
{
    CharonProgressObserver *observer = objc_getAssociatedObject(self, &charon_observed_key);
    if (observer.progress == observedProgress || [observer.progress isEqual:observedProgress])
        return;
    [observer stop];
    objc_setAssociatedObject(self, &charon_observed_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!observedProgress)
        return;
    CharonProgressObserver *fresh = [[CharonProgressObserver alloc] init];
    fresh.view = self;
    fresh.progress = observedProgress;
    objc_setAssociatedObject(self, &charon_observed_key, fresh, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [fresh start];
}

@end
