#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurfaceRef.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#include "../air2cpu-abi.h"

@class RevenantMetalTexture;
@class RevenantMetalSampler;
@class RevenantMetalHeap;

typedef struct {
    GLenum type;
    GLint size;
    GLboolean normalized;
    NSUInteger bytes;
    BOOL floating;
} RevenantVertexFormat;

BOOL RevenantMetalVertexFormat(MTLVertexFormat format, RevenantVertexFormat *out);
void RevenantMetalDecodeVertex(MTLVertexFormat format, const uint8_t *bytes, GLfloat out[4]);

@interface MTLFunctionConstantValues (RevenantValues)
- (NSDictionary *)valueAtIndex:(NSUInteger)index name:(NSString *)name;
@end

enum { RevenantScalarFloat, RevenantScalarHalf, RevenantScalarI32, RevenantScalarI16, RevenantScalarI8 };

typedef struct {
    GLint location;
    unsigned buffer;
    NSUInteger offset;
    NSUInteger instanceStride;
    int scalar;
    int components;
    int columns; // 0 for a vector or a scalar; the column count of a matrix, whose components are its rows
} RevenantUniformPlan;

typedef struct {
    GLint location;
    unsigned buffer;
    NSUInteger offset;
    NSUInteger stride;
    GLenum type;
    int components;
} RevenantAttributePlan;

typedef struct {
    GLint location;
    MTLVertexFormat format;
    RevenantVertexFormat decoded;
    unsigned buffer;
    NSUInteger offset;
    NSUInteger stride;
    NSUInteger stepRate;
    MTLVertexStepFunction step;
} RevenantInputPlan;

typedef struct {
    GLint location;
    unsigned unit;
    BOOL depth;
    BOOL compare;
    BOOL constant;
    GLint minFilter;
    GLint magFilter;
    GLint wrapS;
    GLint wrapT;
} RevenantTexturePlan;

typedef struct {
    GLint location;
    unsigned unit;
    BOOL output;
} RevenantSizePlan;

typedef struct {
    GLint location;
    unsigned attachment;
    unsigned unit;
} RevenantFetchPlan;

typedef struct {
    BOOL blending;
    GLenum sourceRGB, destinationRGB, sourceAlpha, destinationAlpha, equationRGB, equationAlpha;
    GLboolean mask[4];
} RevenantBlend;

typedef struct {
    GLuint program;
    GLint flip;
    GLint instance;
    GLint target;
    GLint vertexId;
    RevenantUniformPlan *vertexUniforms;
    unsigned vertexUniformCount;
    RevenantUniformPlan *fragmentUniforms;
    unsigned fragmentUniformCount;
    RevenantAttributePlan *attributes;
    unsigned attributeCount;
    RevenantInputPlan *inputs;
    unsigned inputCount;
    RevenantTexturePlan *textures;
    unsigned textureCount;
    RevenantSizePlan *sizes;
    unsigned sizeCount;
    BOOL blending;
    GLenum sourceRGB, destinationRGB, sourceAlpha, destinationAlpha, equationRGB, equationAlpha;
    GLboolean mask[4];
    unsigned outputCount;
    unsigned outputIndex[4];
    GLint output;
    RevenantFetchPlan *fetches;
    unsigned fetchCount;
    RevenantBlend blends[4];
} RevenantPlan;


@interface RevenantMetalDevice : NSObject <MTLDevice>
@property (nonatomic, readonly) EAGLContext *context;
+ (RevenantMetalDevice *)shared;
- (void)acquire;
- (void)relinquish;
- (CVOpenGLESTextureCacheRef)textureCache;
@end

@interface RevenantMetalBuffer : NSObject <MTLBuffer>
@property (nonatomic, readonly) void *bytes;
@property (nonatomic, readonly) NSUInteger length;
- (instancetype)initWithLength:(NSUInteger)length bytes:(const void *)bytes;
- (instancetype)initWithHeap:(RevenantMetalHeap *)heap offset:(NSUInteger)offset length:(NSUInteger)length;
@end

