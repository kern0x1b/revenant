#import "CharonMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString *const CharonMetalErrorDomain = @"CharonMetalErrorDomain";

NSError *CharonMetalError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:CharonMetalErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation CharonMetalDevice {
    EAGLContext *_context;
    NSRecursiveLock *_lock;
    NSMutableDictionary *_pipelines;
}

+ (CharonMetalDevice *)shared
{
    static CharonMetalDevice *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonMetalDevice alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context)
        return nil;
    if ((self = [super init])) {
        _context = context;
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (EAGLContext *)context
{
    return _context;
}

- (void)acquire
{
    [_lock lock];
    if ([EAGLContext currentContext] != _context)
        [EAGLContext setCurrentContext:_context];
}

- (void)relinquish
{
    [_lock unlock];
}

- (NSString *)name
{
    return @"Charon OpenGL ES 2.0";
}

- (uint64_t)registryID
{
    return 1;
}

- (BOOL)isLowPower
{
    return YES;
}

- (BOOL)isHeadless
{
    return NO;
}

- (BOOL)isRemovable
{
    return NO;
}

- (BOOL)hasUnifiedMemory
{
    return YES;
}

- (BOOL)supportsFeatureSet:(MTLFeatureSet)featureSet
{
    return NO;
}

- (BOOL)supportsFamily:(MTLGPUFamily)gpuFamily
{
    return NO;
}

- (BOOL)supportsTextureSampleCount:(NSUInteger)sampleCount
{
    return sampleCount == 1;
}

- (MTLSize)maxThreadsPerThreadgroup
{
    return MTLSizeMake(0, 0, 0);
}

- (id<MTLCommandQueue>)newCommandQueue
{
    return (id<MTLCommandQueue>)[[CharonMetalQueue alloc] init];
}

- (id<MTLCommandQueue>)newCommandQueueWithMaxCommandBufferCount:(NSUInteger)maxCommandBufferCount
{
    return [self newCommandQueue];
}

- (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options
{
    return (id<MTLBuffer>)[[CharonMetalBuffer alloc] initWithLength:length bytes:NULL];
}

- (id<MTLBuffer>)newBufferWithBytes:(const void *)pointer length:(NSUInteger)length options:(MTLResourceOptions)options
{
    return (id<MTLBuffer>)[[CharonMetalBuffer alloc] initWithLength:length bytes:pointer];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor
{
    return (id<MTLTexture>)[[CharonMetalTexture alloc] initWithDescriptor:descriptor];
}

- (id<MTLSamplerState>)newSamplerStateWithDescriptor:(MTLSamplerDescriptor *)descriptor
{
    return (id<MTLSamplerState>)[[CharonMetalSampler alloc] initWithDescriptor:descriptor];
}

// A compute pipeline of the port is a kernel tools/air2cpu translated out of the AIR of the library
// the function came from, run on the CPU because the drivers of iOS 6 are OpenGL ES 2.0 and there is
// no compute shader to dispatch into (facts/OpenGLES/ES3Functions.md, measured on an iPhone 4S). A
// kernel the tool refused is not in the table the pipeline looks in, and the answer says so by name.
- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction error:(NSError **)error
{
    return (id<MTLComputePipelineState>)[[CharonMetalComputePipeline alloc] initWithFunction:computeFunction error:error];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction options:(MTLPipelineOption)options reflection:(MTLAutoreleasedComputePipelineReflection *)reflection error:(NSError **)error
{
    return [self newComputePipelineStateWithFunction:computeFunction error:error];
}

- (void)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction completionHandler:(MTLNewComputePipelineStateCompletionHandler)completionHandler
{
    NSError *error = nil;
    id<MTLComputePipelineState> state = [self newComputePipelineStateWithFunction:computeFunction error:&error];
    completionHandler(state, error);
}

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor:(MTLDepthStencilDescriptor *)descriptor
{
    return (id<MTLDepthStencilState>)[[CharonMetalDepthStencil alloc] initWithDescriptor:descriptor];
}

- (id<MTLLibrary>)newDefaultLibrary
{
    return [self newDefaultLibraryWithBundle:[NSBundle mainBundle] error:NULL];
}

- (id<MTLLibrary>)newDefaultLibraryWithBundle:(NSBundle *)bundle error:(NSError **)error
{
    NSString *path = [bundle pathForResource:@"default" ofType:@"metallib"];
    if (!path) {
        if (error)
            *error = CharonMetalError(1, @"the bundle carries no default.metallib");
        return nil;
    }
    return [self newLibraryWithFile:path error:error];
}

- (id<MTLLibrary>)newLibraryWithFile:(NSString *)filepath error:(NSError **)error
{
    return (id<MTLLibrary>)[[CharonMetalLibrary alloc] initWithFolder:[filepath stringByAppendingString:@".es2"] error:error];
}

- (id<MTLLibrary>)newLibraryWithURL:(NSURL *)url error:(NSError **)error
{
    return [self newLibraryWithFile:url.path error:error];
}

- (id<MTLLibrary>)newLibraryWithData:(id)data error:(NSError **)error
{
    if (error)
        *error = CharonMetalError(2, @"a library built from bytes in memory has no OpenGL ES form; the translated library sits beside its metallib file");
    return nil;
}

- (id<MTLLibrary>)newLibraryWithSource:(NSString *)source options:(MTLCompileOptions *)options error:(NSError **)error
{
    if (error)
        *error = CharonMetalError(3, @"Metal Shading Language source is not compiled on this system");
    return nil;
}

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error
{
    return (id<MTLRenderPipelineState>)[[CharonMetalPipeline alloc] initWithDescriptor:descriptor error:error];
}

- (void)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor completionHandler:(MTLNewRenderPipelineStateCompletionHandler)completionHandler
{
    NSError *error = nil;
    id<MTLRenderPipelineState> state = [self newRenderPipelineStateWithDescriptor:descriptor error:&error];
    completionHandler(state, error);
}

@end
