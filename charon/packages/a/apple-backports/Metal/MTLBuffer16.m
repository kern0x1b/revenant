#import "CharonMetal.h"

// The 16.0 GPU address of a buffer: the number a shader uses to name the buffer. The port's shaders are CPU
// kernels that take the buffer's bytes as a pointer, so the address is that pointer, widened to 64 bits.
// The bytes are allocated once and never move while the buffer lives, so the address is stable, and calloc
// never returns zero for them (facts/Metal/Buffers.md).
@implementation CharonMetalBuffer (Address16)

- (uint64_t)gpuAddress
{
    return (uint64_t)(uintptr_t)[self contents];
}

@end