@interface RevenantMetalTexture : NSObject <MTLTexture>
@property (nonatomic, readonly) GLuint name;
@property (nonatomic, readonly) GLuint framebuffer;
@property (nonatomic, readonly) BOOL screen;
@property (nonatomic, readonly) MTLPixelFormat pixelFormat;
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
- (instancetype)initWithDescriptor:(MTLTextureDescriptor *)descriptor;
- (instancetype)initWithDescriptor:(MTLTextureDescriptor *)descriptor iosurface:(IOSurfaceRef)iosurface plane:(NSUInteger)plane;
+ (instancetype)revenantTextureFromImage:(CVImageBufferRef)image device:(RevenantMetalDevice *)device pixelFormat:(MTLPixelFormat)pixelFormat width:(size_t)width height:(size_t)height plane:(size_t)plane status:(CVReturn *)status;
- (instancetype)initWithOpenGLESTexture:(CVOpenGLESTextureRef)texture pixelFormat:(MTLPixelFormat)pixelFormat width:(NSUInteger)width height:(NSUInteger)height usage:(MTLTextureUsage)usage;
- (CVOpenGLESTextureRef)revenantOpenGLESTexture;
- (instancetype)initScreenWithFramebuffer:(GLuint)framebuffer width:(NSUInteger)width height:(NSUInteger)height pixelFormat:(MTLPixelFormat)format;
- (GLuint)renderTarget;
@property (nonatomic, readonly) int attachmentKind;
@property (nonatomic, readonly) GLuint renderbuffer;
@property (nonatomic) GLuint checkedDepth;
@property (nonatomic) GLuint checkedStencil;
@property (nonatomic, unsafe_unretained) RevenantMetalSampler *appliedSampler;
@property (nonatomic) int appliedCompare;
- (BOOL)revenantReadRegion:(MTLRegion)region level:(NSUInteger)level bytesPerRow:(NSUInteger)bytesPerRow into:(void *)pointer;
- (BOOL)revenantWriteRegion:(MTLRegion)region level:(NSUInteger)level bytes:(const void *)pointer bytesPerRow:(NSUInteger)bytesPerRow;
- (BOOL)revenantGenerateMipmaps;
- (BOOL)revenantIsColour;
- (BOOL)revenantCanFilter;
- (NSUInteger)revenantChannels;
- (NSUInteger)revenantStorageSize;
- (void)revenantSetHeap:(RevenantMetalHeap *)heap offset:(NSUInteger)offset;
@end

extern const NSUInteger RevenantMetalHeapAlignment;

@interface RevenantMetalHeap : NSObject <MTLHeap>
- (instancetype)initWithDescriptor:(MTLHeapDescriptor *)descriptor error:(NSError **)error;
- (void *)revenantBytesAtOffset:(NSUInteger)offset;
- (BOOL)revenantReserve:(NSUInteger)length atOffset:(NSUInteger *)offset error:(NSError **)error;
- (BOOL)revenantPlace:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error;
- (NSUInteger)revenantAligned:(NSUInteger)offset;
- (void)revenantDidAllocate:(NSUInteger)length;
- (NSUInteger)revenantAllocated;
- (MTLHeapType)revenantType;
- (MTLHazardTrackingMode)revenantHazardTracking;
- (MTLStorageMode)revenantStorageMode;
@end

@interface RevenantMetalSampler : NSObject <MTLSamplerState>
@property (nonatomic, readonly) GLint minFilter;
@property (nonatomic, readonly) GLint magFilter;
@property (nonatomic, readonly) GLint wrapS;
@property (nonatomic, readonly) GLint wrapT;
@property (nonatomic, readonly) GLenum compareFunction;
- (instancetype)initWithDescriptor:(MTLSamplerDescriptor *)descriptor;
@end

@interface RevenantMetalFunction : NSObject <MTLFunction>
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *stage;
@property (nonatomic, readonly) NSString *source;
@property (nonatomic, readonly) NSDictionary *reflection;
- (instancetype)initWithName:(NSString *)name stage:(NSString *)stage source:(NSString *)source reflection:(NSDictionary *)reflection;
- (RevenantMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values error:(NSError **)error;
- (RevenantMetalFunction *)specializedWith:(MTLFunctionConstantValues *)values name:(NSString *)name options:(MTLFunctionOptions)options error:(NSError **)error;
@end

@interface RevenantMetalLibrary : NSObject <MTLLibrary>
- (instancetype)initWithFolder:(NSString *)folder error:(NSError **)error;
- (NSString *)revenantInstallName;
- (id<MTLFunction>)revenantFunctionNamed:(NSString *)name specializedName:(NSString *)specializedName options:(MTLFunctionOptions)options constantValues:(MTLFunctionConstantValues *)constantValues error:(NSError **)error;
@end

@interface RevenantMetalPipeline : NSObject <MTLRenderPipelineState>
@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) NSDictionary *vertexReflection;
@property (nonatomic, readonly) NSDictionary *fragmentReflection;
@property (nonatomic, readonly) MTLRenderPipelineDescriptor *descriptor;
- (instancetype)initWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error;
+ (instancetype)fullscreenWithFragment:(RevenantMetalFunction *)fragment error:(NSError **)error;
- (GLint)locationForName:(NSString *)name;
- (GLint)attributeForName:(NSString *)name;
- (const RevenantPlan *)plan;
@end

