#import "RevenantMetal.h"
#import "RevenantMetalDebugGroups.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#include <pthread.h>

static const NSUInteger RevenantMetalComputeBufferSlots = 16;

typedef air2cpu_kernel_fn RevenantMetalKernel;
typedef air2cpu_barrier_fn RevenantMetalBarrier;

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t arrived;
    uint32_t threads;
    uint32_t arrivals;
    uint32_t departures;
    uint32_t generation;
    int released;
} RevenantMetalRendezvous;

typedef struct {
    RevenantMetalKernel kernel;
    void *buffers[RevenantMetalComputeBufferSlots];
    revenant_v4i thread, group, size;
    char *block;
    uint32_t blockBytes;
    RevenantMetalRendezvous *rendezvous;
} RevenantMetalWork;

static void RevenantMetalRendezvousWait(void *context, uint32_t tid, uint32_t threads)
{
    RevenantMetalRendezvous *rendezvous = context;
    (void)tid;
    (void)threads;
    pthread_mutex_lock(&rendezvous->mutex);
    uint32_t generation = rendezvous->generation;
    rendezvous->arrivals++;
    if (++rendezvous->departures == rendezvous->threads) {
        rendezvous->arrivals = 0;
        rendezvous->departures = 0;
        rendezvous->generation++;
        pthread_cond_broadcast(&rendezvous->arrived);
    } else {
        while (generation == rendezvous->generation && !rendezvous->released)
            pthread_cond_wait(&rendezvous->arrived, &rendezvous->mutex);
    }
    pthread_mutex_unlock(&rendezvous->mutex);
}

static void RevenantMetalRendezvousRelease(RevenantMetalRendezvous *rendezvous)
{
    pthread_mutex_lock(&rendezvous->mutex);
    rendezvous->released = 1;
    rendezvous->generation++;
    pthread_cond_broadcast(&rendezvous->arrived);
    pthread_mutex_unlock(&rendezvous->mutex);
}

typedef struct {
    RevenantMetalWork *work;
    revenant_v4i thread, group, size;
} RevenantMetalSlot;

static void *RevenantMetalRunOneThread(void *argument)
{
    RevenantMetalSlot *slot = argument;
    slot->work->kernel((void *const *)slot->work->buffers, slot->thread, slot->group, slot->size,
                       slot->work->block, slot->work->blockBytes,
                       RevenantMetalRendezvousWait, slot->work->rendezvous);
    return NULL;
}

@implementation RevenantMetalComputeEncoder {
    RevenantMetalComputePipeline *_pipeline;
    NSMutableArray *_buffers;
    NSMutableArray *_offsets;
    NSMutableArray *_threads;
    NSMutableArray *_threadgroups;
    NSMutableArray *_groups;
    NSMutableArray *_textures;
    NSMutableArray *_samplers;
    uint32_t _blockBytes;
}

@synthesize label;

