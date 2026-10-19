// harness.m — the differential's second half: the PORT's encoder, not a reimplementation of it.
//
// driver.c was the test's own implementation of the same shape, so it could not see a bug in the
// encoder that runs on the device: rotating the tid/gid/tg the encoder hands a kernel left the
// differential green. This program dispatches through the port's own
// -newComputePipelineStateWithFunction:error:, -computeCommandEncoder, -setBuffer:offset:atIndex:,
// -setThreadgroupMemoryLength:atIndex: and -dispatchThreadgroups:threadsPerThreadgroup:, with the
// encoder's source compiled into this binary (see compare.sh), so what runs here is what runs on the
// device. The host Metal's own dispatch of the same kernel is the answer it is compared against.
//
// A kernel the tool refused is absent from the table, and compare.py fails the run when any kernel in
// the table was not compared - so a refusal cannot pass as a match.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "../../../../packages/a/apple-backports/air2cpu-abi.h"

// The port's own classes, as the harness sees them after the rename compare.sh applies.
// A buffer of the port is its own bytes: the port has no GPU memory, so a kernel is handed the
// bytes of a CharonMetalBuffer. A host MTLBuffer is a different object with different storage, and
// binding one here is what made the kernel read a pointer the encoder had refused to bind.
@interface CharonHostCharonMetalBuffer : NSObject
- (instancetype)initWithLength:(NSUInteger)length bytes:(const void *)bytes;
- (void *)bytes;
- (NSUInteger)length;
@end

@interface CharonHostCharonMetalComputePipeline : NSObject
- (instancetype)initWithFunction:(id<MTLFunction>)function error:(NSError **)error;
- (id)charonKernelFunction;
- (uint32_t)charonBlockBytes;
- (uint32_t)charonThreads;
@end

@interface CharonHostCharonMetalComputeEncoder : NSObject
- (void)setComputePipelineState:(id)pipeline;
- (void)setBuffer:(id)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index;
- (void)setBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index;
- (void)setThreadgroupMemoryLength:(NSUInteger)length atIndex:(NSUInteger)index;
- (void)dispatchThreadgroups:(MTLSize)groups threadsPerThreadgroup:(MTLSize)threads;
- (void)endEncoding;
@end

// The device's own compute methods are one line each and the device itself makes an EAGL context,
// which a host has none of; the harness stands in for those two, so the pipeline, the encoder and
// the buffer - where every bug the review found in this path lives - are the port's own.
@interface CharonHostDevice : NSObject
- (id)newComputePipelineStateWithFunction:(id<MTLFunction>)function error:(NSError **)error;
- (id)computeCommandEncoder;
@end

@implementation CharonHostDevice
- (id)newComputePipelineStateWithFunction:(id<MTLFunction>)function error:(NSError **)error
{
    return [[CharonHostCharonMetalComputePipeline alloc] initWithFunction:function error:error];
}

