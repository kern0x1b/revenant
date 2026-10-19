#import "CharonBackdrop.h"
#import "CharonBlur.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const CharonEffectKey = @"UIVisualEffectViewEffect";
static NSString *const CharonContentViewKey = @"UIVisualEffectViewContentView";

static void charon_free_pixels(void *info, const void *data, size_t size)
{
    free((void *)data);
}

static const CGFloat CharonMaximumScale = 0.25;

@interface UIVisualEffectView () <CharonBackdropClient>
@end

@implementation UIVisualEffectView {
    UIVisualEffect *_effect;
    UIView *_contentView;
    BOOL _installing;
    CALayer *_backdrop;
    CharonBackdrop *_reader;
    /* Where the box blur and the colour matrix run. The read has to be on the main thread -- the
       display link is on the main run loop and CoreAnimation is not thread-safe for a layer read --
       but the shading is arithmetic over a buffer this view owns, and it was the whole cost of a
       refresh: on the iPad 2 a whole-screen refresh measured 172 ms, 5.8 frames a second, of which
       the read is 21 to 33 ms. That is a property of the device and is the figure to reason from.
       What the shading costs on any one machine is not, and is not put here: it moves by a factor of
       2.6 with the machine's load, and
       tests/backports/host/blurcost measures it here for whoever wants the number with the load it
       was taken at. The reasoning and the measurements, including the load, are in
       facts/UIKit/UIVisualEffect.md. The sheet's shadow already shades off the main thread for the
       same reason (UISheetPresentationController.m:795-796). */
    dispatch_queue_t _shadeQueue;
    /* Set while a reading is being shaded, so a second reading does not queue up behind the first: the
       same guard the shadow's client uses for the same reason. */
    BOOL _shading;
}

- (CharonBackdrop *)charon_reader
{
    if (!_reader) {
        _reader = [[CharonBackdrop alloc] initWithView:self client:self];
        _reader.scale = CharonMaximumScale;
        _shadeQueue = dispatch_queue_create("org.charon.visualeffect.shade", DISPATCH_QUEUE_SERIAL);
    }
    return _reader;
}

/* Reads what lies under the view now; the picture is made again only when that changed. */
- (void)charon_refresh
{
    [[self charon_reader] refresh];
}

- (void)charon_removeBackdrop
{
    [_backdrop removeFromSuperlayer];
    _backdrop = nil;
    [_reader invalidate];
}

- (BOOL)backdropIsWanted:(CharonBackdrop *)backdrop
{
    return [_effect isKindOfClass:[UIBlurEffect class]] && !self.hidden && self.alpha > 0.01 && self.bounds.size.width > 0 && self.bounds.size.height > 0 && !_shading;
}

- (CGRect)backdropRegion:(CharonBackdrop *)backdrop
{
    CGFloat radius = charon_blur_parameters([(UIBlurEffect *)_effect charon_style]).radius;
    return CGRectInset(self.bounds, -radius, -radius);
}

