#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSString *const RevenantMetalErrorDomain = @"RevenantMetalErrorDomain";

NSError *RevenantMetalError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:RevenantMetalErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation RevenantMetalDevice {
    EAGLContext *_context;
    NSRecursiveLock *_lock;
    NSMutableDictionary *_pipelines;
    CVOpenGLESTextureCacheRef _textureCache;
}

+ (RevenantMetalDevice *)shared
{
    static RevenantMetalDevice *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[RevenantMetalDevice alloc] init];
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
    return @"Revenant OpenGL ES 2.0";
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
    return (id<MTLCommandQueue>)[[RevenantMetalQueue alloc] init];
}

- (id<MTLCommandQueue>)newCommandQueueWithMaxCommandBufferCount:(NSUInteger)maxCommandBufferCount
{
    return [self newCommandQueue];
}

- (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options
{
    return (id<MTLBuffer>)[[RevenantMetalBuffer alloc] initWithLength:length bytes:NULL];
}

- (id<MTLBuffer>)newBufferWithBytes:(const void *)pointer length:(NSUInteger)length options:(MTLResourceOptions)options
{
    return (id<MTLBuffer>)[[RevenantMetalBuffer alloc] initWithLength:length bytes:pointer];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor
{
    return (id<MTLTexture>)[[RevenantMetalTexture alloc] initWithDescriptor:descriptor];
}

- (id<MTLTexture>)newTextureWithDescriptor:(MTLTextureDescriptor *)descriptor iosurface:(IOSurfaceRef)iosurface plane:(NSUInteger)plane
{
    return (id<MTLTexture>)[[RevenantMetalTexture alloc] initWithDescriptor:descriptor iosurface:iosurface plane:plane];
}

- (CVOpenGLESTextureCacheRef)textureCache
{
    if (!_textureCache) {
        CVReturn status = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
        if (status != kCVReturnSuccess) {
            NSLog(@"Metal: the OpenGL ES texture cache cannot be created: CoreVideo returned %d", (int)status);
            return NULL;
        }
    }
    return _textureCache;
}

- (id<MTLSamplerState>)newSamplerStateWithDescriptor:(MTLSamplerDescriptor *)descriptor
{
    return (id<MTLSamplerState>)[[RevenantMetalSampler alloc] initWithDescriptor:descriptor];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction error:(NSError **)error
{
    return (id<MTLComputePipelineState>)[[RevenantMetalComputePipeline alloc] initWithFunction:computeFunction error:error];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction options:(MTLPipelineOption)options reflection:(MTLAutoreleasedComputePipelineReflection *)reflection error:(NSError **)error
{
    return [self newComputePipelineStateWithFunction:computeFunction error:error];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor:(MTLComputePipelineDescriptor *)descriptor options:(MTLPipelineOption)options reflection:(MTLAutoreleasedComputePipelineReflection *)reflection error:(NSError **)error
{
    if (!descriptor.computeFunction) {
        if (error)
            *error = RevenantMetalError(23, @"the compute pipeline descriptor has no compute function");
        return nil;
    }
    return [self newComputePipelineStateWithFunction:descriptor.computeFunction options:options reflection:reflection error:error];
}

- (void)newComputePipelineStateWithFunction:(id<MTLFunction>)computeFunction completionHandler:(MTLNewComputePipelineStateCompletionHandler)completionHandler
{
    NSError *error = nil;
    id<MTLComputePipelineState> state = [self newComputePipelineStateWithFunction:computeFunction error:&error];
    completionHandler(state, error);
}

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor:(MTLDepthStencilDescriptor *)descriptor
{
    return (id<MTLDepthStencilState>)[[RevenantMetalDepthStencil alloc] initWithDescriptor:descriptor];
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
            *error = RevenantMetalError(1, @"the bundle carries no default.metallib");
        return nil;
    }
    return [self newLibraryWithFile:path error:error];
}

- (id<MTLLibrary>)newLibraryWithFile:(NSString *)filepath error:(NSError **)error
{
    return (id<MTLLibrary>)[[RevenantMetalLibrary alloc] initWithFolder:[filepath stringByAppendingString:@".es2"] error:error];
}

- (id<MTLLibrary>)newLibraryWithURL:(NSURL *)url error:(NSError **)error
{
    return [self newLibraryWithFile:url.path error:error];
}

- (id<MTLLibrary>)newLibraryWithData:(id)data error:(NSError **)error
{
    if (error)
        *error = RevenantMetalError(2, @"a library built from bytes in memory has no OpenGL ES form; the translated library sits beside its metallib file");
    return nil;
}

- (id<MTLLibrary>)newLibraryWithSource:(NSString *)source options:(MTLCompileOptions *)options error:(NSError **)error
{
    if (error)
        *error = RevenantMetalError(3, @"Metal Shading Language source is not compiled on this system");
    return nil;
}

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error
{
    return (id<MTLRenderPipelineState>)[[RevenantMetalPipeline alloc] initWithDescriptor:descriptor error:error];
}

- (void)newRenderPipelineStateWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor completionHandler:(MTLNewRenderPipelineStateCompletionHandler)completionHandler
{
    NSError *error = nil;
    id<MTLRenderPipelineState> state = [self newRenderPipelineStateWithDescriptor:descriptor error:&error];
    completionHandler(state, error);
}

@end
