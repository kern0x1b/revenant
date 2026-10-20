#import "RevenantMetal.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#include <pthread.h>

#include <dlfcn.h>

@implementation RevenantMetalComputePipeline {
    void *_function;
    uint32_t _threads;
    uint32_t _blockBytes;
    NSString *_kernel;
}

@synthesize label;

- (instancetype)initWithFunction:(id<MTLFunction>)function error:(NSError **)error
{
    NSString *name = function.name;
    struct KernelEntry { const char *name; void *function; uint32_t buffers; uint32_t block; uint32_t reserved; };
    static const struct KernelEntry *table;
    static unsigned count;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const struct KernelEntry *found = dlsym(RTLD_DEFAULT, "air2cpu_kernels");
        if (!found)
            return;
        table = found;
        const unsigned *total = dlsym(RTLD_DEFAULT, "air2cpu_kernel_count");
        count = total ? *total : 0;
    });
    if (!table) {
        if (error)
            *error = RevenantMetalError(20, @"this library carries no kernel the port could translate: the air2cpu tool in frameworks/Backports/src/air2cpu has not been run over it, or every kernel in it was refused by name, and the log of the build that ran it says which");
        return nil;
    }
    for (unsigned index = 0; index < count; index++) {
        if (!table[index].name || !name || ![name isEqualToString:[NSString stringWithUTF8String:table[index].name]])
            continue;
        if ((self = [super init])) {
            _kernel = name;
            _function = table[index].function;
            _blockBytes = table[index].block;
        }
        return self;
    }
    if (error)
        *error = RevenantMetalError(21, [NSString stringWithFormat:@"%@ is not a kernel this port could translate: the air2cpu tool in frameworks/Backports/src/air2cpu refused it, and the refusal is in the log of the build that ran it",
                                   name ? name : @"that function"]);
    return nil;
}

- (id<MTLDevice>)device
{
    return [RevenantMetalDevice shared];
}

- (void *)revenantKernelFunction
{
    return _function;
}

- (uint32_t)revenantBlockBytes
{
    return _blockBytes;
}

- (uint32_t)revenantThreads
{
    return _threads;
}

- (void)revenantSetThreads:(uint32_t)threads
{
    _threads = threads;
}

- (NSUInteger)maxTotalThreadsPerThreadgroup
{
    return _threads;
}

- (NSUInteger)threadExecutionWidth
{
    return _threads;
}

- (NSUInteger)maxThreadgroupsPerThreadgroup
{
    return 1;
}

- (NSUInteger)threadgroupMemoryLengthForIndex:(NSUInteger)index
{
    return index == 0 ? _blockBytes : 0;
}

- (void)revenantSetBlockBytes:(uint32_t)bytes
{
    _blockBytes = bytes;
}

- (NSString *)kernelName
{
    return _kernel;
}

@end