- (instancetype)init
{
    if ((self = [super init])) {
        _buffers = [NSMutableArray array];
        _offsets = [NSMutableArray array];
        _threads = [NSMutableArray array];
        _threadgroups = [NSMutableArray array];
        _groups = [NSMutableArray array];
        _textures = [NSMutableArray array];
        _samplers = [NSMutableArray array];
    }
    return self;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (void)setComputePipelineState:(id<MTLComputePipelineState>)pipeline
{
    _pipeline = [pipeline isKindOfClass:[RevenantMetalComputePipeline class]] ? (RevenantMetalComputePipeline *)pipeline : nil;
    if (_pipeline && !_blockBytes)
        _blockBytes = [_pipeline revenantBlockBytes];
}

- (void)setBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index
{
    if (index >= RevenantMetalComputeBufferSlots) {
        NSLog(@"Metal: a compute buffer at index %lu is refused: a translated kernel is handed %lu buffers, which is the bound this encoder keeps",
              (unsigned long)index, (unsigned long)RevenantMetalComputeBufferSlots);
        return;
    }
    while (_buffers.count <= index) {
        [_buffers addObject:[NSNull null]];
        [_offsets addObject:@(0)];
    }
    [_buffers replaceObjectAtIndex:index withObject:buffer ? (id)buffer : [NSNull null]];
    if (![buffer isKindOfClass:[RevenantMetalBuffer class]]) {
        [_offsets replaceObjectAtIndex:index withObject:@(0)];
        return;
    }
    RevenantMetalBuffer *held = (RevenantMetalBuffer *)buffer;
    if (offset > held.length) {
        NSLog(@"Metal: a compute buffer at index %lu is bound at offset %lu of %lu bytes, which is past its end, and the binding is refused",
              (unsigned long)index, (unsigned long)offset, (unsigned long)held.length);
        [_buffers replaceObjectAtIndex:index withObject:[NSNull null]];
        [_offsets replaceObjectAtIndex:index withObject:@(0)];
        return;
    }
    [_offsets replaceObjectAtIndex:index withObject:@(offset)];
}

- (void)setBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index
{
    [self setBuffer:(id<MTLBuffer>)[[RevenantMetalBuffer alloc] initWithLength:length bytes:bytes] offset:0 atIndex:index];
}

- (void)setTexture:(id<MTLTexture>)texture atIndex:(NSUInteger)index
{
    if (index >= RevenantMetalComputeBufferSlots) {
        NSLog(@"Metal: a compute texture at index %lu is refused: this encoder keeps %lu texture slots", (unsigned long)index, (unsigned long)RevenantMetalComputeBufferSlots);
        return;
    }
    while (_textures.count <= index)
        [_textures addObject:[NSNull null]];
    [_textures replaceObjectAtIndex:index withObject:texture ? (id)texture : [NSNull null]];
}

- (void)setSamplerState:(id<MTLSamplerState>)sampler atIndex:(NSUInteger)index
{
    if (index >= RevenantMetalComputeBufferSlots) {
        NSLog(@"Metal: a compute sampler at index %lu is refused: this encoder keeps %lu sampler slots", (unsigned long)index, (unsigned long)RevenantMetalComputeBufferSlots);
        return;
    }
    while (_samplers.count <= index)
        [_samplers addObject:[NSNull null]];
    [_samplers replaceObjectAtIndex:index withObject:sampler ? (id)sampler : [NSNull null]];
}

- (void)setThreadgroupMemoryLength:(NSUInteger)length atIndex:(NSUInteger)index
{
    if (index != 0) {
        NSLog(@"Metal: threadgroup memory at index %lu is refused: this port holds one block per encoder", (unsigned long)index);
        return;
    }
    _blockBytes = (uint32_t)length;
    [_pipeline revenantSetBlockBytes:_blockBytes];
}

- (void)dispatchThreadgroups:(MTLSize)groups threadsPerThreadgroup:(MTLSize)threads
{
    if (!_pipeline) {
        NSLog(@"Metal: a compute dispatch with no pipeline state: there is no kernel to run, so nothing is");
        return;
    }
    if ([_pipeline revenantBlockBytes] && !_blockBytes) {
        NSLog(@"Metal: %@ declares a threadgroup block and -setThreadgroupMemoryLength:atIndex: has not said how long it is, so this dispatch is refused rather than given a block of a guessed size",
              [_pipeline kernelName] ?: @"the kernel");
        return;
    }
    if (threads.width == 0 || threads.height == 0 || threads.depth == 0) {
        NSLog(@"Metal: a dispatch of %lux%lux%lu threads per group has an empty dimension, and there is no thread to run",
              (unsigned long)threads.width, (unsigned long)threads.height, (unsigned long)threads.depth);
        return;
    }
    if ([_pipeline revenantTranslatedFunction]) {
        [self revenantDispatchTranslatedGrid:MTLSizeMake(groups.width * threads.width, groups.height * threads.height, groups.depth * threads.depth)];
        return;
    }
    uint32_t each = (uint32_t)(threads.width * threads.height * threads.depth);
    [_pipeline revenantSetThreads:each];
    uint32_t group = 0;
    for (uint32_t z = 0; z < (uint32_t)groups.depth; z++)
        for (uint32_t y = 0; y < (uint32_t)groups.height; y++)
            for (uint32_t x = 0; x < (uint32_t)groups.width; x++, group++)
                [self revenantRunGroup:each atGroup:group atGroupPosition:(revenant_v4i){x, y, z, 0} threads:threads];
}

- (void)dispatchThreads:(MTLSize)threadsPerThreadgroup threadsPerGrid:(MTLSize)threadsPerGrid
{
    if ([_pipeline revenantTranslatedFunction]) {
        [self revenantDispatchTranslatedGrid:threadsPerGrid];
        return;
    }
    uint32_t each = (uint32_t)threadsPerThreadgroup.width;
    uint32_t wide = each ? each : 1;
    MTLSize groups = MTLSizeMake((uint32_t)threadsPerGrid.width / wide, threadsPerGrid.height, threadsPerGrid.depth);
    [self dispatchThreadgroups:groups threadsPerThreadgroup:threadsPerThreadgroup];
}

- (void)revenantDispatchTranslatedGrid:(MTLSize)grid
{
    NSString *kernel = [_pipeline kernelName] ?: @"the kernel";
    if (_blockBytes) {
        NSLog(@"Metal: %@ is translated and has no threadgroup block, so the threadgroup memory set for it is refused and the dispatch is not run", kernel);
        return;
    }
    if (!grid.width || !grid.height)
        return;
    if (grid.depth != 1) {
        NSLog(@"Metal: %@ is a translated two-dimensional kernel, so a grid of depth %lu is refused and the dispatch is not run", kernel, (unsigned long)grid.depth);
        return;
    }
    NSDictionary *output = [_pipeline revenantTranslatedFunction].reflection[@"outputTexture"];
    NSUInteger index = [output[@"index"] unsignedIntegerValue];
    if (!output || index >= _textures.count || ![_textures[index] isKindOfClass:[RevenantMetalTexture class]]) {
        NSLog(@"Metal: %@ writes an output texture that is not bound to the encoder, so the dispatch is not run", kernel);
        return;
    }
    RevenantMetalTexture *target = _textures[index];
    RevenantMetalPipeline *pipeline = [_pipeline revenantRenderPipeline];
    if (!pipeline)
        return;
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    RevenantMetalEncoder *render = [[RevenantMetalEncoder alloc] initWithDescriptor:pass];
    if (!render)
        return;
    [render setRenderPipelineState:pipeline];
    for (NSUInteger slot = 0; slot < _buffers.count && slot < RevenantMetalComputeBufferSlots; slot++)
        if ([_buffers[slot] isKindOfClass:[RevenantMetalBuffer class]])
            [render setFragmentBuffer:_buffers[slot] offset:[_offsets[slot] unsignedIntegerValue] atIndex:slot];
    for (NSUInteger slot = 0; slot < _textures.count && slot < RevenantMetalComputeBufferSlots; slot++)
        if (slot != index && [_textures[slot] isKindOfClass:[RevenantMetalTexture class]])
            [render setFragmentTexture:_textures[slot] atIndex:slot];
    for (NSUInteger slot = 0; slot < _samplers.count && slot < RevenantMetalComputeBufferSlots; slot++)
        if ([_samplers[slot] isKindOfClass:[RevenantMetalSampler class]])
            [render setFragmentSamplerState:_samplers[slot] atIndex:slot];
    static const GLfloat corners[8] = {-1, -1, 1, -1, -1, 1, 1, 1};
    [render setVertexBytes:corners length:sizeof corners atIndex:0];
    [render setViewport:(MTLViewport){0, 0, (double)target.width, (double)target.height, 0, 1}];
    [render setScissorRect:(MTLScissorRect){0, 0, grid.width < target.width ? grid.width : target.width, grid.height < target.height ? grid.height : target.height}];
    [render drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [render endEncoding];
}

- (void)revenantRunGroup:(uint32_t)each atGroup:(uint32_t)group atGroupPosition:(revenant_v4i)position threads:(MTLSize)threads
{
    void *raw = [_pipeline revenantKernelFunction];
    if (!raw) {
        NSLog(@"Metal: the pipeline holds no kernel, so this dispatch is not run");
        return;
    }
    [_pipeline revenantAnnounceCPURoute];
    RevenantMetalKernel kernel = (RevenantMetalKernel)raw;
    RevenantMetalRendezvous *rendezvous = calloc(1, sizeof(*rendezvous));
    pthread_mutex_init(&rendezvous->mutex, NULL);
    pthread_cond_init(&rendezvous->arrived, NULL);
    rendezvous->threads = each;
    rendezvous->arrivals = 0;
    rendezvous->departures = 0;
    rendezvous->generation = 0;
    rendezvous->released = 0;

    RevenantMetalWork *work = calloc(1, sizeof(*work));
    work->kernel = kernel;
    work->group = position;
    work->size = (revenant_v4i){(int32_t)threads.width, (int32_t)threads.height, (int32_t)threads.depth, 1};
    work->blockBytes = _blockBytes;
    work->block = calloc(1, _blockBytes ? _blockBytes : 1);
    work->rendezvous = rendezvous;
    for (NSUInteger slot = 0; slot < _buffers.count && slot < RevenantMetalComputeBufferSlots; slot++) {
        id bound = _buffers[slot];
        if (![bound isKindOfClass:[RevenantMetalBuffer class]])
            continue;
        NSUInteger offset = slot < _offsets.count ? [_offsets[slot] unsignedIntegerValue] : 0;
        work->buffers[slot] = (uint8_t *)[(RevenantMetalBuffer *)bound bytes] + offset;
    }

    pthread_t *pool = calloc(each ? each : 1, sizeof(pthread_t));
    RevenantMetalSlot *slots = calloc(each ? each : 1, sizeof(RevenantMetalSlot));
    for (uint32_t thread = 0; thread < each; thread++) {
        if (getenv("REVENANT_PRINT_POSITIONS"))
            fprintf(stderr, "revenant: group %u thread %u of %u is told thread (%d, %d, %d) group (%d, %d, %d) size (%d, %d, %d)\n",
                    (unsigned)group, (unsigned)thread, (unsigned)each,
                    (int)slots[thread].thread.x, (int)slots[thread].thread.y, (int)slots[thread].thread.z,
                    (int)slots[thread].group.x, (int)slots[thread].group.y, (int)slots[thread].group.z,
                    (int)slots[thread].size.x, (int)slots[thread].size.y, (int)slots[thread].size.z);
        slots[thread].work = work;
        slots[thread].thread = (revenant_v4i){(int32_t)(thread % (uint32_t)threads.width),
                                             (int32_t)((thread / (uint32_t)threads.width) % (uint32_t)threads.height),
                                             (int32_t)(thread / ((uint32_t)threads.width * (uint32_t)threads.height)), 0};
        slots[thread].group = work->group;
        slots[thread].size = work->size;
        if (pthread_create(&pool[thread], NULL, RevenantMetalRunOneThread, &slots[thread]) != 0) {
            NSLog(@"Metal: the %luth thread of a workgroup of %lu could not be started; the rest of the group is let go out of its barrier and the dispatch is refused rather than left hanging",
                  (unsigned long)thread, (unsigned long)each);
            RevenantMetalRendezvousRelease(rendezvous);
            for (uint32_t started = 0; started < thread; started++)
                pthread_join(pool[started], NULL);
            free(pool);
            free(slots);
            free(work->block);
            free(work);
            pthread_mutex_destroy(&rendezvous->mutex);
            pthread_cond_destroy(&rendezvous->arrived);
            free(rendezvous);
            return;
        }
    }
    for (uint32_t thread = 0; thread < each; thread++)
        pthread_join(pool[thread], NULL);
    free(pool);
    free(slots);
    free(work->block);
    free(work);
    pthread_mutex_destroy(&rendezvous->mutex);
    pthread_cond_destroy(&rendezvous->arrived);
    free(rendezvous);
}

- (void)memoryBarrierWithScope:(MTLBarrierScope)scope afterStages:(MTLRenderStages)afterStages beforeStages:(MTLRenderStages)beforeStages
{
    (void)scope;
    (void)afterStages;
    (void)beforeStages;
}

- (void)endEncoding
{
}

- (void)pushDebugGroup:(NSString *)string
{
    RevenantMetalPushDebugGroup(_groups, string);
}

- (void)popDebugGroup
{
    RevenantMetalPopDebugGroup(_groups, self);
}

- (void)insertDebugSignpost:(NSString *)string
{
}

@end
