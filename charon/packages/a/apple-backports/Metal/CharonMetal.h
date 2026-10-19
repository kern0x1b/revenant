#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#include "../air2cpu-abi.h"

@class CharonMetalTexture;
@class CharonMetalSampler;
@class CharonMetalHeap;

typedef struct {
    GLenum type;
    GLint size;
    GLboolean normalized;
    NSUInteger bytes;
    BOOL floating;
} CharonVertexFormat;

BOOL CharonMetalVertexFormat(MTLVertexFormat format, CharonVertexFormat *out);
void CharonMetalDecodeVertex(MTLVertexFormat format, const uint8_t *bytes, GLfloat out[4]);

@interface MTLFunctionConstantValues (CharonValues)
- (NSDictionary *)valueAtIndex:(NSUInteger)index name:(NSString *)name;
@end

enum { CharonScalarFloat, CharonScalarHalf, CharonScalarI32, CharonScalarI16, CharonScalarI8 };

typedef struct {
    GLint location;
    unsigned buffer;
    NSUInteger offset;
    NSUInteger instanceStride;
    int scalar;
    int components;
} CharonUniformPlan;

typedef struct {
    GLint location;
    unsigned buffer;
    NSUInteger offset;
    NSUInteger stride;
    GLenum type;
    int components;
} CharonAttributePlan;

typedef struct {
    GLint location;
    MTLVertexFormat format;
    CharonVertexFormat decoded;
    unsigned buffer;
    NSUInteger offset;
    NSUInteger stride;
    NSUInteger stepRate;
    MTLVertexStepFunction step;
} CharonInputPlan;

typedef struct {
    GLint location;
    unsigned unit;
    BOOL depth;
    BOOL compare;
} CharonTexturePlan;

typedef struct {
    GLint location;
    unsigned unit;
} CharonSizePlan;

typedef struct {
    GLint location;
    unsigned attachment;
    unsigned unit;
} CharonFetchPlan;

typedef struct {
    BOOL blending;
    GLenum sourceRGB, destinationRGB, sourceAlpha, destinationAlpha, equationRGB, equationAlpha;
    GLboolean mask[4];
} CharonBlend;

typedef struct {
    GLuint program;
    GLint flip;
    GLint instance;
    GLint target;
    GLint vertexId;
    CharonUniformPlan *vertexUniforms;
    unsigned vertexUniformCount;
    CharonUniformPlan *fragmentUniforms;
    unsigned fragmentUniformCount;
    CharonAttributePlan *attributes;
    unsigned attributeCount;
    CharonInputPlan *inputs;
    unsigned inputCount;
    CharonTexturePlan *textures;
    unsigned textureCount;
    CharonSizePlan *sizes;
    unsigned sizeCount;
    BOOL blending;
    GLenum sourceRGB, destinationRGB, sourceAlpha, destinationAlpha, equationRGB, equationAlpha;
    GLboolean mask[4];
    unsigned outputCount;
    unsigned outputIndex[4];
    GLint output;
    CharonFetchPlan *fetches;
    unsigned fetchCount;
    CharonBlend blends[4];
} CharonPlan;


@interface CharonMetalDevice : NSObject <MTLDevice>
@property (nonatomic, readonly) EAGLContext *context;
+ (CharonMetalDevice *)shared;
- (void)acquire;
- (void)relinquish;
@end

@interface CharonMetalBuffer : NSObject <MTLBuffer>
@property (nonatomic, readonly) void *bytes;
@property (nonatomic, readonly) NSUInteger length;
- (instancetype)initWithLength:(NSUInteger)length bytes:(const void *)bytes;
- (instancetype)initWithHeap:(CharonMetalHeap *)heap offset:(NSUInteger)offset length:(NSUInteger)length;
@end

