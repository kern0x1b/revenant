#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wobjc-method-access"
#pragma clang diagnostic ignored "-Wnonnull"

extern CGImageRef UIGetScreenImage(void);

static NSString *const results_folder = @"/private/var/backports";

typedef struct { float position[2]; float texture[2]; } Corner;

@interface Delegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLLibrary> library;
@end

static BOOL comes_from_backports(Class cls)
{
    Dl_info info;
    return cls && dladdr((__bridge void *)cls, &info) != 0 && [@(info.dli_fname).lastPathComponent isEqualToString:@"libMetalBackports.dylib"];
}

@implementation Delegate

- (id<MTLRenderPipelineState>)pipelineBlending:(BOOL)blending
{
    MTLRenderPipelineDescriptor *d = [[MTLRenderPipelineDescriptor alloc] init];
    d.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
    d.fragmentFunction = [self.library newFunctionWithName:@"quadFragment"];
    d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    if (blending) {
        d.colorAttachments[0].blendingEnabled = YES;
        d.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        d.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    }
    NSError *error = nil;
    id<MTLRenderPipelineState> state = [self.device newRenderPipelineStateWithDescriptor:d error:&error];
    CHECK(state != nil, blending ? "a blending pipeline is made" : "a pipeline is made");
    return state;
}

- (void)draw:(id<MTLTexture>)target pipeline:(id<MTLRenderPipelineState>)pipeline tint:(const float *)tint indexed:(BOOL)indexed clear:(MTLClearColor)clear picture:(id<MTLTexture>)picture
{
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = clear;
    MTLSamplerDescriptor *sd = [[MTLSamplerDescriptor alloc] init];
    sd.minFilter = MTLSamplerMinMagFilterNearest;
    sd.magFilter = MTLSamplerMinMagFilterNearest;
    id<MTLSamplerState> nearest = [self.device newSamplerStateWithDescriptor:sd];
    id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    Corner corners[6] = {
        {{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}},
        {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
    Corner four[4] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, -1}, {1, 1}}};
    uint16_t indices[6] = {0, 1, 2, 1, 3, 2};
    float scale = 1;
    [encoder setRenderPipelineState:pipeline];
    if (indexed)
        [encoder setVertexBytes:four length:sizeof four atIndex:0];
    else
        [encoder setVertexBytes:corners length:sizeof corners atIndex:0];
    [encoder setVertexBytes:&scale length:sizeof scale atIndex:1];
    [encoder setFragmentTexture:picture atIndex:0];
    [encoder setFragmentSamplerState:nearest atIndex:0];
    [encoder setFragmentBytes:tint length:16 atIndex:0];
    if (indexed) {
        id<MTLBuffer> index = [self.device newBufferWithBytes:indices length:sizeof indices options:0];
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:index indexBufferOffset:0];
    } else {
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    }
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
}

- (MTLVertexDescriptor *)stagedDescriptor
{
    MTLVertexDescriptor *v = [MTLVertexDescriptor vertexDescriptor];
    v.attributes[0].format = MTLVertexFormatFloat2;
    v.attributes[0].offset = 0;
    v.attributes[0].bufferIndex = 0;
    v.attributes[1].format = MTLVertexFormatFloat2;
    v.attributes[1].offset = 8;
    v.attributes[1].bufferIndex = 0;
    v.attributes[2].format = MTLVertexFormatFloat4;
    v.attributes[2].offset = 16;
    v.attributes[2].bufferIndex = 0;
    v.layouts[0].stride = 32;
    return v;
}

- (id<MTLRenderPipelineState>)stagedPipeline:(MTLVertexDescriptor *)descriptor error:(NSError **)error
{
    MTLRenderPipelineDescriptor *d = [[MTLRenderPipelineDescriptor alloc] init];
    d.vertexFunction = [self.library newFunctionWithName:@"stageInVertex"];
    d.fragmentFunction = [self.library newFunctionWithName:@"quadFragment"];
    d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    d.vertexDescriptor = descriptor;
    return [self.device newRenderPipelineStateWithDescriptor:d error:error];
}

- (void)drawStaged:(id<MTLTexture>)target pipeline:(id<MTLRenderPipelineState>)pipeline instances:(NSUInteger)instances picture:(id<MTLTexture>)picture
{
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    MTLSamplerDescriptor *sd = [[MTLSamplerDescriptor alloc] init];
    sd.minFilter = MTLSamplerMinMagFilterNearest;
    sd.magFilter = MTLSamplerMinMagFilterNearest;
    float vertices[6][8] = {
        {-1, 1, 0, 0, 1, 0, 0, 1}, {1, 1, 1, 0, 0, 1, 0, 1}, {-1, -1, 0, 1, 0, 0, 1, 1},
        {1, 1, 1, 0, 0, 1, 0, 1}, {1, -1, 1, 1, 1, 1, 1, 1}, {-1, -1, 0, 1, 0, 0, 1, 1}};
    float scale = 1;
    const float white[4] = {1, 1, 1, 1};
    id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    [encoder setVertexBytes:vertices length:sizeof vertices atIndex:0];
    [encoder setVertexBytes:&scale length:sizeof scale atIndex:1];
    [encoder setFragmentTexture:picture atIndex:0];
    [encoder setFragmentSamplerState:[self.device newSamplerStateWithDescriptor:sd] atIndex:0];
    [encoder setFragmentBytes:white length:16 atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:instances];
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
}

