#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>

@implementation MTKView
{
    id<MTLDevice> _revenantDevice;
    MTLPixelFormat _revenantColorPixelFormat;
    MTLPixelFormat _revenantDepthStencilPixelFormat;
    NSUInteger _revenantSampleCount;
    MTLClearColor _revenantClearColor;
    double _revenantClearDepth;
    uint32_t _revenantClearStencil;
    CGSize _revenantDrawableSize;
    NSInteger _revenantPreferredFramesPerSecond;
    MTLTextureUsage _revenantDepthStencilAttachmentTextureUsage;
    MTLTextureUsage _revenantMultisampleColorAttachmentTextureUsage;
    BOOL _revenantEnableSetNeedsDisplay;
    BOOL _revenantAutoResizeDrawable;
    BOOL _revenantPaused;
    CADisplayLink *_revenantDisplayLink;
    id<MTLTexture> _revenantDepthStencilTexture;
    __weak id<MTKViewDelegate> _revenantDelegate;
}

- (CAMetalLayer *)revenantLayer
{
    return (CAMetalLayer *)self.layer;
}

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (instancetype)initWithFrame:(CGRect)frameRect device:(id<MTLDevice>)device
{
    if ((self = [super initWithFrame:frameRect])) {
        _revenantDevice = device;
        [self revenantSetup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        [self revenantSetup];
    return self;
}

- (void)revenantSetup
{
    _revenantColorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _revenantDepthStencilPixelFormat = MTLPixelFormatInvalid;
    _revenantSampleCount = 1;
    _revenantClearColor = MTLClearColorMake(0, 0, 0, 1);
    _revenantClearDepth = 1.0;
    _revenantPreferredFramesPerSecond = 60;
    _revenantAutoResizeDrawable = YES;
    _revenantDepthStencilAttachmentTextureUsage = MTLTextureUsageRenderTarget;
    _revenantMultisampleColorAttachmentTextureUsage = MTLTextureUsageRenderTarget;
    self.revenantLayer.device = _revenantDevice;
    self.revenantLayer.pixelFormat = _revenantColorPixelFormat;
    self.revenantLayer.framebufferOnly = YES;
}

- (void)dealloc
{
    [_revenantDisplayLink invalidate];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    if (!newWindow) {
        [_revenantDisplayLink invalidate];
        _revenantDisplayLink = nil;
    } else if (!_revenantPaused && !_revenantEnableSetNeedsDisplay && !_revenantDisplayLink) {
        _revenantDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(revenantTick)];
        [_revenantDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)revenantTick
{
    [self draw];
}

- (void)draw
{
    if (_revenantAutoResizeDrawable)
        self.revenantLayer.drawableSize = CGSizeMake(self.bounds.size.width * self.contentScaleFactor, self.bounds.size.height * self.contentScaleFactor);
    id<MTKViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(drawInMTKView:)])
        [delegate drawInMTKView:self];
    else if ([self respondsToSelector:@selector(drawRect:)] && [self isKindOfClass:[MTKView class]] && [self methodForSelector:@selector(drawRect:)] != [MTKView instanceMethodForSelector:@selector(drawRect:)])
        [self drawRect:self.bounds];
}

- (id<MTLDevice>)device
{
    return _revenantDevice;
}

- (void)setDevice:(id<MTLDevice>)device
{
    _revenantDevice = device;
    self.revenantLayer.device = device;
}

- (id<CAMetalDrawable>)currentDrawable
{
    return self.revenantLayer.nextDrawable;
}

- (MTLPixelFormat)colorPixelFormat
{
    return _revenantColorPixelFormat;
}

- (void)setColorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    _revenantColorPixelFormat = colorPixelFormat;
    self.revenantLayer.pixelFormat = colorPixelFormat;
}

- (MTLPixelFormat)depthStencilPixelFormat
{
    return _revenantDepthStencilPixelFormat;
}

- (void)setDepthStencilPixelFormat:(MTLPixelFormat)depthStencilPixelFormat
{
    _revenantDepthStencilPixelFormat = depthStencilPixelFormat;
    _revenantDepthStencilTexture = nil;
}

- (NSUInteger)sampleCount
{
    return _revenantSampleCount;
}

- (void)setSampleCount:(NSUInteger)sampleCount
{
    _revenantSampleCount = sampleCount ?: 1;
}

- (MTLClearColor)clearColor
{
    return _revenantClearColor;
}

- (void)setClearColor:(MTLClearColor)clearColor
{
    _revenantClearColor = clearColor;
}

- (double)clearDepth
{
    return _revenantClearDepth;
}

- (void)setClearDepth:(double)clearDepth
{
    _revenantClearDepth = clearDepth;
}

- (uint32_t)clearStencil
{
    return _revenantClearStencil;
}

- (void)setClearStencil:(uint32_t)clearStencil
{
    _revenantClearStencil = clearStencil;
}

- (CGSize)drawableSize
{
    return self.revenantLayer.drawableSize;
}

- (void)setDrawableSize:(CGSize)drawableSize
{
    self.revenantLayer.drawableSize = drawableSize;
}

