#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static const char RevenantPageProgressKey;

@interface UIPageControlProgress (RevenantControl)
- (void)revenant_attachToControl:(UIPageControl *)control;
- (UIPageControl *)revenant_control;
- (void)revenant_currentPageChanged;
@end

@implementation UIPageControlProgress {
    __weak id<UIPageControlProgressDelegate> _delegate;
    float _currentProgress;
    BOOL _progressVisible;
    __weak UIPageControl *_control;
}

- (id<UIPageControlProgressDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UIPageControlProgressDelegate>)delegate
{
    _delegate = delegate;
}

- (float)currentProgress
{
    return _currentProgress;
}

- (void)setCurrentProgress:(float)currentProgress
{
    _currentProgress = MIN(MAX(currentProgress, 0), 1);
}

- (BOOL)isProgressVisible
{
    return _progressVisible;
}

- (BOOL)progressVisible
{
    return _progressVisible;
}

- (UIPageControl *)revenant_control
{
    return _control;
}

- (void)revenant_attachToControl:(UIPageControl *)control
{
    BOOL visible = control != nil;
    _control = control;
    if (visible && [_delegate respondsToSelector:@selector(pageControlProgress:initialProgressForPage:)])
        _currentProgress = [_delegate pageControlProgress:self initialProgressForPage:control.currentPage];
    else if (!visible)
        _currentProgress = 0;
    if (visible == _progressVisible)
        return;
    _progressVisible = visible;
    if ([_delegate respondsToSelector:@selector(pageControlProgressVisibilityDidChange:)])
        [_delegate pageControlProgressVisibilityDidChange:self];
}

- (void)revenant_currentPageChanged
{
}

@end

@implementation UIPageControlTimerProgress {
    NSTimeInterval _preferredDuration;
    NSMutableDictionary<NSNumber *, NSNumber *> *_durations;
    BOOL _resetsToInitialPageAfterEnd;
    BOOL _running;
    NSTimer *_timer;
    NSDate *_lastTick;
    NSInteger _timedPage;
}

- (instancetype)initWithPreferredDuration:(NSTimeInterval)preferredDuration
{
    if ((self = [super init])) {
        _preferredDuration = preferredDuration;
        _durations = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    [_timer invalidate];
}

- (id<UIPageControlTimerProgressDelegate>)delegate
{
    return (id<UIPageControlTimerProgressDelegate>)[super delegate];
}

- (void)setDelegate:(id<UIPageControlTimerProgressDelegate>)delegate
{
    [super setDelegate:delegate];
}

- (BOOL)resetsToInitialPageAfterEnd
{
    return _resetsToInitialPageAfterEnd;
}

- (void)setResetsToInitialPageAfterEnd:(BOOL)resetsToInitialPageAfterEnd
{
    _resetsToInitialPageAfterEnd = resetsToInitialPageAfterEnd;
}

- (BOOL)isRunning
{
    return _running;
}

- (BOOL)running
{
    return _running;
}

- (NSTimeInterval)preferredDuration
{
    return _preferredDuration;
}

- (void)setPreferredDuration:(NSTimeInterval)preferredDuration
{
    _preferredDuration = preferredDuration;
}

- (void)setDuration:(NSTimeInterval)duration forPage:(NSInteger)page
{
    _durations[@(page)] = @(duration);
}

- (NSTimeInterval)durationForPage:(NSInteger)page
{
    NSNumber *own = _durations[@(page)];
    return own ? own.doubleValue : _preferredDuration;
}

- (void)resumeTimer
{
    if (_running || ![self revenant_control])
        return;
    _running = YES;
    _lastTick = [NSDate date];
    _timedPage = [self revenant_control].currentPage;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30 target:self selector:@selector(revenant_tick) userInfo:nil repeats:YES];
}

- (void)pauseTimer
{
    _running = NO;
    [_timer invalidate];
    _timer = nil;
}

- (void)revenant_currentPageChanged
{
    UIPageControl *control = [self revenant_control];
    if (control && control.currentPage != _timedPage) {
        _timedPage = control.currentPage;
        self.currentProgress = 0;
        _lastTick = [NSDate date];
    }
}

- (void)revenant_tick
{
    UIPageControl *control = [self revenant_control];
    if (!control) {
        [self pauseTimer];
        return;
    }
    [self revenant_currentPageChanged];
    NSDate *now = [NSDate date];
    NSTimeInterval duration = [self durationForPage:_timedPage];
    self.currentProgress = duration > 0 ? self.currentProgress + (float)([now timeIntervalSinceDate:_lastTick] / duration) : 1;
    _lastTick = now;
    id<UIPageControlTimerProgressDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(pageControlTimerProgressDidChange:)])
        [delegate pageControlTimerProgressDidChange:self];
    if (self.currentProgress < 1)
        return;
    NSInteger next = _timedPage + 1;
    if (next >= control.numberOfPages) {
        if (!_resetsToInitialPageAfterEnd) {
            [self pauseTimer];
            return;
        }
        next = 0;
    }
    if ([delegate respondsToSelector:@selector(pageControlTimerProgress:shouldAdvanceToPage:)] && ![delegate pageControlTimerProgress:self shouldAdvanceToPage:next]) {
        self.currentProgress = 0;
        return;
    }
    control.currentPage = next;
    [control sendActionsForControlEvents:UIControlEventValueChanged];
    _timedPage = next;
    self.currentProgress = 0;
}

@end

@implementation UIPageControl (RevenantProgress17)

- (UIPageControlProgress *)progress
{
    return objc_getAssociatedObject(self, &RevenantPageProgressKey);
}

- (void)setProgress:(UIPageControlProgress *)progress
{
    UIPageControlProgress *old = self.progress;
    if (old == progress)
        return;
    [old revenant_attachToControl:nil];
    objc_setAssociatedObject(self, &RevenantPageProgressKey, progress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [progress revenant_attachToControl:self];
}

@end