- (int)centerOfFragment:(id<MTLFunction>)fragment into:(id<MTLTexture>)target
{
    MTLRenderPipelineDescriptor *d = [[MTLRenderPipelineDescriptor alloc] init];
    d.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
    d.fragmentFunction = fragment;
    d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    NSError *error = nil;
    id<MTLRenderPipelineState> state = [self.device newRenderPipelineStateWithDescriptor:d error:&error];
    if (!state)
        return -1;
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    Corner quad[6] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
    float unit = 1;
    id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:state];
    [encoder setVertexBytes:quad length:sizeof quad atIndex:0];
    [encoder setVertexBytes:&unit length:sizeof unit atIndex:1];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
    uint8_t pixel[4];
    [target getBytes:pixel bytesPerRow:4 fromRegion:MTLRegionMake2D(32, 32, 1, 1) mipmapLevel:0];
    return pixel[0];
}

- (void)read:(id<MTLTexture>)texture width:(NSUInteger)w height:(NSUInteger)h into:(uint8_t *)out
{
    [texture getBytes:out bytesPerRow:w * 4 fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];
}

static void screen_pixel(CGImageRef image, CGFloat x, CGFloat y, uint8_t out[4])
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(out, 1, 1, 8, 4, rgb, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(context, -x, -(CGFloat)CGImageGetHeight(image) + y + 1);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    CGContextRelease(context);
    CGColorSpaceRelease(rgb);
}

static BOOL near(const uint8_t *p, int r, int g, int b, int tolerance)
{
    return abs(p[0] - r) <= tolerance && abs(p[1] - g) <= tolerance && abs(p[2] - b) <= tolerance;
}