@interface CharonMetalTexture : NSObject <MTLTexture>
@property (nonatomic, readonly) GLuint name;
@property (nonatomic, readonly) GLuint framebuffer;
@property (nonatomic, readonly) BOOL screen;
@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
- (instancetype)initWithDescriptor:(MTLTextureDescriptor *)descriptor;
- (instancetype)initScreenWithFramebuffer:(GLuint)framebuffer width:(NSUInteger)width height:(NSUInteger)height pixelFormat:(MTLPixelFormat)format;
- (GLuint)renderTarget;
@property (nonatomic, readonly) int attachmentKind;
@property (nonatomic, readonly) GLuint renderbuffer;
@property (nonatomic) GLuint checkedDepth;
@property (nonatomic) GLuint checkedStencil;
@property (nonatomic, unsafe_unretained) CharonMetalSampler *appliedSampler;
@property (nonatomic) int appliedCompare;
- (BOOL)charonReadRegion:(MTLRegion)region level:(NSUInteger)level bytesPerRow:(NSUInteger)bytesPerRow into:(void *)pointer;
- (BOOL)charonWriteRegion:(MTLRegion)region level:(NSUInteger)level bytes:(const void *)pointer bytesPerRow:(NSUInteger)bytesPerRow;
- (BOOL)charonGenerateMipmaps;
- (BOOL)charonIsColour;
- (BOOL)charonCanFilter;
- (NSUInteger)charonChannels;
- (NSUInteger)charonStorageSize;
- (void)charonSetHeap:(CharonMetalHeap *)heap offset:(NSUInteger)offset;
@end

extern const NSUInteger CharonMetalHeapAlignment;

@interface CharonMetalHeap : NSObject <MTLHeap>
- (instancetype)initWithDescriptor:(MTLHeapDescriptor *)descriptor error:(NSError **)error;
- (void *)charonBytesAtOffset:(NSUInteger)offset;
- (BOOL)charonReserve:(NSUInteger)length atOffset:(NSUInteger *)offset error:(NSError **)error;
- (BOOL)charonPlace:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error;
- (NSUInteger)charonAligned:(NSUInteger)offset;
- (void)charonDidAllocate:(NSUInteger)length;
- (NSUInteger)charonAllocated;
- (MTLHeapType)charonType;
- (MTLHazardTrackingMode)charonHazardTracking;
- (MTLStorageMode)charonStorageMode;
@end

@interface CharonMetalSampler : NSObject <MTLSamplerState>
@property (nonatomic, readonly) GLint minFilter;
@property (nonatomic, readonly) GLint magFilter;
@property (nonatomic, readonly) GLint wrapS;
@property (nonatomic, readonly) GLint wrapT;
@property (nonatomic, readonly) GLenum compareFunction;
- (instancetype)initWithDescriptor:(MTLSamplerDescriptor *)descriptor;
@end