- (NSInteger)preferredFramesPerSecond
{
    return _revenantPreferredFramesPerSecond;
}

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    _revenantPreferredFramesPerSecond = preferredFramesPerSecond;
    _revenantDisplayLink.frameInterval = MAX(1, (NSInteger)round(60.0 / MAX(preferredFramesPerSecond, 1)));
}

- (BOOL)enableSetNeedsDisplay
{
    return _revenantEnableSetNeedsDisplay;
}

- (void)setEnableSetNeedsDisplay:(BOOL)enableSetNeedsDisplay
{
    _revenantEnableSetNeedsDisplay = enableSetNeedsDisplay;
    if (enableSetNeedsDisplay) {
        [_revenantDisplayLink invalidate];
        _revenantDisplayLink = nil;
    } else if (self.window && !_revenantPaused && !_revenantDisplayLink) {
        _revenantDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(revenantTick)];
        [_revenantDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (BOOL)autoResizeDrawable
{
    return _revenantAutoResizeDrawable;
}

- (void)setAutoResizeDrawable:(BOOL)autoResizeDrawable
{
    _revenantAutoResizeDrawable = autoResizeDrawable;
}

- (BOOL)isPaused
{
    return _revenantPaused;
}

- (void)setPaused:(BOOL)paused
{
    _revenantPaused = paused;
    if (paused || _revenantEnableSetNeedsDisplay) {
        [_revenantDisplayLink invalidate];
        _revenantDisplayLink = nil;
    } else if (self.window && !_revenantDisplayLink) {
        _revenantDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(revenantTick)];
        [_revenantDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)releaseDrawables
{
    _revenantDepthStencilTexture = nil;
}

- (MTLTextureUsage)depthStencilAttachmentTextureUsage
{
    return _revenantDepthStencilAttachmentTextureUsage;
}

- (void)setDepthStencilAttachmentTextureUsage:(MTLTextureUsage)depthStencilAttachmentTextureUsage
{
    _revenantDepthStencilAttachmentTextureUsage = depthStencilAttachmentTextureUsage;
    _revenantDepthStencilTexture = nil;
}

- (MTLTextureUsage)multisampleColorAttachmentTextureUsage
{
    return _revenantMultisampleColorAttachmentTextureUsage;
}

- (void)setMultisampleColorAttachmentTextureUsage:(MTLTextureUsage)multisampleColorAttachmentTextureUsage
{
    _revenantMultisampleColorAttachmentTextureUsage = multisampleColorAttachmentTextureUsage;
}

- (id<MTKViewDelegate>)delegate
{
    return _revenantDelegate;
}

- (void)setDelegate:(id<MTKViewDelegate>)delegate
{
    _revenantDelegate = delegate;
}

- (BOOL)framebufferOnly
{
    return self.revenantLayer.framebufferOnly;
}

- (void)setFramebufferOnly:(BOOL)framebufferOnly
{
    self.revenantLayer.framebufferOnly = framebufferOnly;
}

- (BOOL)presentsWithTransaction
{
    return self.revenantLayer.presentsWithTransaction;
}

- (void)setPresentsWithTransaction:(BOOL)presentsWithTransaction
{
    self.revenantLayer.presentsWithTransaction = presentsWithTransaction;
}

- (CGColorSpaceRef)colorspace
{
    return self.revenantLayer.colorspace;
}

- (void)setColorspace:(CGColorSpaceRef)colorspace
{
    self.revenantLayer.colorspace = colorspace;
}

- (id<MTLTexture>)depthStencilTexture
{
    if (_revenantDepthStencilPixelFormat == MTLPixelFormatInvalid)
        return nil;
    CGSize size = self.drawableSize;
    if (!_revenantDepthStencilTexture || _revenantDepthStencilTexture.width != (NSUInteger)size.width || _revenantDepthStencilTexture.height != (NSUInteger)size.height) {
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_revenantDepthStencilPixelFormat width:(NSUInteger)size.width height:(NSUInteger)size.height mipmapped:NO];
        descriptor.usage = _revenantDepthStencilAttachmentTextureUsage;
        _revenantDepthStencilTexture = [_revenantDevice newTextureWithDescriptor:descriptor];
    }
    return _revenantDepthStencilTexture;
}

- (id<MTLTexture>)multisampleColorTexture
{
    return nil;
}

- (MTLRenderPassDescriptor *)currentRenderPassDescriptor
{
    id<CAMetalDrawable> drawable = self.currentDrawable;
    if (!drawable)
        return nil;
    MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    descriptor.colorAttachments[0].texture = drawable.texture;
    descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.colorAttachments[0].clearColor = _revenantClearColor;
    if (_revenantDepthStencilPixelFormat != MTLPixelFormatInvalid) {
        id<MTLTexture> depthStencil = self.depthStencilTexture;
        descriptor.depthAttachment.texture = depthStencil;
        descriptor.depthAttachment.loadAction = MTLLoadActionClear;
        descriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
        descriptor.depthAttachment.clearDepth = _revenantClearDepth;
        descriptor.stencilAttachment.texture = depthStencil;
        descriptor.stencilAttachment.loadAction = MTLLoadActionClear;
        descriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
        descriptor.stencilAttachment.clearStencil = _revenantClearStencil;
    }
    return descriptor;
}

- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    if (_revenantEnableSetNeedsDisplay)
        [self draw];
}

@end
