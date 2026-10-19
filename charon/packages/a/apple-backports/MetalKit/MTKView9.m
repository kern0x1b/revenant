#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>

@implementation MTKView
{
    id<MTLDevice> _charonDevice;
    MTLPixelFormat _charonColorPixelFormat;
    MTLPixelFormat _charonDepthStencilPixelFormat;
    NSUInteger _charonSampleCount;
    MTLClearColor _charonClearColor;
    double _charonClearDepth;
    uint32_t _charonClearStencil;
    CGSize _charonDrawableSize;
    NSInteger _charonPreferredFramesPerSecond;
    MTLTextureUsage _charonDepthStencilAttachmentTextureUsage;
    MTLTextureUsage _charonMultisampleColorAttachmentTextureUsage;
    BOOL _charonEnableSetNeedsDisplay;
    BOOL _charonAutoResizeDrawable;
    BOOL _charonPaused;
    CADisplayLink *_charonDisplayLink;
    id<MTLTexture> _charonDepthStencilTexture;
    __weak id<MTKViewDelegate> _charonDelegate;
}

- (CAMetalLayer *)charonLayer
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
        _charonDevice = device;
        [self charonSetup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder]))
        [self charonSetup];
    return self;
}

- (void)charonSetup
{
    _charonColorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _charonDepthStencilPixelFormat = MTLPixelFormatInvalid;
    _charonSampleCount = 1;
    _charonClearColor = MTLClearColorMake(0, 0, 0, 1);
    _charonClearDepth = 1.0;
    _charonPreferredFramesPerSecond = 60;
    _charonAutoResizeDrawable = YES;
    _charonDepthStencilAttachmentTextureUsage = MTLTextureUsageRenderTarget;
    _charonMultisampleColorAttachmentTextureUsage = MTLTextureUsageRenderTarget;
    self.charonLayer.device = _charonDevice;
    self.charonLayer.pixelFormat = _charonColorPixelFormat;
    self.charonLayer.framebufferOnly = YES;
}

- (void)dealloc
{
    [_charonDisplayLink invalidate];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    if (!newWindow) {
        [_charonDisplayLink invalidate];
        _charonDisplayLink = nil;
    } else if (!_charonPaused && !_charonEnableSetNeedsDisplay && !_charonDisplayLink) {
        _charonDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(charonTick)];
        [_charonDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)charonTick
{
    [self draw];
}

- (void)draw
{
    if (_charonAutoResizeDrawable)
        self.charonLayer.drawableSize = CGSizeMake(self.bounds.size.width * self.contentScaleFactor, self.bounds.size.height * self.contentScaleFactor);
    id<MTKViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(drawInMTKView:)])
        [delegate drawInMTKView:self];
    else if ([self respondsToSelector:@selector(drawRect:)] && [self isKindOfClass:[MTKView class]] && [self methodForSelector:@selector(drawRect:)] != [MTKView instanceMethodForSelector:@selector(drawRect:)])
        [self drawRect:self.bounds];
}

- (id<MTLDevice>)device
{
    return _charonDevice;
}

- (void)setDevice:(id<MTLDevice>)device
{
    _charonDevice = device;
    self.charonLayer.device = device;
}

- (id<CAMetalDrawable>)currentDrawable
{
    return self.charonLayer.nextDrawable;
}

- (MTLPixelFormat)colorPixelFormat
{
    return _charonColorPixelFormat;
}

- (void)setColorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    _charonColorPixelFormat = colorPixelFormat;
    self.charonLayer.pixelFormat = colorPixelFormat;
}

- (MTLPixelFormat)depthStencilPixelFormat
{
    return _charonDepthStencilPixelFormat;
}

- (void)setDepthStencilPixelFormat:(MTLPixelFormat)depthStencilPixelFormat
{
    _charonDepthStencilPixelFormat = depthStencilPixelFormat;
    _charonDepthStencilTexture = nil;
}

- (NSUInteger)sampleCount
{
    return _charonSampleCount;
}

- (void)setSampleCount:(NSUInteger)sampleCount
{
    _charonSampleCount = sampleCount ?: 1;
}

- (MTLClearColor)clearColor
{
    return _charonClearColor;
}

- (void)setClearColor:(MTLClearColor)clearColor
{
    _charonClearColor = clearColor;
}

- (double)clearDepth
{
    return _charonClearDepth;
}

- (void)setClearDepth:(double)clearDepth
{
    _charonClearDepth = clearDepth;
}

- (uint32_t)clearStencil
{
    return _charonClearStencil;
}

- (void)setClearStencil:(uint32_t)clearStencil
{
    _charonClearStencil = clearStencil;
}

- (CGSize)drawableSize
{
    return self.charonLayer.drawableSize;
}

- (void)setDrawableSize:(CGSize)drawableSize
{
    self.charonLayer.drawableSize = drawableSize;
}

