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
// The heap a buffer of a heap is a view into, and the offset inside it. The buffer holds the heap, so
// the arena outlives every resource that is a view into it. -heap and -heapOffset are MTLResource's
// own properties: the buffer answers those, of the SDK's own declaration, and does not declare a
// second one of the same name.
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
// The internal surface a blit encoder copies through: a region of one mip level read or written with
// the texture's own channel count, whatever the driver hands back for a read.
- (BOOL)charonReadRegion:(MTLRegion)region level:(NSUInteger)level bytesPerRow:(NSUInteger)bytesPerRow into:(void *)pointer;
- (BOOL)charonWriteRegion:(MTLRegion)region level:(NSUInteger)level bytes:(const void *)pointer bytesPerRow:(NSUInteger)bytesPerRow;
- (BOOL)charonGenerateMipmaps;
- (BOOL)charonIsColour;
- (BOOL)charonCanFilter;
- (NSUInteger)charonChannels;
- (NSUInteger)charonStorageSize;
// The heap a texture of a heap was taken out of, and the offset inside it, and the setter the heap
// uses. -heap and -heapOffset are MTLResource's own properties and are answered as the SDK declares
// them; this is how the heap records where it put the texture.
- (void)charonSetHeap:(CharonMetalHeap *)heap offset:(NSUInteger)offset;
@end

// A heap of the port is one allocation resources are taken out of, the way a heap is on any Metal
// device: a buffer from a heap is a view into that allocation and a texture from a heap takes its
// size out of it, so `usedSize`, `currentAllocatedSize`, `maxAvailableSizeWithAlignment:` and an
// explicit offset all mean what the header says they mean. facts/Metal/Heaps.md is the whole of it.
// Apple's documented alignment of a heap allocation: MTLHeapAlignment is 256 bytes in Apple's Metal
// documentation (Metal Resource Allocation, "heap" alignment), which is where this number comes from
// and not from a measurement of this device - the SGX 543 has no heaps. Nothing an application can
// observe here depends on the exact value beyond the offsets it asks for, because 256 is also a
// multiple of 16, the largest alignment an ARMv7 allocation needs.
extern const NSUInteger CharonMetalHeapAlignment;

@interface CharonMetalHeap : NSObject <MTLHeap>
- (instancetype)initWithDescriptor:(MTLHeapDescriptor *)descriptor error:(NSError **)error;
- (void *)charonBytesAtOffset:(NSUInteger)offset;
- (BOOL)charonReserve:(NSUInteger)length atOffset:(NSUInteger *)offset error:(NSError **)error;
- (BOOL)charonPlace:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error;
- (NSUInteger)charonAligned:(NSUInteger)offset;
- (void)charonDidAllocate:(NSUInteger)length;
// What the heap recorded, for the members of 11.0 and 13.0 that live in their own files.
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

// A compute pipeline of the port is a translated kernel and the threadgrid it wants, found in the
// image that was loaded; a compute encoder runs a workgroup as one thread per thread of the group,
// with a rendezvous of a mutex and a condition variable because iOS 6 has no pthread_barrier.
// facts/Metal/Compute.md is the whole of it.
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
// The command buffer the queue's factories vend, with the two settings the descriptor and the
// unretained factory choose; the release files that name a factory call it.
- (id<MTLCommandBuffer>)charonCommandBufferRetainingReferences:(BOOL)retaining errorOptions:(MTLCommandBufferErrorOption)options;
@end

// The command buffer of the port. Its times are 0 until it has completed, as Metal's are; the release
// files that name a property read them through these accessors, since a category cannot add the
// buffer's own state.
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
// The heaps -useHeap: and -useHeaps:count: name, and the check a bind makes against them. Metal
// leaves undefined what happens when a resource that did not come from one of them is bound, so the
// port says which resource it was rather than passing it by.
- (void)charonUseHeaps:(id<MTLHeap> const *)heaps count:(NSUInteger)count;
- (void)charonCheckHeapOf:(id)resource what:(const char *)what;
- (NSString *)charonHeapNames;
@end

@interface CharonMetalDrawable : NSObject <CAMetalDrawable>
- (instancetype)initWithTexture:(CharonMetalTexture *)texture layer:(CAMetalLayer *)layer context:(EAGLContext *)context;
@end

// A blit is a copy, and a copy on this device is a copy on the CPU between the bytes of a buffer and
// the pixels of a texture: the port's resources are all CPU-resident, so no transfer is ever staged.
@interface CharonMetalBlitEncoder : NSObject <MTLBlitCommandEncoder>
- (uint64_t)charonEncodedCount;
- (BOOL)charonBlitTexture:(CharonMetalTexture *)source from:(MTLRegion)from level:(NSUInteger)sourceLevel
                      to:(CharonMetalTexture *)destination region:(MTLRegion)to level:(NSUInteger)destinationLevel;
@end

// A fence, and the event a shared fence is: a signal value and the wait that blocks until it is
// reached. Both are real state, not a stand-in: -waitForFence: blocks until the value is signalled.
// The event is the port's own class under a name of its own, because the SDK declares MTLSharedEvent
// as a protocol and never names a class for it; the listener is the SDK's own class, implemented
// here, because an application constructs that one by name.
//
// The value and the wait live in a state of their own, so that a handle names the state and not the
// object: an event opened from a handle is a different object over the same value, which is what
// opening an event in another process is.
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

// The log container of a command buffer and of a function log: the one class, defined in MTLReflection14.m and
// handed out by MTLCommandBuffer14.m, so both files see its declaration here.
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
