#import "RevenantRefreshHost.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const CGFloat RevenantRefreshHeight = 60.0;
static const CGFloat RevenantRefreshTrigger = 60.0;
static const NSTimeInterval RevenantRefreshDuration = 0.25;
static char RevenantRefreshPullContext;
static const char RevenantHostOfScrollKey;
static const char RevenantHostOfControlKey;

static void revenant_exchange(Class cls, SEL original, SEL replacement)
{
    Method first = class_getInstanceMethod(cls, original);
    Method second = class_getInstanceMethod(cls, replacement);
    if (first && second)
        method_exchangeImplementations(first, second);
}

@implementation RevenantRefreshHost {
@private
    __weak UIScrollView *_scrollView;
    __weak UIRefreshControl *_control;
    UIActivityIndicatorView *_spinner;
    BOOL _refreshing;
    BOOL _armed;
    CGFloat _added;
    BOOL _attached;
}

+ (void)setControl:(UIRefreshControl *)control forScrollView:(UIScrollView *)scrollView
{
    RevenantRefreshHost *previous = objc_getAssociatedObject(scrollView, &RevenantHostOfScrollKey);
    [previous detach];
    if (!control)
        return;
    RevenantRefreshHost *host = [[RevenantRefreshHost alloc] initWithScrollView:scrollView control:control];
    objc_setAssociatedObject(scrollView, &RevenantHostOfScrollKey, host, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(control, &RevenantHostOfControlKey, host, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [host attach];
}

- (instancetype)initWithScrollView:(UIScrollView *)scrollView control:(UIRefreshControl *)control
{
    self = [super initWithFrame:CGRectMake(0, -RevenantRefreshHeight, scrollView.bounds.size.width, RevenantRefreshHeight)];
    if (!self)
        return nil;
    _scrollView = scrollView;
    _control = control;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.backgroundColor = [UIColor clearColor];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.hidesWhenStopped = YES;
    [self addSubview:_spinner];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _spinner.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

- (void)attach
{
    _attached = YES;
    [_scrollView insertSubview:self atIndex:0];
    [_scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:&RevenantRefreshPullContext];
    [_scrollView.panGestureRecognizer addTarget:self action:@selector(revenant_pan:)];
}

- (void)detach
{
    if (!_attached)
        return;
    _attached = NO;
    [_scrollView.panGestureRecognizer removeTarget:self action:@selector(revenant_pan:)];
    [_scrollView removeObserver:self forKeyPath:@"contentOffset" context:&RevenantRefreshPullContext];
    if (_refreshing) {
        UIEdgeInsets inset = _scrollView.contentInset;
        inset.top -= _added;
        _scrollView.contentInset = inset;
    }
    _refreshing = NO;
    _armed = NO;
    _added = 0;
    [_spinner stopAnimating];
    [self removeFromSuperview];
    objc_setAssociatedObject(_scrollView, &RevenantHostOfScrollKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(_control, &RevenantHostOfControlKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)pull
{
    return -(_scrollView.contentOffset.y + _scrollView.contentInset.top);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != &RevenantRefreshPullContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if (_refreshing)
        return;
    _armed = [self pull] >= RevenantRefreshTrigger;
    if ([self pull] > 0)
        [self setNeedsDisplay];
}

- (void)revenant_pan:(UIPanGestureRecognizer *)pan
{
    if (pan.state != UIGestureRecognizerStateEnded && pan.state != UIGestureRecognizerStateCancelled)
        return;
    if (_armed && !_refreshing)
        [self beginRefreshingSendingAction:YES];
}

- (BOOL)isRefreshing
{
    return _refreshing;
}

- (void)beginRefreshingSendingAction:(BOOL)sendAction
{
    if (_refreshing || !_scrollView)
        return;
    _refreshing = YES;
    _armed = NO;
    _added = RevenantRefreshHeight;
    UIScrollView *scrollView = _scrollView;
    UIEdgeInsets inset = scrollView.contentInset;
    CGFloat top = inset.top + _added;
    CGPoint offset = scrollView.contentOffset;
    [_spinner startAnimating];
    [UIView animateWithDuration:RevenantRefreshDuration animations:^{
        scrollView.contentInset = UIEdgeInsetsMake(top, inset.left, inset.bottom, inset.right);
        scrollView.contentOffset = CGPointMake(offset.x, -top);
    }];
    [self setNeedsDisplay];
    if (sendAction)
        [_control sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)endRefreshing
{
    if (!_refreshing || !_scrollView)
        return;
    _refreshing = NO;
    _armed = NO;
    UIScrollView *scrollView = _scrollView;
    UIEdgeInsets inset = scrollView.contentInset;
    CGFloat top = inset.top - _added;
    _added = 0;
    CGPoint offset = scrollView.contentOffset;
    [_spinner stopAnimating];
    [UIView animateWithDuration:RevenantRefreshDuration animations:^{
        scrollView.contentInset = UIEdgeInsetsMake(top, inset.left, inset.bottom, inset.right);
        scrollView.contentOffset = CGPointMake(offset.x, -top);
    }];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (_refreshing)
        return;
    CGFloat pull = MAX([self pull], 0);
    if (pull <= 0)
        return;
    CGFloat visible = MIN(pull, RevenantRefreshHeight);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMidX(self.bounds), RevenantRefreshHeight - visible / 2);
    if (_armed)
        CGContextRotateCTM(context, M_PI);
    CGContextSetRGBStrokeColor(context, 0.56, 0.56, 0.6, MIN(pull / RevenantRefreshHeight, 1));
    CGContextSetLineWidth(context, 2);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextMoveToPoint(context, 0, -9);
    CGContextAddLineToPoint(context, 0, 9);
    CGContextMoveToPoint(context, -7, 2);
    CGContextAddLineToPoint(context, 0, 9);
    CGContextAddLineToPoint(context, 7, 2);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

- (void)dealloc
{
    [self detach];
}

@end

@implementation UIRefreshControl (RevenantOutsideTable)

+ (void)load
{
    revenant_exchange(self, @selector(beginRefreshing), @selector(revenant_beginRefreshing));
    revenant_exchange(self, @selector(endRefreshing), @selector(revenant_endRefreshing));
    revenant_exchange(self, @selector(isRefreshing), @selector(revenant_isRefreshing));
}

- (RevenantRefreshHost *)revenant_host
{
    return objc_getAssociatedObject(self, &RevenantHostOfControlKey);
}

- (void)revenant_beginRefreshing
{
    RevenantRefreshHost *host = [self revenant_host];
    if (host)
        [host beginRefreshingSendingAction:NO];
    else
        [self revenant_beginRefreshing];
}

- (void)revenant_endRefreshing
{
    RevenantRefreshHost *host = [self revenant_host];
    if (host)
        [host endRefreshing];
    else
        [self revenant_endRefreshing];
}

- (BOOL)revenant_isRefreshing
{
    RevenantRefreshHost *host = [self revenant_host];
    return host ? host.isRefreshing : [self revenant_isRefreshing];
}

@end