- (void)runAndFinish
{
    CHECK(comes_from_backports(NSClassFromString(@"MTLTextureDescriptor")), "the texture descriptor comes from the backports");
    CHECK(comes_from_backports(NSClassFromString(@"MTLRenderPassDescriptor")), "the render pass descriptor comes from the backports");
    CHECK(comes_from_backports(NSClassFromString(@"MTLRenderPipelineDescriptor")), "the render pipeline descriptor comes from the backports");
    CHECK(comes_from_backports(NSClassFromString(@"MTLSamplerDescriptor")), "the sampler descriptor comes from the backports");
    CHECK(NSClassFromString(@"MTKView") == Nil, "MetalKit is not there");

    self.device = MTLCreateSystemDefaultDevice();
    CHECK(self.device != nil, "there is a default device");
    CHECK(MTLCreateSystemDefaultDevice() == self.device, "and it is the same the second time");
    CHECK(self.device.name.length > 0, "it has a name");
    CHECK(![self.device supportsFamily:MTLGPUFamilyApple1], "it supports no family");
    CHECK(![self.device supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily1_v1], "and no feature set");
    self.queue = [self.device newCommandQueue];
    CHECK(self.queue != nil, "it makes a command queue");

    NSString *folder = [[NSBundle mainBundle] pathForResource:@"quad" ofType:@"metallib.es2"];
    CHECK(folder != nil, "the translated library is in the bundle");
    NSError *error = nil;
    self.library = [self.device newLibraryWithFile:[folder stringByDeletingPathExtension] error:&error];
    CHECK(self.library != nil, "a library is read from beside its file");
    CHECK([[[self.library functionNames] sortedArrayUsingSelector:@selector(compare:)] isEqualToArray:(@[@"colorFragment", @"constFragment", @"depthRead", @"depthVertex", @"fetchFragment", @"flowFragment", @"maskMerge", @"maskShape", @"pairFragment", @"quadFragment", @"quadVertex", @"shadowCompare", @"stageInVertex"])], "it holds its thirteen functions");
    CHECK([self.library newFunctionWithName:@"missing"] == nil, "a name it does not hold gives nil");
    CHECK([[self.library newFunctionWithName:@"quadVertex"] functionType] == MTLFunctionTypeVertex, "the vertex function is a vertex function");
    CHECK([[self.library newFunctionWithName:@"quadFragment"] functionType] == MTLFunctionTypeFragment, "and the fragment function a fragment function");
    error = nil;
    CHECK([self.device newLibraryWithFile:@"/nonexistent.metallib" error:&error] == nil && error != nil, "a library that is not there is an error");
    error = nil;
    CHECK([self.device newLibraryWithSource:@"kernel void f() {}" options:nil error:&error] == nil && error != nil, "source is not compiled");
    error = nil;
    CHECK([self.device newLibraryWithData:(id)[NSData data] error:&error] == nil && error != nil, "a library in memory is an error");

    error = nil;
    MTLRenderPipelineDescriptor *incomplete = [[MTLRenderPipelineDescriptor alloc] init];
    CHECK([self.device newRenderPipelineStateWithDescriptor:incomplete error:&error] == nil && error != nil, "a pipeline with no functions is an error");
    error = nil;
    CHECK([self.device newComputePipelineStateWithFunction:[self.library newFunctionWithName:@"quadVertex"] error:&error] == nil && error != nil, "a compute pipeline is an error");
    CHECK(NSClassFromString(@"MTLDepthStencilDescriptor") != Nil, "the depth and stencil descriptor is there");
    MTLSamplerDescriptor *border = [[MTLSamplerDescriptor alloc] init];
    border.sAddressMode = MTLSamplerAddressModeClampToZero;
    CHECK([self.device newSamplerStateWithDescriptor:border] == nil, "a sampler that clamps to zero is nil");
    MTLTextureDescriptor *srgb = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm_sRGB width:4 height:4 mipmapped:NO];
    CHECK([self.device newTextureWithDescriptor:srgb] == nil, "an sRGB texture is nil");
    id<MTLCommandBuffer> spare = [self.queue commandBuffer];
    CHECK([spare computeCommandEncoder] == nil && [spare blitCommandEncoder] == nil, "the compute and blit encoders are nil");

    MTLTextureDescriptor *pd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:NO];
    id<MTLTexture> picture = [self.device newTextureWithDescriptor:pd];
    CHECK(picture != nil && picture.width == 2 && picture.height == 2 && picture.pixelFormat == MTLPixelFormatRGBA8Unorm, "a texture is made with its size and format");
    const uint8_t texels[16] = {255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255};
    [picture replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:texels bytesPerRow:8];

    MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO];
    td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    id<MTLTexture> target = [self.device newTextureWithDescriptor:td];
    id<MTLRenderPipelineState> plain = [self pipelineBlending:NO];
    static uint8_t out[64 * 64 * 4];
    const float white[4] = {1, 1, 1, 1};
    for (int indexed = 0; indexed < 2; indexed++) {
        [self draw:target pipeline:plain tint:white indexed:indexed clear:MTLClearColorMake(0, 0, 0, 1) picture:picture];
        [self read:target width:64 height:64 into:out];
        const uint8_t *tl = out + (16 * 64 + 16) * 4, *tr = out + (16 * 64 + 48) * 4, *bl = out + (48 * 64 + 16) * 4, *br = out + (48 * 64 + 48) * 4;
        CHECK(near(tl, 0, 0, 255, 1), indexed ? "indexed: top left is the first texel, red and blue swapped by the shader" : "arrays: top left is the first texel, red and blue swapped by the shader");
        CHECK(near(tr, 0, 255, 0, 1), indexed ? "indexed: top right is the second texel" : "arrays: top right is the second texel");
        CHECK(near(bl, 255, 0, 0, 1), indexed ? "indexed: bottom left is the third texel, swapped" : "arrays: bottom left is the third texel, swapped");
        CHECK(near(br, 255, 255, 255, 1), indexed ? "indexed: bottom right is the fourth texel" : "arrays: bottom right is the fourth texel");
    }

    NSError *staged = nil;
    CHECK([self stagedPipeline:nil error:&staged] == nil && staged != nil, "a function with inputs and no vertex descriptor is an error");
    staged = nil;
    MTLVertexDescriptor *missing = [self stagedDescriptor];
    missing.attributes[2].format = MTLVertexFormatInvalid;
    CHECK([self stagedPipeline:missing error:&staged] == nil && staged != nil, "an input with no attribute in the descriptor is an error");
    staged = nil;
    MTLVertexDescriptor *half = [self stagedDescriptor];
    half.attributes[1].format = MTLVertexFormatHalf2;
    CHECK([self stagedPipeline:half error:&staged] == nil && staged != nil, "a half float format is an error");
    staged = nil;
    MTLVertexDescriptor *rate = [self stagedDescriptor];
    rate.layouts[0].stepRate = 2;
    CHECK([self stagedPipeline:rate error:&staged] == nil && staged != nil, "a per vertex step rate other than one is an error");
    MTLVertexDescriptor *copied = [[self stagedDescriptor] copy];
    CHECK(copied.attributes[2].offset == 16 && copied.layouts[0].stride == 32, "a copy of a descriptor keeps its attributes and layouts");
    id<MTLRenderPipelineState> stagedPipeline = [self stagedPipeline:[self stagedDescriptor] error:&staged];
    CHECK(stagedPipeline != nil, "a pipeline with a vertex descriptor is made");
    [self drawStaged:target pipeline:stagedPipeline instances:1 picture:picture];
    [self read:target width:64 height:64 into:out];
    {
        const uint8_t *stl = out + (16 * 64 + 16) * 4, *str = out + (16 * 64 + 48) * 4, *sbl = out + (48 * 64 + 16) * 4, *sbr = out + (48 * 64 + 48) * 4;
        CHECK(near(stl, 0, 0, 255, 1) && near(str, 0, 255, 0, 1) && near(sbl, 255, 0, 0, 1) && near(sbr, 255, 255, 255, 1), "staged inputs draw the four texels as the buffer reads did");
    }
    [self drawStaged:target pipeline:stagedPipeline instances:2 picture:picture];
    [self read:target width:64 height:64 into:out];
    {
        const uint8_t *stl = out + (16 * 64 + 16) * 4, *sbl = out + (48 * 64 + 16) * 4;
        CHECK(near(stl, 0, 255, 0, 1) && near(sbl, 255, 255, 255, 1), "the second instance shifts the coordinate by half and is drawn over the first");
    }

    {
        MTLRenderPipelineDescriptor *fd = [[MTLRenderPipelineDescriptor alloc] init];
        fd.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
        fd.fragmentFunction = [self.library newFunctionWithName:@"flowFragment"];
        fd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        NSError *flowError = nil;
        id<MTLRenderPipelineState> flow = [self.device newRenderPipelineStateWithDescriptor:fd error:&flowError];
        CHECK(flow != nil, "a fragment function with a loop and branches is made");
        struct { int32_t n; float k; } cases[3] = {{3, 0.5f}, {12, 0.25f}, {1, 1.0f}};
        const int expected[3] = {77, 38, 51};
        const char *names[3] = {"a loop of three rounds and the branch below the threshold", "a loop of twelve rounds and the branch above it", "a loop of one round"};
        for (int c = 0; c < 3; c++) {
            MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = target;
            pass.colorAttachments[0].loadAction = MTLLoadActionClear;
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            Corner quad[6] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
            float unit = 1;
            id<MTLCommandBuffer> flowBuffer = [self.queue commandBuffer];
            id<MTLRenderCommandEncoder> flowEncoder = [flowBuffer renderCommandEncoderWithDescriptor:pass];
            [flowEncoder setRenderPipelineState:flow];
            [flowEncoder setVertexBytes:quad length:sizeof quad atIndex:0];
            [flowEncoder setVertexBytes:&unit length:sizeof unit atIndex:1];
            [flowEncoder setFragmentBytes:&cases[c] length:sizeof cases[c] atIndex:0];
            [flowEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
            [flowEncoder endEncoding];
            [flowBuffer commit];
            [flowBuffer waitUntilCompleted];
            [self read:target width:64 height:64 into:out];
            const uint8_t *middle = out + (32 * 64 + 32) * 4;
            CHECK(near(middle, expected[c], expected[c], expected[c], 2), names[c]);
        }
    }

    {
        BOOL yes = YES, no = NO;
        float gain = 0.5f;
        NSError *constantError = nil;
        MTLFunctionConstantValues *both = [[MTLFunctionConstantValues alloc] init];
        [both setConstantValue:&yes type:MTLDataTypeBool atIndex:0];
        [both setConstantValue:&gain type:MTLDataTypeFloat atIndex:1];
        id<MTLFunction> specialised = [self.library newFunctionWithName:@"constFragment" constantValues:both error:&constantError];
        CHECK(specialised != nil, "a function is specialised with its constants");
        CHECK(abs([self centerOfFragment:specialised into:target] - 128) <= 2, "a bool constant that is set and a float constant give the gain");
        MTLFunctionConstantValues *off = [[MTLFunctionConstantValues alloc] init];
        [off setConstantValue:&no type:MTLDataTypeBool withName:@"use_tint"];
        [off setConstantValue:&gain type:MTLDataTypeFloat withName:@"gain"];
        CHECK(abs([self centerOfFragment:[self.library newFunctionWithName:@"constFragment" constantValues:off error:&constantError] into:target] - 191) <= 2, "the constants are given by name, and a bool that is clear takes the other branch");
        MTLFunctionConstantValues *undefinedGain = [[MTLFunctionConstantValues alloc] init];
        [undefinedGain setConstantValue:&yes type:MTLDataTypeBool atIndex:0];
        CHECK(abs([self centerOfFragment:[self.library newFunctionWithName:@"constFragment" constantValues:undefinedGain error:&constantError] into:target] - 64) <= 2, "a constant that is not given is not defined");
        CHECK(abs([self centerOfFragment:[self.library newFunctionWithName:@"constFragment"] into:target] - 191) <= 2, "a function made with no values has none defined");
        MTLFunctionConstantValues *wrong = [[MTLFunctionConstantValues alloc] init];
        [wrong setConstantValue:&yes type:MTLDataTypeBool atIndex:1];
        constantError = nil;
        CHECK([self.library newFunctionWithName:@"constFragment" constantValues:wrong error:&constantError] == nil && constantError != nil, "a value of another type than the constant is an error");
        constantError = nil;
        CHECK([self.library newFunctionWithName:@"missing" constantValues:both error:&constantError] == nil && constantError != nil, "a function that is not there is an error with values too");
    }

    {
        MTLRenderPipelineDescriptor *fd = [[MTLRenderPipelineDescriptor alloc] init];
        fd.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
        fd.fragmentFunction = [self.library newFunctionWithName:@"fetchFragment"];
        fd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        NSError *fetchError = nil;
        id<MTLRenderPipelineState> fetch = [self.device newRenderPipelineStateWithDescriptor:fd error:&fetchError];
        CHECK(fetch != nil, "a fragment function that reads the colour attachment is made");
        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = target;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.4, 0.6, 1);
        Corner quad[6] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
        float unit = 1;
        const float red[4] = {1, 0, 0, 1};
        id<MTLCommandBuffer> fetchBuffer = [self.queue commandBuffer];
        id<MTLRenderCommandEncoder> fetchEncoder = [fetchBuffer renderCommandEncoderWithDescriptor:pass];
        [fetchEncoder setRenderPipelineState:fetch];
        [fetchEncoder setVertexBytes:quad length:sizeof quad atIndex:0];
        [fetchEncoder setVertexBytes:&unit length:sizeof unit atIndex:1];
        [fetchEncoder setFragmentBytes:red length:16 atIndex:0];
        [fetchEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [fetchEncoder endEncoding];
        [fetchBuffer commit];
        [fetchBuffer waitUntilCompleted];
        [self read:target width:64 height:64 into:out];
        CHECK(near(out + (32 * 64 + 32) * 4, 153, 51, 77, 2), "the colour attachment is read in the shader: half of what was there and half of the tint");
    }

    {
        MTLTextureDescriptor *dd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)252 width:64 height:64 mipmapped:NO];
        dd.usage = MTLTextureUsageRenderTarget;
        id<MTLTexture> depthTexture = [self.device newTextureWithDescriptor:dd];
        MTLTextureDescriptor *sd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)260 width:64 height:64 mipmapped:NO];
        sd.usage = MTLTextureUsageRenderTarget;
        id<MTLTexture> packedTexture = [self.device newTextureWithDescriptor:sd];
        MTLTextureDescriptor *only = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)253 width:64 height:64 mipmapped:NO];
        only.usage = MTLTextureUsageRenderTarget;
        id<MTLTexture> stencilOnly = [self.device newTextureWithDescriptor:only];
        CHECK(depthTexture != nil && packedTexture != nil && stencilOnly != nil, "a depth texture, a texture of depth and stencil and a stencil texture are made");
        MTLRenderPassDescriptor *fresh = [MTLRenderPassDescriptor renderPassDescriptor];
        CHECK(fresh.depthAttachment.clearDepth == 1.0 && fresh.stencilAttachment.clearStencil == 0, "a pass clears depth to one and stencil to zero to start");

        MTLRenderPipelineDescriptor *dp = [[MTLRenderPipelineDescriptor alloc] init];
        dp.vertexFunction = [self.library newFunctionWithName:@"depthVertex"];
        dp.fragmentFunction = [self.library newFunctionWithName:@"colorFragment"];
        dp.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        dp.depthAttachmentPixelFormat = (MTLPixelFormat)252;
        NSError *depthError = nil;
        id<MTLRenderPipelineState> depthPipeline = [self.device newRenderPipelineStateWithDescriptor:dp error:&depthError];
        CHECK(depthPipeline != nil, "a pipeline of the depth functions is made");

        MTLDepthStencilDescriptor *lessWrite = [[MTLDepthStencilDescriptor alloc] init];
        lessWrite.depthCompareFunction = MTLCompareFunctionLess;
        lessWrite.depthWriteEnabled = YES;
        MTLDepthStencilDescriptor *always = [[MTLDepthStencilDescriptor alloc] init];
        always.depthCompareFunction = MTLCompareFunctionAlways;
        always.depthWriteEnabled = YES;
        MTLDepthStencilDescriptor *lessOnly = [[MTLDepthStencilDescriptor alloc] init];
        lessOnly.depthCompareFunction = MTLCompareFunctionLess;
        lessOnly.depthWriteEnabled = NO;
        id<MTLDepthStencilState> lessWriteState = [self.device newDepthStencilStateWithDescriptor:lessWrite];
        id<MTLDepthStencilState> alwaysState = [self.device newDepthStencilStateWithDescriptor:always];
        id<MTLDepthStencilState> lessOnlyState = [self.device newDepthStencilStateWithDescriptor:lessOnly];
        CHECK(lessWriteState != nil && alwaysState != nil && lessOnlyState != nil, "depth and stencil states are made");

        const float red[4] = {1, 0, 0, 1}, green[4] = {0, 1, 0, 1};
        void (^quad)(id<MTLRenderCommandEncoder>, float, float, const float *) = ^(id<MTLRenderCommandEncoder> e, float z, float half, const float *color) {
            float p[6][4] = {{-half, half, z, 1}, {half, half, z, 1}, {-half, -half, z, 1}, {half, half, z, 1}, {half, -half, z, 1}, {-half, -half, z, 1}};
            float c[6][4];
            for (int i = 0; i < 6; i++)
                memcpy(c[i], color, 16);
            [e setVertexBytes:p length:sizeof p atIndex:0];
            [e setVertexBytes:c length:sizeof c atIndex:1];
            [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        };
        MTLRenderPassDescriptor *(^depthPass)(void) = ^MTLRenderPassDescriptor *{
            MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = target;
            pass.colorAttachments[0].loadAction = MTLLoadActionClear;
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            pass.depthAttachment.texture = depthTexture;
            pass.depthAttachment.loadAction = MTLLoadActionClear;
            pass.depthAttachment.clearDepth = 1.0;
            return pass;
        };
        struct { id<MTLDepthStencilState> state; float firstZ, secondZ; int expectRed; const char *name; } cases[4] = {
            {lessWriteState, 0.5f, 0.8f, 1, "the nearer quad drawn first keeps the pixel against a farther one"},
            {lessWriteState, 0.8f, 0.5f, 0, "the nearer quad drawn second takes the pixel"},
            {alwaysState, 0.5f, 0.8f, 0, "a depth test that always passes lets the later quad over"},
            {lessOnlyState, 0.5f, 0.8f, 0, "a quad drawn without writing depth leaves the depth alone"}};
        for (int k = 0; k < 4; k++) {
            id<MTLCommandBuffer> b = [self.queue commandBuffer];
            id<MTLRenderCommandEncoder> e = [b renderCommandEncoderWithDescriptor:depthPass()];
            [e setRenderPipelineState:depthPipeline];
            [e setDepthStencilState:cases[k].state];
            quad(e, cases[k].firstZ, 1.0f, red);
            quad(e, cases[k].secondZ, 1.0f, green);
            [e endEncoding];
            [b commit];
            [b waitUntilCompleted];
            [self read:target width:64 height:64 into:out];
            const uint8_t *middle = out + (32 * 64 + 32) * 4;
            CHECK(cases[k].expectRed ? near(middle, 255, 0, 0, 1) : near(middle, 0, 255, 0, 1), cases[k].name);
        }

        MTLStencilDescriptor *mark = [[MTLStencilDescriptor alloc] init];
        mark.stencilCompareFunction = MTLCompareFunctionAlways;
        mark.depthStencilPassOperation = MTLStencilOperationReplace;
        MTLDepthStencilDescriptor *marking = [[MTLDepthStencilDescriptor alloc] init];
        marking.frontFaceStencil = mark;
        marking.backFaceStencil = mark;
        MTLStencilDescriptor *equal = [[MTLStencilDescriptor alloc] init];
        equal.stencilCompareFunction = MTLCompareFunctionEqual;
        MTLDepthStencilDescriptor *masked = [[MTLDepthStencilDescriptor alloc] init];
        masked.frontFaceStencil = equal;
        masked.backFaceStencil = equal;
        id<MTLDepthStencilState> markingState = [self.device newDepthStencilStateWithDescriptor:marking];
        id<MTLDepthStencilState> maskedState = [self.device newDepthStencilStateWithDescriptor:masked];
        const float *redColor = red, *greenColor = green;
        void (^stencilRun)(id<MTLTexture>, id<MTLTexture>, const char *) = ^(id<MTLTexture> depthAttach, id<MTLTexture> stencilAttach, const char *name) {
            MTLRenderPassDescriptor *stencilPass = [MTLRenderPassDescriptor renderPassDescriptor];
            stencilPass.colorAttachments[0].texture = target;
            stencilPass.colorAttachments[0].loadAction = MTLLoadActionClear;
            stencilPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            stencilPass.depthAttachment.texture = depthAttach;
            stencilPass.depthAttachment.loadAction = MTLLoadActionClear;
            stencilPass.stencilAttachment.texture = stencilAttach;
            stencilPass.stencilAttachment.loadAction = MTLLoadActionClear;
            id<MTLCommandBuffer> sb = [self.queue commandBuffer];
            id<MTLRenderCommandEncoder> se = [sb renderCommandEncoderWithDescriptor:stencilPass];
            [se setRenderPipelineState:depthPipeline];
            [se setDepthStencilState:markingState];
            [se setStencilReferenceValue:1];
            quad(se, 0.5f, 0.5f, redColor);
            [se setDepthStencilState:maskedState];
            quad(se, 0.5f, 1.0f, greenColor);
            [se endEncoding];
            [sb commit];
            [sb waitUntilCompleted];
            [self read:target width:64 height:64 into:out];
            CHECK(near(out + (32 * 64 + 32) * 4, 0, 255, 0, 1) && near(out + (4 * 64 + 4) * 4, 0, 0, 0, 1), name);
        };
        stencilRun(packedTexture, packedTexture, "a stencil that is set where a quad was drawn lets a second quad in there only, with depth and stencil in one texture");
        stencilRun(nil, stencilOnly, "and with a texture of stencil alone");
    }

    {
        MTLRenderPipelineDescriptor *pd2 = [[MTLRenderPipelineDescriptor alloc] init];
        pd2.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
        pd2.fragmentFunction = [self.library newFunctionWithName:@"pairFragment"];
        pd2.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        pd2.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA8Unorm;
        NSError *pairError = nil;
        id<MTLRenderPipelineState> pair = [self.device newRenderPipelineStateWithDescriptor:pd2 error:&pairError];
        CHECK(pair != nil, "a fragment function that writes two render targets is made");
        MTLTextureDescriptor *td2 = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO];
        td2.usage = MTLTextureUsageRenderTarget;
        id<MTLTexture> second = [self.device newTextureWithDescriptor:td2];
        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = target;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        pass.colorAttachments[1].texture = second;
        pass.colorAttachments[1].loadAction = MTLLoadActionClear;
        pass.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 1, 1);
        Corner quad[6] = {{{-0.5f, 0.5f}, {0, 0}}, {{0.5f, 0.5f}, {1, 0}}, {{-0.5f, -0.5f}, {0, 1}}, {{0.5f, 0.5f}, {1, 0}}, {{0.5f, -0.5f}, {1, 1}}, {{-0.5f, -0.5f}, {0, 1}}};
        float unit = 1;
        const float orange[4] = {1, 0.5f, 0, 1};
        id<MTLCommandBuffer> pairBuffer = [self.queue commandBuffer];
        id<MTLRenderCommandEncoder> pairEncoder = [pairBuffer renderCommandEncoderWithDescriptor:pass];
        [pairEncoder setRenderPipelineState:pair];
        [pairEncoder setVertexBytes:quad length:sizeof quad atIndex:0];
        [pairEncoder setVertexBytes:&unit length:sizeof unit atIndex:1];
        [pairEncoder setFragmentBytes:orange length:16 atIndex:0];
        [pairEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [pairEncoder endEncoding];
        [pairBuffer commit];
        [pairBuffer waitUntilCompleted];
        [self read:target width:64 height:64 into:out];
        CHECK(near(out + (32 * 64 + 32) * 4, 255, 128, 0, 2) && near(out + (4 * 64 + 4) * 4, 0, 0, 0, 1), "the first render target has the first colour where the quad is");
        static uint8_t outSecond[64 * 64 * 4];
        [second getBytes:outSecond bytesPerRow:256 fromRegion:MTLRegionMake2D(0, 0, 64, 64) mipmapLevel:0];
        CHECK(near(outSecond + (32 * 64 + 32) * 4, 128, 64, 0, 2) && near(outSecond + (4 * 64 + 4) * 4, 0, 0, 255, 1), "and the second has the second colour there and its own clear colour outside");
    }

    {
        MTLTextureDescriptor *dd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:(MTLPixelFormat)252 width:64 height:64 mipmapped:NO];
        dd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        id<MTLTexture> shadowMap = [self.device newTextureWithDescriptor:dd];
        MTLRenderPipelineDescriptor *wp = [[MTLRenderPipelineDescriptor alloc] init];
        wp.vertexFunction = [self.library newFunctionWithName:@"depthVertex"];
        wp.fragmentFunction = [self.library newFunctionWithName:@"colorFragment"];
        wp.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        id<MTLRenderPipelineState> writer = [self.device newRenderPipelineStateWithDescriptor:wp error:NULL];
        MTLDepthStencilDescriptor *writes = [[MTLDepthStencilDescriptor alloc] init];
        writes.depthCompareFunction = MTLCompareFunctionAlways;
        writes.depthWriteEnabled = YES;
        MTLRenderPassDescriptor *depthOnly = [MTLRenderPassDescriptor renderPassDescriptor];
        depthOnly.colorAttachments[0].texture = target;
        depthOnly.colorAttachments[0].loadAction = MTLLoadActionClear;
        depthOnly.depthAttachment.texture = shadowMap;
        depthOnly.depthAttachment.loadAction = MTLLoadActionClear;
        id<MTLCommandBuffer> wb = [self.queue commandBuffer];
        id<MTLRenderCommandEncoder> we = [wb renderCommandEncoderWithDescriptor:depthOnly];
        [we setRenderPipelineState:writer];
        [we setDepthStencilState:[self.device newDepthStencilStateWithDescriptor:writes]];
        float p[6][4] = {{-1, 1, 0.5f, 1}, {1, 1, 0.5f, 1}, {-1, -1, 0.5f, 1}, {1, 1, 0.5f, 1}, {1, -1, 0.5f, 1}, {-1, -1, 0.5f, 1}};
        float c[6][4] = {{0}};
        [we setVertexBytes:p length:sizeof p atIndex:0];
        [we setVertexBytes:c length:sizeof c atIndex:1];
        [we drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [we endEncoding];
        [wb commit];
        [wb waitUntilCompleted];
        CHECK([shadowMap usage] & MTLTextureUsageShaderRead, "a depth texture that is drawn into can be read by a shader");

        MTLSamplerDescriptor *plainSampler = [[MTLSamplerDescriptor alloc] init];
        id<MTLSamplerState> nearestSampler = [self.device newSamplerStateWithDescriptor:plainSampler];
        MTLSamplerDescriptor *comparing = [[MTLSamplerDescriptor alloc] init];
        comparing.compareFunction = MTLCompareFunctionLess;
        id<MTLSamplerState> comparingSampler = [self.device newSamplerStateWithDescriptor:comparing];
        Corner quad[6] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
        float unit = 1;
        const Corner *quadPointer = quad;
        float (^readBack)(NSString *, id<MTLSamplerState>, float) = ^float(NSString *fragment, id<MTLSamplerState> sampler, float reference) {
            MTLRenderPipelineDescriptor *rp = [[MTLRenderPipelineDescriptor alloc] init];
            rp.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
            rp.fragmentFunction = [self.library newFunctionWithName:fragment];
            rp.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
            NSError *e = nil;
            id<MTLRenderPipelineState> state = [self.device newRenderPipelineStateWithDescriptor:rp error:&e];
            if (!state)
                return -1;
            MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = target;
            pass.colorAttachments[0].loadAction = MTLLoadActionClear;
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            id<MTLCommandBuffer> b = [self.queue commandBuffer];
            id<MTLRenderCommandEncoder> enc = [b renderCommandEncoderWithDescriptor:pass];
            [enc setRenderPipelineState:state];
            [enc setVertexBytes:quadPointer length:6 * sizeof(Corner) atIndex:0];
            [enc setVertexBytes:&unit length:sizeof unit atIndex:1];
            [enc setFragmentTexture:shadowMap atIndex:0];
            [enc setFragmentSamplerState:sampler atIndex:0];
            [enc setFragmentBytes:&reference length:4 atIndex:0];
            [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
            [enc endEncoding];
            [b commit];
            [b waitUntilCompleted];
            uint8_t pixel[4];
            [target getBytes:pixel bytesPerRow:4 fromRegion:MTLRegionMake2D(32, 32, 1, 1) mipmapLevel:0];
            return pixel[0];
        };
        CHECK(fabsf(readBack(@"depthRead", nearestSampler, 0) - 128) <= 2, "a shader reads the depth that was written, half of the range");
        CHECK(readBack(@"shadowCompare", comparingSampler, 0.3f) > 253, "a compared reference nearer than the depth is lit");
        CHECK(readBack(@"shadowCompare", comparingSampler, 0.7f) < 2, "and one farther than the depth is not");
    }

    {
        MTLRenderPipelineDescriptor *sp = [[MTLRenderPipelineDescriptor alloc] init];
        sp.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
        sp.fragmentFunction = [self.library newFunctionWithName:@"maskShape"];
        sp.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        sp.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA8Unorm;
        NSError *maskError = nil;
        id<MTLRenderPipelineState> shape = [self.device newRenderPipelineStateWithDescriptor:sp error:&maskError];
        MTLRenderPipelineDescriptor *mp = [[MTLRenderPipelineDescriptor alloc] init];
        mp.vertexFunction = [self.library newFunctionWithName:@"quadVertex"];
        mp.fragmentFunction = [self.library newFunctionWithName:@"maskMerge"];
        mp.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        mp.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA8Unorm;
        id<MTLRenderPipelineState> merge = [self.device newRenderPipelineStateWithDescriptor:mp error:&maskError];
        CHECK(shape != nil && merge != nil, "a function that writes the second render target and reads it, and one that reads it and writes the first, are made");
        MTLTextureDescriptor *md = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO];
        md.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        id<MTLTexture> mask = [self.device newTextureWithDescriptor:md];
        Corner quad[6] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
        float unit = 1;
        MTLRenderPassDescriptor *first = [MTLRenderPassDescriptor renderPassDescriptor];
        first.colorAttachments[0].texture = target;
        first.colorAttachments[0].loadAction = MTLLoadActionClear;
        first.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        first.colorAttachments[1].texture = mask;
        first.colorAttachments[1].loadAction = MTLLoadActionClear;
        first.colorAttachments[1].clearColor = MTLClearColorMake(0.25, 0, 0, 1);
        id<MTLCommandBuffer> mb = [self.queue commandBuffer];
        id<MTLRenderCommandEncoder> me = [mb renderCommandEncoderWithDescriptor:first];
        [me setRenderPipelineState:shape];
        [me setVertexBytes:quad length:sizeof quad atIndex:0];
        [me setVertexBytes:&unit length:sizeof unit atIndex:1];
        [me drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [me drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [me endEncoding];
        [mb commit];
        [mb waitUntilCompleted];
        uint8_t maskPixel[4];
        [mask getBytes:maskPixel bytesPerRow:4 fromRegion:MTLRegionMake2D(32, 32, 1, 1) mipmapLevel:0];
        [self read:target width:64 height:64 into:out];
        CHECK(abs(maskPixel[0] - 191) <= 2 && near(out + (32 * 64 + 32) * 4, 0, 0, 0, 1), "a function that reads and writes the second target adds to it twice and leaves the first alone");
        MTLRenderPassDescriptor *second = [MTLRenderPassDescriptor renderPassDescriptor];
        second.colorAttachments[0].texture = target;
        second.colorAttachments[0].loadAction = MTLLoadActionClear;
        second.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        second.colorAttachments[1].texture = mask;
        second.colorAttachments[1].loadAction = MTLLoadActionLoad;
        id<MTLCommandBuffer> nb = [self.queue commandBuffer];
        id<MTLRenderCommandEncoder> ne = [nb renderCommandEncoderWithDescriptor:second];
        [ne setRenderPipelineState:merge];
        [ne setVertexBytes:quad length:sizeof quad atIndex:0];
        [ne setVertexBytes:&unit length:sizeof unit atIndex:1];
        [ne drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [ne endEncoding];
        [nb commit];
        [nb waitUntilCompleted];
        [self read:target width:64 height:64 into:out];
        CHECK(near(out + (32 * 64 + 32) * 4, 191, 0, 0, 2), "a function that reads the second target and writes the first takes what the first draws left there");
    }

    const float faint[4] = {0.5f, 0.5f, 0.5f, 0.4f};
    [self draw:target pipeline:plain tint:faint indexed:NO clear:MTLClearColorMake(0, 0, 0, 1) picture:picture];
    [self read:target width:64 height:64 into:out];
    const uint8_t *tl = out + (16 * 64 + 16) * 4;
    CHECK(near(tl, 128, 0, 0, 2), "a tint below the alpha of the test is not swapped and scales the colour");
    id<MTLRenderPipelineState> blended = [self pipelineBlending:YES];
    [self draw:target pipeline:blended tint:faint indexed:NO clear:MTLClearColorMake(0, 0, 0, 1) picture:picture];
    [self read:target width:64 height:64 into:out];
    CHECK(near(tl, 51, 0, 0, 2), "blending by source alpha over the cleared colour gives the mixed colour");

    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.frame = CGRectMake(0, 0, 100, 60);
    layer.contentsScale = 1;
    CHECK([layer nextDrawable] == nil, "a layer with no device has no drawable");
    layer.device = self.device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    [self.window.rootViewController.view.layer addSublayer:layer];
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    CHECK(drawable != nil, "a layer with the device has a drawable");
    CHECK(drawable.texture.width == 100 && drawable.texture.height == 60, "its texture is the size of the layer");
    CHECK(drawable.layer == layer, "and it names its layer");
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0.5, 1);
    id<MTLCommandBuffer> frame = [self.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [frame renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    uint8_t pixel[4] = {0, 0, 0, 0};
    [drawable.texture getBytes:pixel bytesPerRow:4 fromRegion:MTLRegionMake2D(50, 30, 1, 1) mipmapLevel:0];
    [frame presentDrawable:drawable];
    [frame commit];
    [frame waitUntilCompleted];
    CHECK(abs(pixel[0] - 128) <= 1 && pixel[1] == 0 && pixel[2] == 255, "the drawable holds what the pass cleared it to, in the order of its BGRA format");
    {
        UIView *host = self.window.rootViewController.view;
        CAMetalLayer *shown = [CAMetalLayer layer];
        shown.frame = CGRectMake(20, 40, 100, 100);
        shown.contentsScale = [UIScreen mainScreen].scale;
        shown.device = self.device;
        shown.pixelFormat = MTLPixelFormatBGRA8Unorm;
        [host.layer addSublayer:shown];
        id<CAMetalDrawable> frame2 = [shown nextDrawable];
        MTLRenderPassDescriptor *shownPass = [MTLRenderPassDescriptor renderPassDescriptor];
        shownPass.colorAttachments[0].texture = frame2.texture;
        shownPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        shownPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        Corner quad[6] = {{{-1, 1}, {0, 0}}, {{1, 1}, {1, 0}}, {{-1, -1}, {0, 1}}, {{1, 1}, {1, 0}}, {{1, -1}, {1, 1}}, {{-1, -1}, {0, 1}}};
        float unit = 1;
        MTLSamplerDescriptor *sd = [[MTLSamplerDescriptor alloc] init];
        sd.minFilter = MTLSamplerMinMagFilterNearest;
        sd.magFilter = MTLSamplerMinMagFilterNearest;
        id<MTLCommandBuffer> shownBuffer = [self.queue commandBuffer];
        id<MTLRenderCommandEncoder> shownEncoder = [shownBuffer renderCommandEncoderWithDescriptor:shownPass];
        [shownEncoder setRenderPipelineState:plain];
        [shownEncoder setVertexBytes:quad length:sizeof quad atIndex:0];
        [shownEncoder setVertexBytes:&unit length:sizeof unit atIndex:1];
        [shownEncoder setFragmentTexture:picture atIndex:0];
        [shownEncoder setFragmentSamplerState:[self.device newSamplerStateWithDescriptor:sd] atIndex:0];
        [shownEncoder setFragmentBytes:white length:16 atIndex:0];
        [shownEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [shownEncoder endEncoding];
        [shownBuffer presentDrawable:frame2];
        [shownBuffer commit];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        CGImageRef screen = UIGetScreenImage();
        CGFloat scale = [UIScreen mainScreen].scale;
        CGRect rect = [self.window convertRect:shown.frame fromView:host];
        uint8_t tlp[4], trp[4], blp[4], brp[4];
        screen_pixel(screen, (rect.origin.x + 25) * scale, (rect.origin.y + 25) * scale, tlp);
        screen_pixel(screen, (rect.origin.x + 75) * scale, (rect.origin.y + 25) * scale, trp);
        screen_pixel(screen, (rect.origin.x + 25) * scale, (rect.origin.y + 75) * scale, blp);
        screen_pixel(screen, (rect.origin.x + 75) * scale, (rect.origin.y + 75) * scale, brp);
        CHECK(near(tlp, 0, 0, 255, 2) && near(trp, 0, 255, 0, 2) && near(blp, 255, 0, 0, 2) && near(brp, 255, 255, 255, 2), "the drawable is on the screen with the first texel at the top left, as Metal shows it");
    }
    id<CAMetalDrawable> second = [layer nextDrawable];
    CHECK(second != nil && second != drawable, "the next drawable is another");

    NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"metal.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"metal.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"metal.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndFinish) withObject:nil afterDelay:0.3];
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([Delegate class]));
    }
}
