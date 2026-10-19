#import "CharonSCN.h"
#import "CharonSCNMath.h"
#import "../CharonSayOnce.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>

// SCNView over OpenGL ES 2.0 (facts/SceneKit/SCNView.md). Defaults and the order of the delegate's messages are
// macOS SceneKit's, measured: preferredFramesPerSecond 0 (the display's own rate), jittering off, the point of view
// the scene's first camera node once a scene is set; -snapshot sends the delegate the whole sequence of a frame on
// the calling thread.

@implementation SCNView
{
    EAGLContext *_context;
    CharonSCNRenderer *_renderer;
    GLuint _framebuffer, _colorBuffer, _depthBuffer;
    GLint _drawableWidth, _drawableHeight;
    CADisplayLink *_displayLink;
    SCNScene *_scene;
    SCNNode *_pointOfView;
    __weak id<SCNSceneRendererDelegate> _delegate;
    NSInteger _preferredFramesPerSecond;
    BOOL _jitteringEnabled;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame options:(NSDictionary<NSString *, id> *)options
{
    if ((self = [super initWithFrame:frame])) {
        [self charonSetUp];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame options:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self charonSetUp];
    }
    return self;
}

- (void)charonSetUp
{
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
    layer.opaque = NO;
    layer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (context == nil) {
        charon_say_once_for(@"scenekit no context", @"SceneKit: this device has no OpenGL ES 2.0 context: an SCNView draws nothing, -snapshot answers nil and no frame is reported to its delegate");
    }
    [self charonSetContext:context];
}

- (void)dealloc
{
    [_displayLink invalidate];
    [self charonDeleteFramebuffer];
}

#pragma mark Context and framebuffer

- (void)charonSetContext:(EAGLContext *)context
{
    if (context == _context) {
        return;
    }
    [self charonDeleteFramebuffer];
    _context = context;
    _renderer = context ? [[CharonSCNRenderer alloc] initWithContext:context] : nil;
}

- (void)charonDeleteFramebuffer
{
    if (_context == nil || _framebuffer == 0) {
        return;
    }
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    glDeleteFramebuffers(1, &_framebuffer);
    glDeleteRenderbuffers(1, &_colorBuffer);
    glDeleteRenderbuffers(1, &_depthBuffer);
    _framebuffer = _colorBuffer = _depthBuffer = 0;
    _drawableWidth = _drawableHeight = 0;
    [EAGLContext setCurrentContext:previous];
}

// The layer's drawable at the view's size in pixels; NO when the view has no area to draw into.
- (BOOL)charonPrepareDrawable
{
    GLint width = (GLint)lroundf(self.bounds.size.width * self.contentScaleFactor);
    GLint height = (GLint)lroundf(self.bounds.size.height * self.contentScaleFactor);
    if (width <= 0 || height <= 0) {
        return NO;
    }
    if (_framebuffer && width == _drawableWidth && height == _drawableHeight) {
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        return YES;
    }
    if (_framebuffer == 0) {
        glGenFramebuffers(1, &_framebuffer);
        glGenRenderbuffers(1, &_colorBuffer);
        glGenRenderbuffers(1, &_depthBuffer);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBuffer);
    if (![_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer]) {
        charon_say_once_for(@"scenekit drawable", @"SceneKit: the view's layer would not give the context a drawable: nothing is drawn to the view");
        return NO;
    }
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_drawableWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_drawableHeight);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, _drawableWidth, _drawableHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthBuffer);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"SceneKit: the view's framebuffer is not complete (0x%x)", status);
        return NO;
    }
    return YES;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self charonDrawFrame];
}

#pragma mark Frames

