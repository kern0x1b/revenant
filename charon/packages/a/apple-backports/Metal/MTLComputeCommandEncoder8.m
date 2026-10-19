#import "CharonMetal.h"
#import "CharonMetalDebugGroups.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#include <pthread.h>

static const NSUInteger CharonMetalComputeBufferSlots = 16;

typedef air2cpu_kernel_fn CharonMetalKernel;
typedef air2cpu_barrier_fn CharonMetalBarrier;

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t arrived;
    uint32_t threads;
    uint32_t arrivals;
    uint32_t departures;
    uint32_t generation;
    int released;
} CharonMetalRendezvous;

typedef struct {
    CharonMetalKernel kernel;
    void *buffers[CharonMetalComputeBufferSlots];
    charon_v4i thread, group, size;
    char *block;
    uint32_t blockBytes;
    CharonMetalRendezvous *rendezvous;
} CharonMetalWork;

static void CharonMetalRendezvousWait(void *context, uint32_t tid, uint32_t threads)
{
    CharonMetalRendezvous *rendezvous = context;
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

static void CharonMetalRendezvousRelease(CharonMetalRendezvous *rendezvous)
{
    pthread_mutex_lock(&rendezvous->mutex);
    rendezvous->released = 1;
    rendezvous->generation++;
    pthread_cond_broadcast(&rendezvous->arrived);
    pthread_mutex_unlock(&rendezvous->mutex);
}

typedef struct {
    CharonMetalWork *work;
    charon_v4i thread, group, size;
} CharonMetalSlot;

static void *CharonMetalRunOneThread(void *argument)
{
    CharonMetalSlot *slot = argument;
    slot->work->kernel((void *const *)slot->work->buffers, slot->thread, slot->group, slot->size,
                       slot->work->block, slot->work->blockBytes,
                       CharonMetalRendezvousWait, slot->work->rendezvous);
    return NULL;
}

@implementation CharonMetalComputeEncoder {
    CharonMetalComputePipeline *_pipeline;
    NSMutableArray *_buffers;
    NSMutableArray *_offsets;
    NSMutableArray *_threads;
    NSMutableArray *_threadgroups;
    NSMutableArray *_groups;
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
    }
    return self;
}

- (id<MTLDevice>)device
{
    return [CharonMetalDevice shared];
}

- (void)setComputePipelineState:(id<MTLComputePipelineState>)pipeline
{
    _pipeline = [pipeline isKindOfClass:[CharonMetalComputePipeline class]] ? (CharonMetalComputePipeline *)pipeline : nil;
    if (_pipeline && !_blockBytes)
        _blockBytes = [_pipeline charonBlockBytes];
}

- (void)setBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index
{
    if (index >= CharonMetalComputeBufferSlots) {
        NSLog(@"Metal: a compute buffer at index %lu is refused: a translated kernel is handed %lu buffers, which is the bound this encoder keeps",
              (unsigned long)index, (unsigned long)CharonMetalComputeBufferSlots);
        return;
    }
    while (_buffers.count <= index) {
        [_buffers addObject:[NSNull null]];
        [_offsets addObject:@(0)];
    }
    [_buffers replaceObjectAtIndex:index withObject:buffer ? (id)buffer : [NSNull null]];
    if (![buffer isKindOfClass:[CharonMetalBuffer class]]) {
        [_offsets replaceObjectAtIndex:index withObject:@(0)];
        return;
    }
    CharonMetalBuffer *held = (CharonMetalBuffer *)buffer;
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
    [self setBuffer:(id<MTLBuffer>)[[CharonMetalBuffer alloc] initWithLength:length bytes:bytes] offset:0 atIndex:index];
}

- (void)setThreadgroupMemoryLength:(NSUInteger)length atIndex:(NSUInteger)index
{
    if (index != 0) {
        NSLog(@"Metal: threadgroup memory at index %lu is refused: this port holds one block per encoder", (unsigned long)index);
        return;
    }
    _blockBytes = (uint32_t)length;
    [_pipeline charonSetBlockBytes:_blockBytes];
}

- (void)dispatchThreadgroups:(MTLSize)groups threadsPerThreadgroup:(MTLSize)threads
{
    if (!_pipeline) {
        NSLog(@"Metal: a compute dispatch with no pipeline state: there is no kernel to run, so nothing is");
        return;
    }
    if ([_pipeline charonBlockBytes] && !_blockBytes) {
        NSLog(@"Metal: %@ declares a threadgroup block and -setThreadgroupMemoryLength:atIndex: has not said how long it is, so this dispatch is refused rather than given a block of a guessed size",
              [_pipeline kernelName] ?: @"the kernel");
        return;
    }
    if (threads.width == 0 || threads.height == 0 || threads.depth == 0) {
        NSLog(@"Metal: a dispatch of %lux%lux%lu threads per group has an empty dimension, and there is no thread to run",
              (unsigned long)threads.width, (unsigned long)threads.height, (unsigned long)threads.depth);
        return;
    }
    uint32_t each = (uint32_t)(threads.width * threads.height * threads.depth);
    [_pipeline charonSetThreads:each];
    uint32_t group = 0;
    for (uint32_t z = 0; z < (uint32_t)groups.depth; z++)
        for (uint32_t y = 0; y < (uint32_t)groups.height; y++)
            for (uint32_t x = 0; x < (uint32_t)groups.width; x++, group++)
                [self charonRunGroup:each atGroup:group atGroupPosition:(charon_v4i){x, y, z, 0} threads:threads];
}

