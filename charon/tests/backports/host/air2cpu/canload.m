// canload.m — the one measurement that decides the shape of the whole compute path: does a real Metal
// runtime accept the hand-authored AIR compute kernel in fixtures/sum.ll, and what does it compute?
//
// If it does, the host is an oracle for the port's own AIR-to-C translation of the same bitcode, and
// the two can be compared on one input. If it does not, the fixture has to come from a real
// application's metallib instead, and that is a different plan. This program answers it either way and
// says which happened.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

int main(int argc, const char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            printf("usage: canload LIB.metallib\n");
            return 2;
        }
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSError *error = nil;
        id<MTLLibrary> library = [device newLibraryWithFile:[NSString stringWithUTF8String:argv[1]] error:&error];
        if (library == nil) {
            printf("REFUSED %s: %s\n", argv[1], error.localizedDescription.UTF8String);
            return 1;
        }
        // The names of a library, read the way an application does before it asks for a function.
        NSArray<NSString *> *names = [library functionNames];
        printf("LOADED %s with %lu functions\n", argv[1], (unsigned long)names.count);
        for (NSString *name in names)
            printf("  function %s\n", name.UTF8String);
        id<MTLFunction> kernel = [library newFunctionWithName:@"sumK"];
        if (kernel == nil) {
            printf("NO sumK\n");
            return 1;
        }
        NSError *pipelineError = nil;
        id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:kernel error:&pipelineError];
        if (pipeline == nil) {
            printf("NO PIPELINE: %s\n", pipelineError.localizedDescription.UTF8String);
            return 1;
        }
        printf("PIPELINE ok, maxTotalThreadsPerThreadgroup=%zu threadExecutionWidth=%zu\n",
               pipeline.maxTotalThreadsPerThreadgroup, pipeline.threadExecutionWidth);

        // Sixteen values in, sixteen sums out: the kernel reads four from the group's window and writes
        // its sum after them, so the whole threadgroup's work is visible in the tail of the buffer.
        const NSUInteger count = 16;
        float *values = calloc(count, sizeof(float));
        for (NSUInteger index = 0; index < count; index++)
            values[index] = (float)(index + 1);
        id<MTLBuffer> buffer = [device newBufferWithLength:count * sizeof(float) options:MTLResourceStorageModeShared];
        memcpy(buffer.contents, values, count * sizeof(float));
        id<MTLCommandBuffer> commandBuffer = [[device newCommandQueue] commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
        [encoder setComputePipelineState:pipeline];
        [encoder setBuffer:buffer offset:0 atIndex:0];
        [encoder dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(16, 1, 1)];
        [encoder endEncoding];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];
        if (commandBuffer.error) {
            printf("DISPATCH FAILED: %s\n", commandBuffer.error.localizedDescription.UTF8String);
            return 1;
        }
        const float *out = buffer.contents;
        printf("OUT");
        for (NSUInteger index = 0; index < count; index++)
            printf(" %g", out[index]);
        printf("\n");
    }
    return 0;
}
