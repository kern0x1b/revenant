#import "CharonBackdrop.h"
#import <QuartzCore/QuartzCore.h>

static const NSTimeInterval CharonBackdropMinimumInterval = 0.1;
static const NSTimeInterval CharonBackdropQuietInterval = 0.5;

/* Hides the layer and every layer drawn above it on the way to the window: the later siblings,
   and those with a greater zPosition, of the layer and of each of its superlayers. What stays
   is what the layer is composited over. */
static void charon_backdrop_hide_above(CALayer *layer, CALayer *top, NSMutableArray *hidden)
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

@implementation CharonBackdrop {
    __weak UIView *_view;
    __weak id<CharonBackdropClient> _client;
    CADisplayLink *_link;
    NSTimeInterval _nextRefresh;
    uint32_t _lastChecksum;
    CGRect _lastRect;
    BOOL _delivered;
    BOOL _refreshing;
}

@synthesize scale = _scale;

- (instancetype)initWithView:(UIView *)view client:(id<CharonBackdropClient>)client
{
    if ((self = [super init])) {
        _view = view;
        _client = client;
        _scale = 1;
    }
    return self;
}

- (void)start
{
    if (_link || !_view.window)
        return;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    _link.frameInterval = 6;
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _nextRefresh = 0;
}

- (void)stop
{
    [_link invalidate];
    _link = nil;
    _delivered = NO;
}

- (void)setNeedsRefresh
{
    _nextRefresh = 0;
}

- (void)invalidate
{
    _delivered = NO;
    _nextRefresh = 0;
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
    if (CACurrentMediaTime() < _nextRefresh)
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
    id<CharonBackdropClient> client = _client;
    UIWindow *window = view.window;
    CGFloat scale = _scale;
    /* The region in the window, widened to the pixels the window is drawn in, cut to the window
       and taken back into the view: the view's transform then maps the reading onto what lies
       under it. */
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
    /* Window coordinates into the view's (the inverse of the view's affine map into the window,
       read off three points), then the captured rect into the bitmap, row 0 at the top. */
    CGPoint o = [view convertPoint:CGPointZero toView:window], ex = [view convertPoint:CGPointMake(1, 0) toView:window], ey = [view convertPoint:CGPointMake(0, 1) toView:window];
    CGAffineTransform toWindow = CGAffineTransformMake(ex.x - o.x, ex.y - o.y, ey.x - o.x, ey.y - o.y, o.x, o.y);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, width / captured.size.width, -(CGFloat)height / captured.size.height);
    CGContextTranslateCTM(context, -captured.origin.x, -captured.origin.y);
    CGContextConcatCTM(context, CGAffineTransformInvert(toWindow));
    NSMutableArray *hidden = [NSMutableArray array];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    charon_backdrop_hide_above(view.layer, window.layer, hidden);
    [window.layer renderInContext:context];
    for (CALayer *layer in hidden)
        layer.hidden = NO;
    [CATransaction commit];
    CGContextRelease(context);
    uint32_t checksum = 2166136261u;
    for (size_t i = 0; i < rowBytes * height; i += 4)
        checksum = (checksum ^ pixels[i] ^ ((uint32_t)pixels[i + 1] << 8) ^ ((uint32_t)pixels[i + 2] << 16)) * 16777619u;
    if (_delivered && checksum == _lastChecksum && CGRectEqualToRect(captured, _lastRect)) {
        free(pixels);
        _nextRefresh = CACurrentMediaTime() + CharonBackdropQuietInterval;
        _refreshing = NO;
        return;
    }
    _lastChecksum = checksum;
    _lastRect = captured;
    _delivered = YES;
    [client backdrop:self captured:pixels width:width height:height rowBytes:rowBytes rect:captured];
    NSTimeInterval cost = CACurrentMediaTime() - started;
    _nextRefresh = CACurrentMediaTime() + MAX(CharonBackdropMinimumInterval, cost * 3);
    _refreshing = NO;
}

@end
