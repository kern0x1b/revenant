#import "CharonMetal.h"
#import <objc/runtime.h>


@implementation CharonMetalDrawable {
    CharonMetalTexture *_texture;
    __weak CAMetalLayer *_layer;
    EAGLContext *_context;
    GLuint _renderbuffer;
}

- (instancetype)initWithTexture:(CharonMetalTexture *)texture layer:(CAMetalLayer *)layer context:(EAGLContext *)context
{
    if ((self = [super init])) {
        _texture = texture;
        _layer = layer;
        _context = context;
    }
    return self;
}

- (id<MTLTexture>)texture
{
    return (id<MTLTexture>)_texture;
}

- (CAMetalLayer *)layer
{
    return _layer;
}

- (NSUInteger)drawableID
{
    return 0;
}

- (void)present
{
    CharonMetalDevice *device = [CharonMetalDevice shared];
    [device acquire];
    GLint renderbuffer = 0;
    glBindFramebuffer(GL_FRAMEBUFFER, _texture.framebuffer);
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    [device relinquish];
}

- (void)presentAtTime:(CFTimeInterval)presentationTime
{
    [self present];
}

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration
{
    [self present];
}

- (void)addPresentedHandler:(MTLDrawablePresentedHandler)block
{
}

- (CFTimeInterval)presentedTime
{
    return 0;
}

@end

@interface CharonMetalLayerState : NSObject
@property (nonatomic, strong) CAEAGLLayer *layer;
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) GLuint renderbuffer;
@property (nonatomic, strong) CharonMetalTexture *texture;
@property (nonatomic) CGSize size;
@end

@implementation CharonMetalLayerState

@synthesize layer = _layer, framebuffer = _framebuffer, renderbuffer = _renderbuffer, texture = _texture, size = _size;

- (void)dealloc
{
    if (_framebuffer) {
        CharonMetalDevice *device = [CharonMetalDevice shared];
        [device acquire];
        glDeleteFramebuffers(1, &_framebuffer);
        glDeleteRenderbuffers(1, &_renderbuffer);
        [device relinquish];
    }
}

@end

static char stateKey;

id<CAMetalDrawable> CharonMetalNextDrawable(CAMetalLayer *layer)
{
    CharonMetalDevice *device = [CharonMetalDevice shared];
    CGSize size = layer.drawableSize;
    CGSize bounds = layer.bounds.size;
    if (!device || size.width < 1 || size.height < 1 || bounds.width <= 0 || layer.device != (id)device)
        return nil;
    CharonMetalLayerState *state = objc_getAssociatedObject(layer, &stateKey);
    if (!state) {
        state = [[CharonMetalLayerState alloc] init];
        state.layer = [CAEAGLLayer layer];
        state.layer.opaque = YES;
        state.layer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @NO, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
        [layer addSublayer:state.layer];
        objc_setAssociatedObject(layer, &stateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [device acquire];
    state.layer.frame = layer.bounds;
    state.layer.contentsScale = size.width / bounds.width;
    state.layer.opaque = layer.isOpaque;
    if (!state.texture || !CGSizeEqualToSize(state.size, size)) {
        if (!state.framebuffer) {
            GLuint fbo, rbo;
            glGenFramebuffers(1, &fbo);
            glGenRenderbuffers(1, &rbo);
            state.framebuffer = fbo;
            state.renderbuffer = rbo;
        }
        glBindFramebuffer(GL_FRAMEBUFFER, state.framebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, state.renderbuffer);
        [device.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:state.layer];
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, state.renderbuffer);
        GLint w = 0, h = 0;
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &w);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &h);
        state.texture = [[CharonMetalTexture alloc] initScreenWithFramebuffer:state.framebuffer width:w height:h pixelFormat:layer.pixelFormat];
        state.size = size;
    }
    [device relinquish];
    return (id<CAMetalDrawable>)[[CharonMetalDrawable alloc] initWithTexture:state.texture layer:layer context:device.context];
}
