#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <objc/runtime.h>

@protocol RevenantMetalDeviceContext <NSObject>
@property (nonatomic, readonly) EAGLContext *context;
- (void)acquire;
- (void)relinquish;
@end

@protocol RevenantMetalRenderTarget <NSObject>
- (GLuint)renderTarget;
@end

static const char revenant_bridge_key;

@interface RevenantOutputContext : NSObject
@property (nonatomic, readonly) id output;
@property (nonatomic, readonly) CIContext *context;
- (instancetype)initWithOutput:(id)output context:(CIContext *)context;
@end

@implementation RevenantOutputContext

@synthesize output = _output;
@synthesize context = _context;

- (instancetype)initWithOutput:(id)output context:(CIContext *)context
{
    self = [super init];
    if (self) {
        _output = output;
        _context = context;
    }
    return self;
}

@end

@interface RevenantBridgedContext : NSObject
@property (nonatomic, copy) NSDictionary *options;
@property (nonatomic, readonly) NSMutableArray<RevenantOutputContext *> *outputs;
@end

@implementation RevenantBridgedContext

@synthesize options = _options;
@synthesize outputs = _outputs;

- (instancetype)init
{
    self = [super init];
    if (self)
        _outputs = [NSMutableArray array];
    return self;
}

@end

static RevenantBridgedContext *revenant_bridge(CIContext *context)
{
    @synchronized (context) {
        RevenantBridgedContext *bridge = objc_getAssociatedObject(context, &revenant_bridge_key);
        if (!bridge) {
            bridge = [RevenantBridgedContext new];
            objc_setAssociatedObject(context, &revenant_bridge_key, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return bridge;
    }
}

static CIContext *revenant_output_context(CIContext *context, EAGLContext *eagl, CGColorSpaceRef colorSpace)
{
    RevenantBridgedContext *bridge = revenant_bridge(context);
    id output = colorSpace ? (__bridge id)colorSpace : nil;
    if (!output) {
        id working = bridge.options[kCIContextWorkingColorSpace];
        if (!working)
            return nil;
        output = working;
    }
    @synchronized (bridge) {
        for (RevenantOutputContext *known in bridge.outputs) {
            if ([known.output isEqual:output])
                return known.context;
        }
        NSMutableDictionary *options = bridge.options ? [bridge.options mutableCopy] : [NSMutableDictionary dictionary];
        options[kCIContextOutputColorSpace] = output;
        CIContext *created = [CIContext contextWithEAGLContext:eagl options:options];
        if (created)
            [bridge.outputs addObject:[[RevenantOutputContext alloc] initWithOutput:output context:created]];
        return created;
    }
}

static BOOL revenant_draw(CIContext *context, CIImage *image, id<MTLTexture> texture, CGRect from, NSUInteger width, NSUInteger height, CGColorSpaceRef colorSpace)
{
    Class backing = NSClassFromString(@"RevenantMetalTexture");
    if (!backing || ![(id)texture isKindOfClass:backing] || ![(id)texture respondsToSelector:@selector(renderTarget)])
        return NO;
    id<RevenantMetalDeviceContext> device = (id<RevenantMetalDeviceContext>)texture.device;
    CIContext *drawing = revenant_output_context(context, device.context, colorSpace);
    if (!drawing)
        return NO;
    [device acquire];
    GLint framebuffer = 0, viewport[4] = {0}, box[4] = {0};
    GLfloat clear[4] = {0};
    GLboolean mask[4] = {GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE};
    GLboolean scissor = glIsEnabled(GL_SCISSOR_TEST);
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
    glGetIntegerv(GL_VIEWPORT, viewport);
    glGetIntegerv(GL_SCISSOR_BOX, box);
    glGetFloatv(GL_COLOR_CLEAR_VALUE, clear);
    glGetBooleanv(GL_COLOR_WRITEMASK, mask);
    glBindFramebuffer(GL_FRAMEBUFFER, [(id<RevenantMetalRenderTarget>)texture renderTarget]);
    BOOL complete = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
    if (complete) {
        glViewport(0, 0, (GLsizei)width, (GLsizei)height);
        glEnable(GL_SCISSOR_TEST);
        glScissor(0, 0, (GLsizei)width, (GLsizei)height);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
        [drawing drawImage:image inRect:CGRectMake(0, 0, width, height) fromRect:from];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)framebuffer);
    glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
    glScissor(box[0], box[1], box[2], box[3]);
    if (scissor)
        glEnable(GL_SCISSOR_TEST);
    else
        glDisable(GL_SCISSOR_TEST);
    glClearColor(clear[0], clear[1], clear[2], clear[3]);
    glColorMask(mask[0], mask[1], mask[2], mask[3]);
    [device relinquish];
    return complete;
}

static BOOL revenant_ci_format(MTLPixelFormat pixelFormat, CIFormat *format, NSUInteger *bytesPerPixel)
{
    switch (pixelFormat) {
        case MTLPixelFormatBGRA8Unorm:
            *format = kCIFormatBGRA8;
            *bytesPerPixel = 4;
            return YES;
        case MTLPixelFormatRGBA8Unorm:
            *format = kCIFormatRGBA8;
            *bytesPerPixel = 4;
            return YES;
        case MTLPixelFormatRGBA16Float:
            *format = kCIFormatRGBAh;
            *bytesPerPixel = 8;
            return YES;
        case MTLPixelFormatRGBA32Float:
            if (&kCIFormatRGBAf == NULL)
                return NO;
            *format = kCIFormatRGBAf;
            *bytesPerPixel = 16;
            return YES;
        default:
            return NO;
    }
}

@implementation CIContext (RevenantMetal)

+ (CIContext *)contextWithMTLDevice:(id<MTLDevice>)device
{
    return [self contextWithMTLDevice:device options:nil];
}

+ (CIContext *)contextWithMTLDevice:(id<MTLDevice>)device options:(NSDictionary<CIContextOption, id> *)options
{
    Class backing = NSClassFromString(@"RevenantMetalDevice");
    if (!backing || ![(id)device isKindOfClass:backing])
        return nil;
    EAGLContext *context = [(id<RevenantMetalDeviceContext>)device context];
    CIContext *created = context ? [self contextWithEAGLContext:context options:options] : nil;
    if (created)
        revenant_bridge(created).options = options;
    return created;
}

+ (CIContext *)contextWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue
{
    return [self contextWithMTLDevice:commandQueue.device options:nil];
}

+ (CIContext *)contextWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue options:(NSDictionary<CIContextOption, id> *)options
{
    return [self contextWithMTLDevice:commandQueue.device options:options];
}

- (void)render:(CIImage *)image toMTLTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer bounds:(CGRect)bounds colorSpace:(CGColorSpaceRef)colorSpace
{
    CIFormat format;
    NSUInteger bytesPerPixel;
    if (!image || !texture || texture.textureType != MTLTextureType2D || !revenant_ci_format(texture.pixelFormat, &format, &bytesPerPixel))
        return;
    if (CGRectIsNull(bounds) || CGRectIsInfinite(bounds))
        return;
    NSUInteger width = MIN(texture.width, (NSUInteger)MAX(0, floor(bounds.size.width)));
    NSUInteger height = MIN(texture.height, (NSUInteger)MAX(0, floor(bounds.size.height)));
    if (width == 0 || height == 0)
        return;
    if (revenant_draw(self, image, texture, CGRectMake(bounds.origin.x, bounds.origin.y, width, height), width, height, colorSpace))
        return;
    CGAffineTransform toBottomRowFirst = CGAffineTransformConcat(CGAffineTransformMakeTranslation(-bounds.origin.x, -bounds.origin.y), CGAffineTransformMake(1, 0, 0, -1, 0, (CGFloat)height));
    NSUInteger rowBytes = width * bytesPerPixel;
    NSMutableData *pixels = [NSMutableData dataWithLength:rowBytes * height];
    [self render:[image imageByApplyingTransform:toBottomRowFirst] toBitmap:pixels.mutableBytes rowBytes:(NSInteger)rowBytes bounds:CGRectMake(0, 0, width, height) format:format colorSpace:colorSpace];
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:pixels.bytes bytesPerRow:rowBytes];
}

@end
