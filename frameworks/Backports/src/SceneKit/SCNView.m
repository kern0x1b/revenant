#import "RevenantSCN.h"
#import "RevenantSCNClock.h"
#import "RevenantSCNJitter.h"
#import "RevenantSCNJitterBuffers.h"
#import "RevenantSCNMath.h"
#import "../RevenantSayOnce.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>

static void revenant_unsupported(const char *member)
{
    [NSException raise:NSInternalInconsistencyException format:@"SCNView: %s is not supported by this SceneKit backport", member];
}

@interface SCNView () <SCNSceneRenderer>
@end

@implementation SCNView
{
    EAGLContext *_context;
    RevenantSCNRenderEngine *_renderer;
    GLuint _framebuffer, _colorBuffer, _depthBuffer;
    GLint _drawableWidth, _drawableHeight;
    CADisplayLink *_displayLink;
    SCNScene *_scene;
    SCNNode *_pointOfView;
    SCNNode *_audioListener;
    __weak id<SCNSceneRendererDelegate> _delegate;
    NSInteger _preferredFramesPerSecond;
    BOOL _jitteringEnabled;
    RevenantSCNClock *_clock;
    RevenantSCNJitterBuffers *_jitter;
    NSUInteger _jitterFrame;
    NSUInteger _jitterAccumulated;
    BOOL _jitterKeyValid;
    NSTimeInterval _jitterTime;
    SCNScene *_jitterScene;
    SCNNode *_jitterPointOfView;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame options:(NSDictionary<NSString *, id> *)options
{
    if ((self = [super initWithFrame:frame])) {
        [self revenantSetUp];
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
        [self revenantSetUp];
    }
    return self;
}

- (void)revenantSetUp
{
    _clock = [[RevenantSCNClock alloc] init];
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
    layer.opaque = NO;
    layer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (context == nil) {
        revenant_say_once_for(@"scenekit no context", @"SceneKit: this device has no OpenGL ES 2.0 context: an SCNView draws nothing, -snapshot answers nil and no frame is reported to its delegate");
    }
    [self revenantSetContext:context];
}

- (void)dealloc
{
    [_displayLink invalidate];
    [self revenantDeleteFramebuffer];
}

#pragma mark Context and framebuffer

- (void)revenantSetContext:(EAGLContext *)context
{
    if (context == _context) {
        return;
    }
    [self revenantDeleteFramebuffer];
    _context = context;
    _renderer = context ? [[RevenantSCNRenderEngine alloc] initWithContext:context] : nil;
}

- (void)revenantDeleteFramebuffer
{
    if (_context == nil) {
        return;
    }
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    [_jitter dispose];
    _jitter = nil;
    _jitterKeyValid = NO;
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        glDeleteRenderbuffers(1, &_colorBuffer);
        glDeleteRenderbuffers(1, &_depthBuffer);
        _framebuffer = _colorBuffer = _depthBuffer = 0;
        _drawableWidth = _drawableHeight = 0;
    }
    [EAGLContext setCurrentContext:previous];
}

- (BOOL)revenantPrepareDrawable
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
        revenant_say_once_for(@"scenekit drawable", @"SceneKit: the view's layer would not give the context a drawable: nothing is drawn to the view");
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
    [self revenantDrawFrame];
}

#pragma mark Frames