- (void)backdrop:(CharonBackdrop *)backdrop captured:(uint8_t *)pixels width:(size_t)width height:(size_t)height rowBytes:(size_t)rowBytes rect:(CGRect)captured
{
    CharonBlurParameters parameters = charon_blur_parameters([(UIBlurEffect *)_effect charon_style]);
    CGFloat sx = width / captured.size.width, sy = height / captured.size.height;

    /* The layer is made here, on the main thread, because inserting it touches self.layer. Everything
       the shading needs that comes off the view is read here too, for the same reason: bounds and the
       effect's style are UIView state and are not read from the queue. */
    if (!_backdrop) {
        _backdrop = [CALayer layer];
        _backdrop.magnificationFilter = kCAFilterLinear;
        _backdrop.minificationFilter = kCAFilterLinear;
        _backdrop.contentsGravity = kCAGravityResize;
        [self.layer insertSublayer:_backdrop atIndex:0];
    }
    CALayer *backdropLayer = _backdrop;
    CGRect bounds = self.bounds;
    size_t bytes = rowBytes * height;

    /* The box blur and the colour matrix, and the picture made from them, run off the main thread;
       the main thread only puts the result on the layer. This is the shadow's arrangement and for the
       same reason: charon_sheet_shadow_shade is "a pass over each of them that took an iPad 2 hundreds
       of milliseconds" and is shaded on a queue of its own (UISheetPresentationController.m:795-796).
       The pixels are this view's to free (CharonBackdrop.h) and the provider frees them when the image
       is released, so the buffer's lifetime does not depend on this method returning.
       Building the CGImage here rather than on the main thread is the same choice: it is not a layer
       operation, and it is what the shadow does. */
    _shading = YES;
    dispatch_async(_shadeQueue, ^{
        charon_blur_pixels(pixels, width, height, rowBytes, parameters.radius * sx, parameters.saturation, parameters.tintRed, parameters.tintGreen, parameters.tintBlue, parameters.tintAlpha);
        CGColorSpaceRef output = CGColorSpaceCreateDeviceRGB();
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, bytes, charon_free_pixels);
        CGImageRef image = CGImageCreate(width, height, 8, 32, rowBytes, output, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault, provider, NULL, true, kCGRenderingIntentDefault);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(output);
        CGRect crop = CGRectMake(floor((CGRectGetMinX(bounds) - captured.origin.x) * sx), floor((CGRectGetMinY(bounds) - captured.origin.y) * sy), ceil(bounds.size.width * sx), ceil(bounds.size.height * sy));
        CGImageRef cropped = CGImageCreateWithImageInRect(image, CGRectIntersection(crop, CGRectMake(0, 0, width, height)));
        dispatch_async(dispatch_get_main_queue(), ^{
            /* The layer may have gone while the queue was busy: -charon_removeBackdrop takes it out
               and the view may be gone with it. A picture nobody will look at is released, not
               handed to a layer that is no longer there. */
            if (_backdrop == backdropLayer) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                backdropLayer.frame = bounds;
                backdropLayer.contents = (__bridge id)(cropped ? cropped : image);
                [CATransaction commit];
            }
            if (cropped)
                CGImageRelease(cropped);
            CGImageRelease(image);
            _shading = NO;
        });
    });
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [[self charon_reader] start];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self charon_refresh];
        });
    } else {
        [_reader stop];
        [self charon_removeBackdrop];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _backdrop.frame = self.bounds;
    [_reader setNeedsRefresh];
}

- (void)charon_install
{
    _installing = YES;
    if (!_contentView) {
        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    if (_contentView.superview != self)
        [super addSubview:_contentView];
    _installing = NO;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithEffect:(UIVisualEffect *)effect
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _effect = [effect copy];
        [self charon_install];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
        [self charon_install];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    _installing = YES;
    self = [super initWithCoder:coder];
    if (self) {
        _effect = [coder decodeObjectOfClass:[UIVisualEffect class] forKey:CharonEffectKey];
        _contentView = [coder decodeObjectOfClass:[UIView class] forKey:CharonContentViewKey];
        [self charon_install];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_effect forKey:CharonEffectKey];
    [coder encodeObject:_contentView forKey:CharonContentViewKey];
}

- (UIVisualEffect *)effect
{
    return _effect;
}

- (void)setEffect:(UIVisualEffect *)effect
{
    _effect = [effect copy];
    [_reader invalidate];
    if (![_effect isKindOfClass:[UIBlurEffect class]])
        [self charon_removeBackdrop];
    else if (self.window)
        [[self charon_reader] start];
}

- (UIView *)contentView
{
    return _contentView;
}

- (void)charon_refuse:(UIView *)view
{
    if (_installing)
        return;
    [NSException raise:NSInternalInconsistencyException format:@"%@ has been added as a subview to %@. Do not add subviews directly to the visual effect view itself, instead add them to the -contentView.", view, self];
}

- (void)addSubview:(UIView *)view
{
    [self charon_refuse:view];
    [super addSubview:view];
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
    [self charon_refuse:view];
    [super insertSubview:view atIndex:index];
}

- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)sibling
{
    [self charon_refuse:view];
    [super insertSubview:view aboveSubview:sibling];
}

- (void)insertSubview:(UIView *)view belowSubview:(UIView *)sibling
{
    [self charon_refuse:view];
    [super insertSubview:view belowSubview:sibling];
}

@end
