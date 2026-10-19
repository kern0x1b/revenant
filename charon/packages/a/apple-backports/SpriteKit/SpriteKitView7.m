// SpriteKitView7.m - SKView of iOS 7, carried for the releases that have no SpriteKit at all. iOS only.
//
// The view is a UIView over a CAEAGLLayer, with an OpenGL ES 2 context and a framebuffer of the layer's size. A display
// link steps the presented scene once per frame, in the order the SDK documents (update:, the delegate's update, the
// actions, the physics, then the constraints and the frame, which the two iOS 8 hooks are called for when the scene
// answers them), and then clears the framebuffer to the scene's background colour and presents it. The nodes draw
// nothing yet: their content is the step that carries it. The host's frame order is not measured (the host's view has
// no public step), so the order is the documented one. Device-unverified: this object is compiled for armv7 only.
#if TARGET_OS_IPHONE
#import "CharonSpriteKit.h"
#import "CharonSpriteKitProtocols.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/gl.h>
#include <objc/message.h>

@implementation SKView {
    SKScene *_scene;
    BOOL _paused;
    BOOL _showsFPS;
    BOOL _showsDrawCount;
    BOOL _showsNodeCount;
    BOOL _asynchronous;
    BOOL _ignoresSiblingOrder;
    NSInteger _frameInterval;
    EAGLContext *_context;
    GLuint _framebuffer;
    GLuint _renderbuffer;
    CADisplayLink *_displayLink;
}

@synthesize paused = _paused;
@synthesize showsFPS = _showsFPS;
@synthesize showsDrawCount = _showsDrawCount;
@synthesize showsNodeCount = _showsNodeCount;
@synthesize asynchronous = _asynchronous;
@synthesize ignoresSiblingOrder = _ignoresSiblingOrder;

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self charon_setUp];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self charon_setUp];
    }
    return self;
}

- (void)charon_setUp
{
    CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
    layer.opaque = YES;
    layer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking: @NO,
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
    };
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _frameInterval = 1;
}

// The framebuffer is made once the context is current, and its colour buffer takes the layer's storage. It is made
// again when the view changes size, so the storage follows the layer.
- (void)charon_makeBuffers
{
    if (_context == nil) {
        return;
    }
    [EAGLContext setCurrentContext:_context];
    if (_framebuffer == 0) {
        glGenFramebuffers(1, &_framebuffer);
        glGenRenderbuffers(1, &_renderbuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    }
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self charon_makeBuffers];
}

// The display link runs while the view is in a window, and stops when it leaves.
- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window != nil && _displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(charon_frame:)];
        _displayLink.frameInterval = _frameInterval;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    } else if (self.window == nil && _displayLink != nil) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)setFrameInterval:(NSInteger)frameInterval
{
    _frameInterval = frameInterval;
    _displayLink.frameInterval = frameInterval;
}

- (NSInteger)frameInterval
{
    return _frameInterval;
}

- (SKScene *)scene
{
    return _scene;
}

- (void)presentScene:(SKScene *)scene
{
    SKScene *previous = _scene;
    [previous willMoveFromView:self];
    [previous charon_setView:nil];
    _scene = scene;
    [scene charon_setView:self];
    [scene didMoveToView:self];
}

- (void)charon_frame:(CADisplayLink *)link
{
    SKScene *scene = _scene;
    if (scene != nil && !_paused) {
        [self charon_stepScene:scene time:link.timestamp];
    }
    [self charon_draw];
}

// The scene's update order: its update:, then its delegate's, then the actions, the physics, the constraints and the
// frame. The delegate and the iOS 8 hooks are called only where the scene answers them.
- (void)charon_stepScene:(SKScene *)scene time:(NSTimeInterval)time
{
    [scene update:time];
    if ([scene respondsToSelector:@selector(delegate)] && [scene.delegate respondsToSelector:@selector(update:forScene:)]) {
        [scene.delegate update:time forScene:scene];
    }
    [scene didEvaluateActions];
    if ([scene respondsToSelector:@selector(delegate)] && [scene.delegate respondsToSelector:@selector(didEvaluateActionsForScene:)]) {
        [scene.delegate didEvaluateActionsForScene:scene];
    }
    [scene didSimulatePhysics];
    if ([scene respondsToSelector:@selector(delegate)] && [scene.delegate respondsToSelector:@selector(didSimulatePhysicsForScene:)]) {
        [scene.delegate didSimulatePhysicsForScene:scene];
    }
    if ([scene respondsToSelector:@selector(didApplyConstraints)]) {
        [scene didApplyConstraints];
        if ([scene respondsToSelector:@selector(delegate)] && [scene.delegate respondsToSelector:@selector(didApplyConstraintsForScene:)]) {
            [scene.delegate didApplyConstraintsForScene:scene];
        }
    }
    if ([scene respondsToSelector:@selector(didFinishUpdate)]) {
        [scene didFinishUpdate];
        if ([scene respondsToSelector:@selector(delegate)] && [scene.delegate respondsToSelector:@selector(didFinishUpdateForScene:)]) {
            [scene.delegate didFinishUpdateForScene:scene];
        }
    }
}

// The background colour of the presented scene is the colour the frame clears to; with no scene the frame clears to black.
- (void)charon_draw
{
    if (_context == nil || _framebuffer == 0) {
        return;
    }
    [EAGLContext setCurrentContext:_context];
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    GLint width = 0;
    GLint height = 0;
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    glViewport(0, 0, width, height);
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 1;
    UIColor *background = _scene.backgroundColor;
    if (background != nil && ![background getRed:&red green:&green blue:&blue alpha:&alpha]) {
        red = green = blue = 0;
        alpha = 1;
    }
    glClearColor(red, green, blue, alpha);
    glClear(GL_COLOR_BUFFER_BIT);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

@end
#endif