- (void)revenantClear
{
    float c[4] = {0, 0, 0, 0};
    UIColor *background = self.backgroundColor;
    CGFloat r, g, b, a;
    if (background && [background getRed:&r green:&g blue:&b alpha:&a]) {
        c[0] = (float)(r * a); c[1] = (float)(g * a); c[2] = (float)(b * a); c[3] = (float)a;
    } else if (background && [background getWhite:&r alpha:&a]) {
        c[0] = c[1] = c[2] = (float)(r * a); c[3] = (float)a;
    }
    glClearColor(c[0], c[1], c[2], c[3]);
    glDepthMask(GL_TRUE);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

- (void)revenantRenderAtTime:(NSTimeInterval)time width:(GLint)width height:(GLint)height framebuffer:(GLuint)framebuffer
{
    id<SCNSceneRendererDelegate> delegate = _delegate;
    SCNScene *scene = _scene;
    if ([delegate respondsToSelector:@selector(renderer:updateAtTime:)]) {
        [delegate renderer:self updateAtTime:time];
    }
    if (scene) {
        [RevenantSCNAnimations evaluateScene:scene atTime:time listener:_audioListener ?: _pointOfView];
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
    if (_jitteringEnabled && scene) {
        [self revenantDrawJitteredScene:scene pointOfView:_pointOfView width:width height:height time:time framebuffer:framebuffer];
    } else {
        [self revenantClear];
        [_renderer renderScene:scene pointOfView:_pointOfView width:width height:height];
        _jitterKeyValid = NO;
    }
    if (scene && [delegate respondsToSelector:@selector(renderer:didRenderScene:atTime:)]) {
        [delegate renderer:self didRenderScene:scene atTime:time];
    }
}

- (void)revenantDrawJitteredScene:(SCNScene *)scene pointOfView:(SCNNode *)pointOfView width:(int)width height:(int)height time:(NSTimeInterval)time framebuffer:(GLuint)framebuffer
{
    if (_jitter == nil) {
        _jitter = [[RevenantSCNJitterBuffers alloc] init];
    }
    if (![_jitter isUsable]) {
        [self revenantClear];
        [_renderer renderScene:scene pointOfView:pointOfView width:width height:height];
        return;
    }
    [_jitter resizeToWidth:width height:height];
    if (!_jitterKeyValid || time != _jitterTime || scene != _jitterScene || pointOfView != _jitterPointOfView) {
        _jitterAccumulated = 0;
        _jitterTime = time;
        _jitterScene = scene;
        _jitterPointOfView = pointOfView;
        _jitterKeyValid = YES;
    }
    if (_jitterAccumulated < [RevenantSCNJitter sampleCount]) {
        float x = 0, y = 0;
        [RevenantSCNJitter offsetForFrame:_jitterFrame x:&x y:&y];
        [_jitter bindSampleFramebuffer];
        [self revenantClear];
        _renderer.jitterX = x;
        _renderer.jitterY = y;
        [_renderer renderScene:scene pointOfView:pointOfView width:width height:height];
        _renderer.jitterX = 0;
        _renderer.jitterY = 0;
        [_jitter accumulateSampleWithWeight:[RevenantSCNJitter weightForAccumulated:_jitterAccumulated]];
        _jitterAccumulated++;
    }
    _jitterFrame++;
    [_jitter presentToFramebuffer:framebuffer];
}

- (void)revenantDrawFrame
{
    if (_context == nil || self.window == nil) {
        return;
    }
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    if ([self revenantPrepareDrawable]) {
        [self revenantRenderAtTime:[_clock sceneTimeAtWallTime:CACurrentMediaTime()] width:_drawableWidth height:_drawableHeight framebuffer:_framebuffer];
        glBindRenderbuffer(GL_RENDERBUFFER, _colorBuffer);
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    [EAGLContext setCurrentContext:previous];
}

- (void)revenantDisplayLinkFired:(CADisplayLink *)link
{
    [self revenantDrawFrame];
}

- (void)revenantUpdateDisplayLink
{
    BOOL wanted = self.window != nil && _scene != nil;
    if (!wanted) {
        [_displayLink invalidate];
        _displayLink = nil;
        return;
    }
    if (_displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(revenantDisplayLinkFired:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    NSInteger fps = _preferredFramesPerSecond;
    _displayLink.frameInterval = fps <= 0 || fps >= 60 ? 1 : MAX(1, (NSInteger)lround(60.0 / (double)fps));
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self revenantUpdateDisplayLink];
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
        [self revenantRenderAtTime:0 width:width height:height framebuffer:framebuffer];
        NSMutableData *pixels = [NSMutableData dataWithLength:(NSUInteger)(width * height * 4)];
        glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels.mutableBytes);
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
    _pointOfView = scene ? [RevenantSCNRenderEngine defaultPointOfViewInScene:scene] : nil;
    [self revenantUpdateDisplayLink];
}

- (SCNNode *)pointOfView
{
    return _pointOfView;
}

- (SCNNode *)audioListener
{
    return _audioListener;
}

- (void)setAudioListener:(SCNNode *)audioListener
{
    _audioListener = audioListener;
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
    [self revenantUpdateDisplayLink];
}

- (BOOL)isJitteringEnabled
{
    return _jitteringEnabled;
}

- (void)setJitteringEnabled:(BOOL)jitteringEnabled
{
    _jitteringEnabled = jitteringEnabled;
    _jitterKeyValid = NO;
}

- (EAGLContext *)eaglContext
{
    return _context;
}

- (void)setEaglContext:(EAGLContext *)eaglContext
{
    [self revenantSetContext:eaglContext];
}

- (SCNRenderingAPI)renderingAPI
{
    return SCNRenderingAPIOpenGLES2;
}

- (void *)context
{
    return (__bridge void *)_context;
}

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

- (NSTimeInterval)sceneTime
{
    return [_clock sceneTimeAtWallTime:CACurrentMediaTime()];
}

- (void)setSceneTime:(NSTimeInterval)sceneTime
{
    [_clock setSceneTime:sceneTime atWallTime:CACurrentMediaTime()];
}

- (BOOL)isPlaying
{
    return [_clock isPlaying];
}

- (void)setPlaying:(BOOL)playing
{
    [_clock setPlaying:playing atWallTime:CACurrentMediaTime()];
}

- (AVAudioEngine *)audioEngine
{
    return [RevenantSCNSoundEngine nodeEngine];
}

- (void)presentScene:(SCNScene *)scene withTransition:(SKTransition *)transition incomingPointOfView:(nullable SCNNode *)pointOfView completionHandler:(nullable void (^)(void))completionHandler
{
    revenant_unsupported("presentScene:withTransition:incomingPointOfView:completionHandler:");
}

- (NSArray<SCNHitTestResult *> *)hitTest:(CGPoint)point options:(nullable NSDictionary<SCNHitTestOption, id> *)options
{
    revenant_unsupported("hitTest:options:");
    return nil;
}

- (BOOL)isNodeInsideFrustum:(SCNNode *)node withPointOfView:(SCNNode *)pointOfView
{
    revenant_unsupported("isNodeInsideFrustum:withPointOfView:");
    return NO;
}

- (NSArray<SCNNode *> *)nodesInsideFrustumWithPointOfView:(SCNNode *)pointOfView
{
    revenant_unsupported("nodesInsideFrustumWithPointOfView:");
    return nil;
}

- (BOOL)prepareObject:(id)object shouldAbortBlock:(nullable NS_NOESCAPE BOOL (^)(void))block
{
    revenant_unsupported("prepareObject:shouldAbortBlock:");
    return NO;
}

- (void)prepareObjects:(NSArray *)objects withCompletionHandler:(nullable void (^)(BOOL success))completionHandler
{
    revenant_unsupported("prepareObjects:withCompletionHandler:");
}

- (BOOL)loops
{
    revenant_unsupported("loops");
    return NO;
}

- (void)setLoops:(BOOL)loops
{
    revenant_unsupported("loops");
}

- (BOOL)autoenablesDefaultLighting
{
    revenant_unsupported("autoenablesDefaultLighting");
    return NO;
}

- (void)setAutoenablesDefaultLighting:(BOOL)autoenablesDefaultLighting
{
    revenant_unsupported("autoenablesDefaultLighting");
}

- (BOOL)isTemporalAntialiasingEnabled
{
    revenant_unsupported("temporalAntialiasingEnabled");
    return NO;
}

- (void)setTemporalAntialiasingEnabled:(BOOL)temporalAntialiasingEnabled
{
    revenant_unsupported("temporalAntialiasingEnabled");
}

- (BOOL)showsStatistics
{
    revenant_unsupported("showsStatistics");
    return NO;
}

- (void)setShowsStatistics:(BOOL)showsStatistics
{
    revenant_unsupported("showsStatistics");
}

- (SCNDebugOptions)debugOptions
{
    revenant_unsupported("debugOptions");
    return 0;
}

- (void)setDebugOptions:(SCNDebugOptions)debugOptions
{
    revenant_unsupported("debugOptions");
}

- (SKScene *)overlaySKScene
{
    revenant_unsupported("overlaySKScene");
    return nil;
}

- (void)setOverlaySKScene:(SKScene *)overlaySKScene
{
    revenant_unsupported("overlaySKScene");
}

- (BOOL)usesReverseZ
{
    revenant_unsupported("usesReverseZ");
    return NO;
}

- (void)setUsesReverseZ:(BOOL)usesReverseZ
{
    revenant_unsupported("usesReverseZ");
}

- (CGColorSpaceRef)workingColorSpace
{
    revenant_unsupported("workingColorSpace");
    return NULL;
}

- (MTLRenderPassDescriptor *)currentRenderPassDescriptor
{
    revenant_unsupported("currentRenderPassDescriptor");
    return nil;
}

- (MTLPixelFormat)colorPixelFormat
{
    revenant_unsupported("colorPixelFormat");
    return MTLPixelFormatInvalid;
}

- (MTLPixelFormat)depthPixelFormat
{
    revenant_unsupported("depthPixelFormat");
    return MTLPixelFormatInvalid;
}

- (MTLPixelFormat)stencilPixelFormat
{
    revenant_unsupported("stencilPixelFormat");
    return MTLPixelFormatInvalid;
}

- (AVAudioEnvironmentNode *)audioEnvironmentNode
{
    revenant_unsupported("audioEnvironmentNode");
    return nil;
}

- (CGRect)currentViewport
{
    revenant_unsupported("currentViewport");
    return CGRectZero;
}

@end
