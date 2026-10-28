#import "RevenantMetal.h"
#import <objc/runtime.h>


static NSUInteger revenant_drawable_counter;
static const char revenant_last_presented_key;

@implementation RevenantMetalDrawable {
    RevenantMetalTexture *_texture;
    __weak CAMetalLayer *_layer;
    EAGLContext *_context;
    GLuint _renderbuffer;
    NSMutableArray *_presentedHandlers;
    NSUInteger _drawableID;
    CFTimeInterval _presentedTime;
}

- (instancetype)initWithTexture:(RevenantMetalTexture *)texture layer:(CAMetalLayer *)layer context:(EAGLContext *)context
{
    if ((self = [super init])) {
        _texture = texture;
        _layer = layer;
        _context = context;
        _drawableID = __sync_add_and_fetch(&revenant_drawable_counter, 1);
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
    return _drawableID;
}

- (void)present
{
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    [device acquire];
    GLint renderbuffer = 0;
    glBindFramebuffer(GL_FRAMEBUFFER, _texture.framebuffer);
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    _presentedTime = CACurrentMediaTime();
    if (_layer)
        objc_setAssociatedObject(_layer, &revenant_last_presented_key, @(_presentedTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [device relinquish];
    NSArray *handlers = _presentedHandlers;
    _presentedHandlers = nil;
    for (MTLDrawablePresentedHandler handler in handlers)
        handler((id<MTLDrawable>)self);
}

- (void)presentAtTime:(CFTimeInterval)presentationTime
{
    CFTimeInterval delay = presentationTime - CACurrentMediaTime();
    if (delay <= 0) {
        [self present];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self present];
    });
}

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration
{
    NSNumber *last = _layer ? objc_getAssociatedObject(_layer, &revenant_last_presented_key) : nil;
    [self presentAtTime:last ? last.doubleValue + duration : 0];
}

- (void)addPresentedHandler:(MTLDrawablePresentedHandler)block
{
    if (!block)
        return;
    if (!_presentedHandlers)
        _presentedHandlers = [NSMutableArray array];
    [_presentedHandlers addObject:block];
}

- (CFTimeInterval)presentedTime
{
    return _presentedTime;
}

@end

@interface RevenantMetalLayerState : NSObject
@property (nonatomic, strong) CAEAGLLayer *layer;
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) GLuint renderbuffer;
@property (nonatomic, strong) RevenantMetalTexture *texture;
@property (nonatomic) CGSize size;
@end

@implementation RevenantMetalLayerState

@synthesize layer = _layer, framebuffer = _framebuffer, renderbuffer = _renderbuffer, texture = _texture, size = _size;

- (void)dealloc
{
    if (_framebuffer) {
        RevenantMetalDevice *device = [RevenantMetalDevice shared];
        [device acquire];
        glDeleteFramebuffers(1, &_framebuffer);
        glDeleteRenderbuffers(1, &_renderbuffer);
        [device relinquish];
    }
}

@end

static char stateKey;

id<CAMetalDrawable> RevenantMetalNextDrawable(CAMetalLayer *layer)
{
    RevenantMetalDevice *device = [RevenantMetalDevice shared];
    CGSize size = layer.drawableSize;
    CGSize bounds = layer.bounds.size;
    if (!device || size.width < 1 || size.height < 1 || bounds.width <= 0 || layer.device != (id)device)
        return nil;
    RevenantMetalLayerState *state = objc_getAssociatedObject(layer, &stateKey);
    if (!state) {
        state = [[RevenantMetalLayerState alloc] init];
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
        state.texture = [[RevenantMetalTexture alloc] initScreenWithFramebuffer:state.framebuffer width:w height:h pixelFormat:layer.pixelFormat];
        state.size = size;
    }
    [device relinquish];
    return (id<CAMetalDrawable>)[[RevenantMetalDrawable alloc] initWithTexture:state.texture layer:layer context:device.context];
}