- (NSInteger)preferredFramesPerSecond
{
    return _charonPreferredFramesPerSecond;
}

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    _charonPreferredFramesPerSecond = preferredFramesPerSecond;
    _charonDisplayLink.frameInterval = MAX(1, (NSInteger)round(60.0 / MAX(preferredFramesPerSecond, 1)));
}

- (BOOL)enableSetNeedsDisplay
{
    return _charonEnableSetNeedsDisplay;
}

- (void)setEnableSetNeedsDisplay:(BOOL)enableSetNeedsDisplay
{
    _charonEnableSetNeedsDisplay = enableSetNeedsDisplay;
    if (enableSetNeedsDisplay) {
        [_charonDisplayLink invalidate];
        _charonDisplayLink = nil;
    } else if (self.window && !_charonPaused && !_charonDisplayLink) {
        _charonDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(charonTick)];
        [_charonDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (BOOL)autoResizeDrawable
{
    return _charonAutoResizeDrawable;
}

- (void)setAutoResizeDrawable:(BOOL)autoResizeDrawable
{
    _charonAutoResizeDrawable = autoResizeDrawable;
}

- (BOOL)isPaused
{
    return _charonPaused;
}

- (void)setPaused:(BOOL)paused
{
    _charonPaused = paused;
    if (paused || _charonEnableSetNeedsDisplay) {
        [_charonDisplayLink invalidate];
        _charonDisplayLink = nil;
    } else if (self.window && !_charonDisplayLink) {
        _charonDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(charonTick)];
        [_charonDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)releaseDrawables
{
    _charonDepthStencilTexture = nil;
}

- (MTLTextureUsage)depthStencilAttachmentTextureUsage
{
    return _charonDepthStencilAttachmentTextureUsage;
}

- (void)setDepthStencilAttachmentTextureUsage:(MTLTextureUsage)depthStencilAttachmentTextureUsage
{
    _charonDepthStencilAttachmentTextureUsage = depthStencilAttachmentTextureUsage;
    _charonDepthStencilTexture = nil;
}

- (MTLTextureUsage)multisampleColorAttachmentTextureUsage
{
    return _charonMultisampleColorAttachmentTextureUsage;
}

- (void)setMultisampleColorAttachmentTextureUsage:(MTLTextureUsage)multisampleColorAttachmentTextureUsage
{
    _charonMultisampleColorAttachmentTextureUsage = multisampleColorAttachmentTextureUsage;
}

- (id<MTKViewDelegate>)delegate
{
    return _charonDelegate;
}

- (void)setDelegate:(id<MTKViewDelegate>)delegate
{
    _charonDelegate = delegate;
}

- (BOOL)framebufferOnly
{
    return self.charonLayer.framebufferOnly;
}

- (void)setFramebufferOnly:(BOOL)framebufferOnly
{
    self.charonLayer.framebufferOnly = framebufferOnly;
}

- (BOOL)presentsWithTransaction
{
    return self.charonLayer.presentsWithTransaction;
}

- (void)setPresentsWithTransaction:(BOOL)presentsWithTransaction
{
    self.charonLayer.presentsWithTransaction = presentsWithTransaction;
}

- (CGColorSpaceRef)colorspace
{
    return self.charonLayer.colorspace;
}

- (void)setColorspace:(CGColorSpaceRef)colorspace
{
    self.charonLayer.colorspace = colorspace;
}

- (id<MTLTexture>)depthStencilTexture
{
    if (_charonDepthStencilPixelFormat == MTLPixelFormatInvalid)
        return nil;
    CGSize size = self.drawableSize;
    if (!_charonDepthStencilTexture || _charonDepthStencilTexture.width != (NSUInteger)size.width || _charonDepthStencilTexture.height != (NSUInteger)size.height) {
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_charonDepthStencilPixelFormat width:(NSUInteger)size.width height:(NSUInteger)size.height mipmapped:NO];
        descriptor.usage = _charonDepthStencilAttachmentTextureUsage;
        _charonDepthStencilTexture = [_charonDevice newTextureWithDescriptor:descriptor];
    }
    return _charonDepthStencilTexture;
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
    descriptor.colorAttachments[0].clearColor = _charonClearColor;
    if (_charonDepthStencilPixelFormat != MTLPixelFormatInvalid) {
        id<MTLTexture> depthStencil = self.depthStencilTexture;
        descriptor.depthAttachment.texture = depthStencil;
        descriptor.depthAttachment.loadAction = MTLLoadActionClear;
        descriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
        descriptor.depthAttachment.clearDepth = _charonClearDepth;
        descriptor.stencilAttachment.texture = depthStencil;
        descriptor.stencilAttachment.loadAction = MTLLoadActionClear;
        descriptor.stencilAttachment.storeAction = MTLStoreActionDontCare;
        descriptor.stencilAttachment.clearStencil = _charonClearStencil;
    }
    return descriptor;
}

- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    if (_charonEnableSetNeedsDisplay)
        [self draw];
}

@end