- (id)computeCommandEncoder
{
    return [[CharonHostCharonMetalComputeEncoder alloc] init];
}
@end

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // The library whose kernels both sides run: compiled here by the same host Metal the oracle
        // used, so the AIR that came out of it is the AIR the tool was run over.
        NSString *source = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]
                                                encoding:NSUTF8StringEncoding error:NULL];
        if (source == nil) {
            fprintf(stderr, "harness: cannot read %s\n", argv[1]);
            return 2;
        }
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSError *error = nil;
        // The SAME compilation as the oracle's serialised library: MTLLibraryTypeDynamic and no
        // explicit language version, so both sides take the default a dynamic library gets on this
        // toolchain and the two answers are about one kernel under one compilation.
        // The SAME compilation as the oracle's DISPATCH library, and ORDINARY: a function of an
        // MTLLibraryTypeDynamic library can only be LINKED into another pipeline, and
        // -newComputePipelineStateWithFunction: asserts `type is not a valid MTLFunctionType` on one.
        // That is why the oracle compiles the source twice - once ordinary to dispatch, once dynamic
        // to serialise - and why this is the ordinary one.
        MTLCompileOptions *options = [MTLCompileOptions new];
        // MSL 4.1, PINNED on both sides of the differential, and pinned because an UNSET version
        // comes from the calling binary's deployment target: the oracle is linked at minos 27.0 and
        // the harness at 15.0, so the two defaulted to different languages and the same source
        // compiled on one side and not the other. Measured, on the fixture:
        //   3.0 196608 refused   3.1 196609 refused   3.2 196610 refused
        //   4.0 262144 refused   4.1 262145 COMPILES   5.0 327680 refused
        // with "no matching function for call to 'atomic_fetch_add_explicit'" on every refusal - the
        // threadgroup family takes a mem_flags argument only from 4.1 on. 4.1 is the LOWEST that
        // accepts the fixture, and a differential compares one kernel under one compilation.
        options.languageVersion = (MTLLanguageVersion)(4 << 16) + 1;

        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
        if (library == nil) {
            fprintf(stderr, "harness: the source does not compile: %s\n", error.localizedDescription.UTF8String);
            return 2;
        }
        printf("kernels=%lu\n", (unsigned long)[[library functionNames] count]);

        CharonHostDevice *port = [CharonHostDevice new];
        // One row per NAME: a library can hold a specialised and a general copy of the same kernel,
        // and printing both would answer for it twice, which compare.py now fails on.
        NSMutableSet *printed = [NSMutableSet set];
        for (NSString *name in [library functionNames]) {
            if ([printed containsObject:name])
                continue;
            id<MTLFunction> function = [library newFunctionWithName:name];
            if (!function)
                continue;
            [printed addObject:name];
            NSError *pipelineError = nil;
            id pipeline = [port newComputePipelineStateWithFunction:function error:&pipelineError];
            if (pipeline == nil) {
                // The port refused the kernel, and it says why. This is the answer an MPS class gets.
                fprintf(stderr, "refused %s: %s\n", name.UTF8String,
                        pipelineError.localizedDescription.UTF8String);
                continue;
            }
            // A fresh buffer, seeded the way the oracle seeds it, so the answer is the kernel's.
            // 32 cells, which is what the fixtures write - see oracle.m.
            const NSUInteger count = 64;   // as oracle.m
            float *seed = calloc(count, sizeof(float));
            // 1, 1, 2, 2, 3, 3 ... the same seed as oracle.m, so a > b and a >= b differ for half
            // the threads and a comparison table that swaps one for the other is visible
            for (NSUInteger index = 0; index < count; index++)
                seed[index] = (float)(index / 2 + 1);
            // The SENTINEL, 0xDEADBEEF in every cell: a cell the kernel did not write reads
            // deadbeef on both sides, and a cell the kernel wrote with the wrong value reads something
            // else. The seed is NOT what the kernel is given - a kernel that reads what it did not
            // write must read the sentinel, not a plausible number that could hide a missing store.
            uint8_t *filled = malloc(count * sizeof(float));
            // 1.0f, 2.0f, 3.0f ... as bits. A sum of sixteen small integers is EXACT in a float, so a
            // kernel that sums a buffer reports the sum and not the order it added in - which is what
            // 0xDEADBEEF failed to do, since it is -6.26e18 and sixteen of them are denormals.
            for (NSUInteger index = 0; index < count; index++)
                ((uint32_t *)filled)[index] = 0x3F800000u + (uint32_t)index;
            CharonHostCharonMetalBuffer *buffer =
                [[CharonHostCharonMetalBuffer alloc] initWithLength:count * sizeof(float) bytes:filled];

            CharonHostCharonMetalComputeEncoder *encoder = [port computeCommandEncoder];
            [encoder setComputePipelineState:pipeline];
            // The offset is exercised, not assumed: a binding at 0 and one that leaves room for the
            // kernel's own indexing are the same case, and the harness uses the plain one.
            [encoder setBuffer:buffer offset:0 atIndex:0];
            // atomicFamilyKernel names a second buffer, and the oracle binds one for it: a kernel
            // that names buffer(1) with nothing bound to it reads a null pointer, which is what the
            // harness's segfault was - the port refusing nothing and the harness binding less than
            // Metal does.
            CharonHostCharonMetalBuffer *second = NULL;
            if ([name isEqualToString:@"atomicFamilyKernel"]) {
                int *signedValues = malloc(count * sizeof(int));
                memset(signedValues, 0xA5, count * sizeof(int));
                second = [[CharonHostCharonMetalBuffer alloc] initWithLength:count * sizeof(int)
                                                                     bytes:signedValues];
                [encoder setBuffer:second offset:0 atIndex:1];
            }
            [encoder setThreadgroupMemoryLength:256 atIndex:0];
            MTLSize threads = MTLSizeMake(16, 1, 1);
            if ([name isEqualToString:@"grid2Kernel"])
                threads = MTLSizeMake(8, 2, 1);
            else if ([name isEqualToString:@"grid3Kernel"])
                threads = MTLSizeMake(2, 2, 2);
            else if ([name isEqualToString:@"atomicFamilyKernel"])
                threads = MTLSizeMake(8, 1, 1);
            else if ([name isEqualToString:@"atomicFamilyKernelProbe"])
                threads = MTLSizeMake(8, 1, 1);
            else if ([name isEqualToString:@"blockProbe"])
                threads = MTLSizeMake(8, 1, 1);
            else if ([name isEqualToString:@"shareProbe"])
                threads = MTLSizeMake(8, 1, 1);
            else if ([name isEqualToString:@"readbackProbe"])
                threads = MTLSizeMake(8, 1, 1);
            else if ([name isEqualToString:@"argNoBar"] || [name isEqualToString:@"argBarrier"] || [name isEqualToString:@"localArray"])
                threads = MTLSizeMake(1, 1, 1);
            else if ([name isEqualToString:@"positionKernel"])
                threads = MTLSizeMake(16, 1, 1);
            [encoder dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:threads];
            [encoder endEncoding];
            free(seed);

            // Printed as BIT PATTERNS, one word per cell, because the buffers are 32-bit integers and
            // the kernels' own values - a sum, a min, a compare-exchange's boolean - are integers, and
            // printing them as floats put them out at 1.4e-45 and invited a decode that had to be
            // undone by hand. A sentinel cell reads deadbeef here and a written one its own value.
            printf("OUT %s", name.UTF8String);
            const uint32_t *out = buffer.bytes;
            for (NSUInteger index = 0; index < count; index++)
                printf(" %08x", out[index]);
            printf("\n");
        }
    }
    return 0;
}