- (void)charonClear
{
    float c[4] = {0, 0, 0, 0};
    UIColor *background = self.backgroundColor;
    CGFloat r, g, b, a;
    if (background && [background getRed:&r green:&g blue:&b alpha:&a]) {
        // the view clears to its background colour, premultiplied as the layer composites it
        c[0] = (float)(r * a); c[1] = (float)(g * a); c[2] = (float)(b * a); c[3] = (float)a;
    } else if (background && [background getWhite:&r alpha:&a]) {
        c[0] = c[1] = c[2] = (float)(r * a); c[3] = (float)a;
    }
    glClearColor(c[0], c[1], c[2], c[3]);
    glDepthMask(GL_TRUE);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

// One frame, the way SceneKit sends it to the delegate: update, animations, physics, constraints, then the render.
- (void)charonRenderAtTime:(NSTimeInterval)time width:(GLint)width height:(GLint)height
{
    id<SCNSceneRendererDelegate> delegate = _delegate;
    SCNScene *scene = _scene;
    if ([delegate respondsToSelector:@selector(renderer:updateAtTime:)]) {
        [delegate renderer:self updateAtTime:time];
    }
    if (scene) {
        // animations run on media time, also for a snapshot, whose delegate time is 0
        [CharonSCNAnimations evaluateScene:scene atTime:CACurrentMediaTime()];
    }
    if ([delegate respondsToSelector:@selector(renderer:didApplyAnimationsAtTime:)]) {
        [delegate renderer:self didApplyAnimationsAtTime:time];
    }
    if ([delegate respondsToSelector:@selector(renderer:didSimulatePhysicsAtTime:)]) {
        [delegate renderer:self didSimulatePhysicsAtTime:time];
    }
    if ([delegate respondsToSelector:@selector(renderer:didApplyConstraintsAtTime:)]) {
        [delegate renderer:self didApplyConstraintsAtTime:time];
    }
    if (scene && [delegate respondsToSelector:@selector(renderer:willRenderScene:atTime:)]) {
        [delegate renderer:self willRenderScene:scene atTime:time];
    }
    [self charonClear];
    [_renderer renderScene:scene pointOfView:_pointOfView width:width height:height];
    if (scene && [delegate respondsToSelector:@selector(renderer:didRenderScene:atTime:)]) {
        [delegate renderer:self didRenderScene:scene atTime:time];
    }
}

- (void)charonDrawFrame
{
    if (_context == nil || self.window == nil) {
        return;
    }
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    if ([self charonPrepareDrawable]) {
        [self charonRenderAtTime:CACurrentMediaTime() width:_drawableWidth height:_drawableHeight];
        glBindRenderbuffer(GL_RENDERBUFFER, _colorBuffer);
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    [EAGLContext setCurrentContext:previous];
}

- (void)charonDisplayLinkFired:(CADisplayLink *)link
{
    [self charonDrawFrame];
}

- (void)charonUpdateDisplayLink
{
    BOOL wanted = self.window != nil && _scene != nil;
    if (!wanted) {
        [_displayLink invalidate];
        _displayLink = nil;
        return;
    }
    if (_displayLink == nil) {
        // the link holds its target strongly; the view invalidates it when it leaves its window
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(charonDisplayLinkFired:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    // the link's interval is in frames of the 60 Hz display; 0 asks for every frame
    NSInteger fps = _preferredFramesPerSecond;
    _displayLink.frameInterval = fps <= 0 || fps >= 60 ? 1 : MAX(1, (NSInteger)lround(60.0 / (double)fps));
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self charonUpdateDisplayLink];
}

- (UIImage *)snapshot
{
    GLint width = (GLint)lroundf(self.bounds.size.width * self.contentScaleFactor);
    GLint height = (GLint)lroundf(self.bounds.size.height * self.contentScaleFactor);
    if (_context == nil || width <= 0 || height <= 0) {
        return nil;
    }
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    GLuint framebuffer, color, depth;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glGenRenderbuffers(1, &color);
    glBindRenderbuffer(GL_RENDERBUFFER, color);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, color);
    glGenRenderbuffers(1, &depth);
    glBindRenderbuffer(GL_RENDERBUFFER, depth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24_OES, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth);
    UIImage *image = nil;
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        // macOS SceneKit's snapshot renders at scene time 0 and sends the delegate the frame's messages
        [self charonRenderAtTime:0 width:width height:height];
        NSMutableData *pixels = [NSMutableData dataWithLength:(NSUInteger)(width * height * 4)];
        glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels.mutableBytes);
        // GL's first row is the bottom one
        NSMutableData *flipped = [NSMutableData dataWithLength:pixels.length];
        size_t row = (size_t)width * 4;
        for (GLint y = 0; y < height; y++) {
            memcpy((uint8_t *)flipped.mutableBytes + (size_t)y * row, (const uint8_t *)pixels.bytes + (size_t)(height - 1 - y) * row, row);
        }
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)flipped);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGImageRef cgImage = CGImageCreate((size_t)width, (size_t)height, 8, 32, row, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
        CGColorSpaceRelease(space);
        CGDataProviderRelease(provider);
        image = [UIImage imageWithCGImage:cgImage scale:self.contentScaleFactor orientation:UIImageOrientationUp];
        CGImageRelease(cgImage);
    }
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteRenderbuffers(1, &color);
    glDeleteRenderbuffers(1, &depth);
    [EAGLContext setCurrentContext:previous];
    return image;
}

#pragma mark Properties

- (SCNScene *)scene
{
    return _scene;
}

- (void)setScene:(SCNScene *)scene
{
    _scene = scene;
    _pointOfView = scene ? [CharonSCNRenderer defaultPointOfViewInScene:scene] : nil;
    [self charonUpdateDisplayLink];
}

- (SCNNode *)pointOfView
{
    return _pointOfView;
}

- (void)setPointOfView:(SCNNode *)pointOfView
{
    _pointOfView = pointOfView;
}

- (id<SCNSceneRendererDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<SCNSceneRendererDelegate>)delegate
{
    _delegate = delegate;
}

- (NSInteger)preferredFramesPerSecond
{
    return _preferredFramesPerSecond;
}

- (void)setPreferredFramesPerSecond:(NSInteger)preferredFramesPerSecond
{
    _preferredFramesPerSecond = preferredFramesPerSecond;
    [self charonUpdateDisplayLink];
}

- (BOOL)isJitteringEnabled
{
    return _jitteringEnabled;
}

- (void)setJitteringEnabled:(BOOL)jitteringEnabled
{
    _jitteringEnabled = jitteringEnabled;
    if (jitteringEnabled) {
        charon_say_once_for(@"scenekit jittering", @"SceneKit: SCNView keeps jitteringEnabled, but a still scene is not refined by jittered frames yet");
    }
}

- (EAGLContext *)eaglContext
{
    return _context;
}

- (void)setEaglContext:(EAGLContext *)eaglContext
{
    [self charonSetContext:eaglContext];
}

- (SCNRenderingAPI)renderingAPI
{
    return SCNRenderingAPIOpenGLES2;
}

- (void *)context
{
    return (__bridge void *)_context;
}

// A renderer that is not Metal answers nil for Metal's objects, as SceneKit's own OpenGL renderer does.
- (id<MTLRenderCommandEncoder>)currentRenderCommandEncoder
{
    return nil;
}

- (id<MTLDevice>)device
{
    return nil;
}

- (id<MTLCommandQueue>)commandQueue
{
    return nil;
}

@end