@interface CharonMetalFunction : NSObject <MTLFunction>
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *stage;
@property (nonatomic, readonly) NSString *source;
@property (nonatomic, readonly) NSDictionary *reflection;
- (instancetype)initWithName:(NSString *)name stage:(NSString *)stage source:(NSString *)source reflection:(NSDictionary *)reflection;
- (CharonMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values error:(NSError **)error;
- (CharonMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values name:(NSString *)name options:(MTLFunctionOptions)options error:(NSError **)error;
@end

@interface CharonMetalLibrary : NSObject <MTLLibrary>
- (instancetype)initWithFolder:(NSString *)folder error:(NSError **)error;
- (NSString *)charonInstallName;
- (id<MTLFunction>)charonFunctionNamed:(NSString *)name specializedName:(NSString *)specializedName options:(MTLFunctionOptions)options constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error;
@end

@interface CharonMetalPipeline : NSObject <MTLRenderPipelineState>
@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) NSDictionary *vertexReflection;
@property (nonatomic, readonly) NSDictionary *fragmentReflection;
@property (nonatomic, readonly) MTLRenderPipelineDescriptor *descriptor;
- (instancetype)initWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error;
- (GLint)locationForName:(NSString *)name;
- (GLint)attributeForName:(NSString *)name;
- (const CharonPlan *)plan;
@end

@interface CharonMetalComputePipeline : NSObject <MTLComputePipelineState>
- (instancetype)initWithFunction:(id<MTLFunction>)function error:(NSError **)error;
- (void *)charonKernelFunction;
- (uint32_t)charonBlockBytes;
- (uint32_t)charonThreads;
- (void)charonSetThreads:(uint32_t)threads;
- (void)charonSetBlockBytes:(uint32_t)bytes;
- (NSString *)kernelName;
@end

@interface CharonMetalComputeEncoder : NSObject <MTLComputeCommandEncoder>
@end

@interface CharonMetalQueue : NSObject <MTLCommandQueue>
- (id<MTLCommandBuffer>)charonCommandBufferRetainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options;
@end

@interface CharonMetalCommandBuffer : NSObject <MTLCommandBuffer>
- (instancetype)initWithQueue:(CharonMetalQueue *)queue retainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options;
- (MTLCommandBufferErrorOption)charonErrorOptions;
- (CFTimeInterval)charonStartTime;
- (CFTimeInterval)charonEndTime;
- (void)charonPushDebugGroup:(NSString *)name;
- (void)charonPopDebugGroup;
@end

@interface CharonMetalEncoder : NSObject <MTLRenderCommandEncoder>
- (instancetype)initWithDescriptor:(MTLRenderPassDescriptor *)descriptor;
- (void)charonUseHeaps:(id<MTLHeap> const *)heaps count:(NSUInteger)count;
- (void)charonCheckHeapOf:(id)resource what:(const char *)what;
- (NSString *)charonHeapNames;
@end

@interface CharonMetalDrawable : NSObject <CAMetalDrawable>
- (instancetype)initWithTexture:(CharonMetalTexture *)texture layer:(CAMetalLayer *)layer context:(EAGLContext *)context;
@end

@interface CharonMetalBlitEncoder : NSObject <MTLBlitCommandEncoder>
- (uint64_t)charonEncodedCount;
- (BOOL)charonBlitTexture:(CharonMetalTexture *)source from:(MTLRegion)from level:(NSUInteger)sourceLevel
                      to:(CharonMetalTexture *)destination region:(MTLRegion)to level:(NSUInteger)destinationLevel;
@end

@interface CharonMetalEventState : NSObject
- (uint64_t)signaledValue;
- (void)setSignaledValue:(uint64_t)value;
- (void)waitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds;
- (void)notifyValue:(uint64_t)value queue:(dispatch_queue_t)queue block:(MTLSharedEventNotificationBlock)block;
@end

@interface CharonMetalSharedEvent : NSObject <MTLSharedEvent>
@property (nonatomic, readonly) CharonMetalEventState *state;
- (BOOL)charonWaitForValue:(uint64_t)value;
- (BOOL)charonWaitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds;
+ (instancetype)charonEventWithState:(CharonMetalEventState *)state;
@end



typedef struct {
    GLenum function, failure, depthFailure, pass;
    uint32_t readMask, writeMask;
} CharonStencil;

typedef struct {
    GLenum depthFunction;
    GLboolean depthWrite;
    BOOL stencilEnabled;
    CharonStencil front, back;
} CharonDepthStencil;

@interface CharonMetalDepthStencil : NSObject <MTLDepthStencilState>
- (instancetype)initWithDescriptor:(MTLDepthStencilDescriptor *)descriptor;
- (const CharonDepthStencil *)state;
@end

@interface CharonMetalLogContainer : NSObject <MTLLogContainer>
{
    NSMutableArray *_logs;
}
- (NSArray<id<MTLFunctionLog>> *)logs;
- (void)addLog:(id<MTLFunctionLog>)log;
@end

extern NSUInteger CharonMetalBindEpoch;

extern NSString *const CharonMetalErrorDomain;
NSError *CharonMetalError(NSInteger code, NSString *message);
id<CAMetalDrawable> CharonMetalNextDrawable(CAMetalLayer *layer);