@interface RevenantMetalComputePipeline : NSObject <MTLComputePipelineState>
- (instancetype)initWithFunction:(id<MTLFunction>)function error:(NSError **)error;
- (void *)revenantKernelFunction;
- (uint32_t)revenantBlockBytes;
- (uint32_t)revenantThreads;
- (void)revenantSetThreads:(uint32_t)threads;
- (void)revenantSetBlockBytes:(uint32_t)bytes;
- (NSString *)kernelName;
- (RevenantMetalFunction *)revenantTranslatedFunction;
- (RevenantMetalPipeline *)revenantRenderPipeline;
- (void)revenantAnnounceCPURoute;
@end

@interface RevenantMetalComputeEncoder : NSObject <MTLComputeCommandEncoder>
@end

@interface RevenantMetalQueue : NSObject <MTLCommandQueue>
- (id<MTLCommandBuffer>)revenantCommandBufferRetainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options;
@end

@interface RevenantMetalCommandBuffer : NSObject <MTLCommandBuffer>
- (instancetype)initWithQueue:(RevenantMetalQueue *)queue retainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options;
- (MTLCommandBufferErrorOption)revenantErrorOptions;
- (CFTimeInterval)revenantStartTime;
- (CFTimeInterval)revenantEndTime;
- (void)revenantPushDebugGroup:(NSString *)name;
- (void)revenantPopDebugGroup;
@end

@interface RevenantMetalEncoder : NSObject <MTLRenderCommandEncoder>
- (instancetype)initWithDescriptor:(MTLRenderPassDescriptor *)descriptor;
- (void)revenantUseHeaps:(id<MTLHeap> const *)heaps count:(NSUInteger)count;
- (void)revenantCheckHeapOf:(id)resource what:(const char *)what;
- (NSString *)revenantHeapNames;
@end

@interface RevenantMetalDrawable : NSObject <CAMetalDrawable>
- (instancetype)initWithTexture:(RevenantMetalTexture *)texture layer:(CAMetalLayer *)layer context:(EAGLContext *)context;
@end

@interface RevenantMetalBlitEncoder : NSObject <MTLBlitCommandEncoder>
- (uint64_t)revenantEncodedCount;
- (BOOL)revenantBlitTexture:(RevenantMetalTexture *)source from:(MTLRegion)from level:(NSUInteger)sourceLevel
                      to:(RevenantMetalTexture *)destination region:(MTLRegion)to level:(NSUInteger)destinationLevel;
@end

@interface RevenantMetalEventState : NSObject
- (uint64_t)signaledValue;
- (void)setSignaledValue:(uint64_t)value;
- (void)waitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds;
- (void)notifyValue:(uint64_t)value queue:(dispatch_queue_t)queue block:(MTLSharedEventNotificationBlock)block;
@end

@interface RevenantMetalSharedEvent : NSObject <MTLSharedEvent>
@property (nonatomic, readonly) RevenantMetalEventState *state;
- (BOOL)revenantWaitForValue:(uint64_t)value;
- (BOOL)revenantWaitForValue:(uint64_t)value timeout:(NSTimeInterval)seconds;
+ (instancetype)revenantEventWithState:(RevenantMetalEventState *)state;
@end



typedef struct {
    GLenum function, failure, depthFailure, pass;
    uint32_t readMask, writeMask;
} RevenantStencil;

typedef struct {
    GLenum depthFunction;
    GLboolean depthWrite;
    BOOL stencilEnabled;
    RevenantStencil front, back;
} RevenantDepthStencil;

@interface RevenantMetalDepthStencil : NSObject <MTLDepthStencilState>
- (instancetype)initWithDescriptor:(MTLDepthStencilDescriptor *)descriptor;
- (const RevenantDepthStencil *)state;
@end

@interface RevenantMetalLogContainer : NSObject <MTLLogContainer>
{
    NSMutableArray *_logs;
}
- (NSArray<id<MTLFunctionLog>> *)logs;
- (void)addLog:(id<MTLFunctionLog>)log;
@end

extern NSUInteger RevenantMetalBindEpoch;

extern NSString *const RevenantMetalErrorDomain;
NSError *RevenantMetalError(NSInteger code, NSString *message);
id<CAMetalDrawable> RevenantMetalNextDrawable(CAMetalLayer *layer);
BOOL RevenantMetalDeviceHasExtension(const char *required);
