#import "RevenantBackdrop.h"
#import <QuartzCore/QuartzCore.h>

static const NSTimeInterval RevenantBackdropMinimumInterval = 0.1;
static const NSTimeInterval RevenantBackdropQuietInterval = 0.5;
static const NSUInteger RevenantBackdropQuietDoublings = 3;
static const int RevenantBackdropPixelTolerance = 16;

static BOOL revenant_backdrop_similar(const uint8_t *a, const uint8_t *b, size_t length)
{
    size_t differing = 0;
    for (size_t i = 0; i < length; i += 4) {
        int delta = MAX(abs(a[i] - b[i]), MAX(abs(a[i + 1] - b[i + 1]), abs(a[i + 2] - b[i + 2])));
        if (delta > RevenantBackdropPixelTolerance)
            differing++;
    }
    return differing * 400 <= length;
}

static void revenant_backdrop_hide_above(CALayer *layer, CALayer *top, NSMutableArray *hidden)
{
    if (!layer.hidden) {
        layer.hidden = YES;
        [hidden addObject:layer];
    }
    for (; layer && layer != top; layer = layer.superlayer) {
        NSArray *siblings = layer.superlayer.sublayers;
        NSUInteger index = [siblings indexOfObjectIdenticalTo:layer];
        for (NSUInteger i = 0; i < siblings.count; i++) {
            CALayer *sibling = siblings[i];
            if (sibling == layer || sibling.hidden)
                continue;
            if (sibling.zPosition > layer.zPosition || (sibling.zPosition == layer.zPosition && i > index)) {
                sibling.hidden = YES;
                [hidden addObject:sibling];
            }
        }
    }
}

@implementation RevenantBackdrop {
    __weak UIView *_view;
    __weak id<RevenantBackdropClient> _client;
    CADisplayLink *_link;
    NSTimeInterval _nextRefresh;
    NSTimeInterval _earliestRefresh;
    NSUInteger _unchanged;
    uint8_t *_lastPixels;
    size_t _lastLength;
    CGRect _lastRect;
    BOOL _delivered;
    BOOL _refreshing;
}

@synthesize scale = _scale;

- (instancetype)initWithView:(UIView *)view client:(id<RevenantBackdropClient>)client
{
    if ((self = [super init])) {
        _view = view;
        _client = client;
        _scale = 1;
    }
    return self;
}

- (void)dealloc
{
    free(_lastPixels);
}

- (void)start
{
    if (_link || !_view.window)
        return;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    _link.frameInterval = 6;
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _nextRefresh = 0;
    _earliestRefresh = 0;
}

- (void)stop
{
    [_link invalidate];
    _link = nil;
    _delivered = NO;
    _unchanged = 0;
}

- (void)setNeedsRefresh
{
    _nextRefresh = 0;
    _earliestRefresh = 0;
    _unchanged = 0;
}

- (void)invalidate
{
    _delivered = NO;
    _nextRefresh = 0;
    _earliestRefresh = 0;
    _unchanged = 0;
}

- (BOOL)wanted
{
    UIView *view = _view;
    return view.window && [_client backdropIsWanted:self];
}

- (void)tick:(CADisplayLink *)link
{
    if (!_view || !_client) {
        [self stop];
        return;
    }
    if (![self wanted] || [UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
        return;
    BOOL tracking = [[NSRunLoop currentRunLoop].currentMode isEqualToString:UITrackingRunLoopMode];
    if (tracking)
        _unchanged = 0;
    if (CACurrentMediaTime() < (tracking ? _earliestRefresh : _nextRefresh))
        return;
    [self refresh];
}

- (void)refresh
{
    if (_refreshing || ![self wanted])
        return;
    _refreshing = YES;
    NSTimeInterval started = CACurrentMediaTime();
    UIView *view = _view;
    id<RevenantBackdropClient> client = _client;
    UIWindow *window = view.window;
    CGFloat scale = _scale;
    CGRect wanted = [view convertRect:[client backdropRegion:self] toView:window];
    CGFloat minX = floor(CGRectGetMinX(wanted) * scale) / scale, minY = floor(CGRectGetMinY(wanted) * scale) / scale;
    CGFloat maxX = ceil(CGRectGetMaxX(wanted) * scale) / scale, maxY = ceil(CGRectGetMaxY(wanted) * scale) / scale;
    CGRect region = CGRectIntersection(CGRectMake(minX, minY, maxX - minX, maxY - minY), window.bounds);
    if (CGRectIsNull(region) || region.size.width * scale < 1 || region.size.height * scale < 1) {
        _refreshing = NO;
        return;
    }
    CGRect captured = [view convertRect:region fromView:window];
    size_t width = MAX((size_t)ceil(captured.size.width * scale - 0.001), 2), height = MAX((size_t)ceil(captured.size.height * scale - 0.001), 2);
    size_t rowBytes = width * 4;
    uint8_t *pixels = calloc(rowBytes, height);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = pixels ? CGBitmapContextCreate(pixels, width, height, 8, rowBytes, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault) : NULL;
    CGColorSpaceRelease(space);
    if (!context) {
        free(pixels);
        _refreshing = NO;
        return;
    }
    CGPoint o = [view convertPoint:CGPointZero toView:window], ex = [view convertPoint:CGPointMake(1, 0) toView:window], ey = [view convertPoint:CGPointMake(0, 1) toView:window];
    CGAffineTransform toWindow = CGAffineTransformMake(ex.x - o.x, ex.y - o.y, ey.x - o.x, ey.y - o.y, o.x, o.y);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, width / captured.size.width, -(CGFloat)height / captured.size.height);
    CGContextTranslateCTM(context, -captured.origin.x, -captured.origin.y);
    CGContextConcatCTM(context, CGAffineTransformInvert(toWindow));
    NSMutableArray *hidden = [NSMutableArray array];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    revenant_backdrop_hide_above(view.layer, window.layer, hidden);
    [window.layer renderInContext:context];
    for (CALayer *layer in hidden)
        layer.hidden = NO;
    [CATransaction commit];
    CGContextRelease(context);
    size_t length = rowBytes * height;
    BOOL same = _delivered && _lastPixels && _lastLength == length && CGRectEqualToRect(captured, _lastRect) && revenant_backdrop_similar(pixels, _lastPixels, length);
    if (same) {
        free(pixels);
        NSTimeInterval now = CACurrentMediaTime();
        NSTimeInterval earliest = now + MAX(RevenantBackdropMinimumInterval, (now - started) * 3);
        NSUInteger doublings = MIN(_unchanged, RevenantBackdropQuietDoublings);
        _unchanged++;
        _earliestRefresh = earliest;
        _nextRefresh = MAX(earliest, now + RevenantBackdropQuietInterval * (1 << doublings));
        _refreshing = NO;
        return;
    }
    _unchanged = 0;
    uint8_t *reference = realloc(_lastPixels, length);
    if (reference) {
        memcpy(reference, pixels, length);
        _lastPixels = reference;
        _lastLength = length;
    } else {
        free(_lastPixels);
        _lastPixels = NULL;
        _lastLength = 0;
    }
    _lastRect = captured;
    _delivered = YES;
    [client backdrop:self captured:pixels width:width height:height rowBytes:rowBytes rect:captured];
    NSTimeInterval cost = CACurrentMediaTime() - started;
    _earliestRefresh = CACurrentMediaTime() + MAX(RevenantBackdropMinimumInterval, cost * 3);
    _nextRefresh = _earliestRefresh;
    _refreshing = NO;
}

@end