- (void)dispatchThreads:(MTLSize)threadsPerThreadgroup threadsPerGrid:(MTLSize)threadsPerGrid
{
    uint32_t each = (uint32_t)threadsPerThreadgroup.width;
    uint32_t wide = each ? each : 1;
    MTLSize groups = MTLSizeMake((uint32_t)threadsPerGrid.width / wide, threadsPerGrid.height, threadsPerGrid.depth);
    [self dispatchThreadgroups:groups threadsPerThreadgroup:threadsPerThreadgroup];
}

- (void)charonRunGroup:(uint32_t)each atGroup:(uint32_t)group atGroupPosition:(charon_v4i)position threads:(MTLSize)threads
{
    void *raw = [_pipeline charonKernelFunction];
    if (!raw) {
        NSLog(@"Metal: the pipeline holds no kernel, so this dispatch is not run");
        return;
    }
    CharonMetalKernel kernel = (CharonMetalKernel)raw;
    CharonMetalRendezvous *rendezvous = calloc(1, sizeof(*rendezvous));
    pthread_mutex_init(&rendezvous->mutex, NULL);
    pthread_cond_init(&rendezvous->arrived, NULL);
    rendezvous->threads = each;
    rendezvous->arrivals = 0;
    rendezvous->departures = 0;
    rendezvous->generation = 0;
    rendezvous->released = 0;

    CharonMetalWork *work = calloc(1, sizeof(*work));
    work->kernel = kernel;
    work->group = position;
    work->size = (charon_v4i){(int32_t)threads.width, (int32_t)threads.height, (int32_t)threads.depth, 1};
    work->blockBytes = _blockBytes;
    work->block = calloc(1, _blockBytes ? _blockBytes : 1);
    work->rendezvous = rendezvous;
    for (NSUInteger slot = 0; slot < _buffers.count && slot < CharonMetalComputeBufferSlots; slot++) {
        id bound = _buffers[slot];
        if (![bound isKindOfClass:[CharonMetalBuffer class]])
            continue;
        NSUInteger offset = slot < _offsets.count ? [_offsets[slot] unsignedIntegerValue] : 0;
        work->buffers[slot] = (uint8_t *)[(CharonMetalBuffer *)bound bytes] + offset;
    }

    pthread_t *pool = calloc(each ? each : 1, sizeof(pthread_t));
    CharonMetalSlot *slots = calloc(each ? each : 1, sizeof(CharonMetalSlot));
    for (uint32_t thread = 0; thread < each; thread++) {
        if (getenv("CHARON_PRINT_POSITIONS"))
            fprintf(stderr, "charon: group %u thread %u of %u is told thread (%d, %d, %d) group (%d, %d, %d) size (%d, %d, %d)\n",
                    (unsigned)group, (unsigned)thread, (unsigned)each,
                    (int)slots[thread].thread.x, (int)slots[thread].thread.y, (int)slots[thread].thread.z,
                    (int)slots[thread].group.x, (int)slots[thread].group.y, (int)slots[thread].group.z,
                    (int)slots[thread].size.x, (int)slots[thread].size.y, (int)slots[thread].size.z);
        slots[thread].work = work;
        slots[thread].thread = (charon_v4i){(int32_t)(thread % (uint32_t)threads.width),
                                             (int32_t)((thread / (uint32_t)threads.width) % (uint32_t)threads.height),
                                             (int32_t)(thread / ((uint32_t)threads.width * (uint32_t)threads.height)), 0};
        slots[thread].group = work->group;
        slots[thread].size = work->size;
        if (pthread_create(&pool[thread], NULL, CharonMetalRunOneThread, &slots[thread]) != 0) {
            NSLog(@"Metal: the %luth thread of a workgroup of %lu could not be started; the rest of the group is let go out of its barrier and the dispatch is refused rather than left hanging",
                  (unsigned long)thread, (unsigned long)each);
            CharonMetalRendezvousRelease(rendezvous);
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
    CharonMetalPushDebugGroup(_groups, string);
}

- (void)popDebugGroup
{
    CharonMetalPopDebugGroup(_groups, self);
}

- (void)insertDebugSignpost:(NSString *)string
{
}

@end
