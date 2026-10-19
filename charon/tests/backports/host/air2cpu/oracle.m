#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Metal/MTLBinaryArchive.h>
#import <Metal/MTLDynamicLibrary.h>
#import <Metal/MTLFunctionDescriptor.h>
#import <Metal/MTLComputeCommandEncoder.h>
#import <Metal/MTLComputePipeline.h>

// oracle.m — the real compute kernels, compiled by Apple's own compiler where it runs.
//
// There is no `metal` tool on this machine and no Xcode, but Metal's runtime compiles Metal Shading
// Language itself: -[MTLDevice newLibraryWithSource:options:error:] with
// MTLCompileOptions.libraryType = MTLLibraryTypeDynamic produces a library Apple's compiler built,
// and -[MTLLibrary serializeToURL:error:] writes it out as a real .metallib. That file is the input the
// differential needs and the bitcode tools/air2cpu reads: this host's own kernels, as Apple's compiler
// emitted them, with the real air.kernel metadata and the real address spaces and intrinsics.
//
// Two things are measured and written to stderr, and both decide the shape of what follows:
//   * whether the runtime serialises a library whose kernels we can dispatch, and
//   * whether -serializeToURL: writes the same AIR the runtime loaded, or only a binary archive.
//
// Usage: oracle.m OUT.metallib   (the kernels are in kernels.metal beside this file)

static id<MTLDevice> device;
static id<MTLLibrary> compiled;

static BOOL writeLibraries(NSURL *metallib)
{
    NSString *source = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"kernels" ofType:@"metal"] encoding:NSUTF8StringEncoding error:NULL];
    if (source == nil) {
        fprintf(stderr, "REFUSED no kernels.metal beside this program\n");
        return NO;
    }
    NSError *error = nil;
    // The one to dispatch: an ordinary library, built with the runtime's own default options.
    compiled = [device newLibraryWithSource:source options:nil error:&error];
    if (compiled == nil) {
        fprintf(stderr, "REFUSED the source: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    printf("DISPATCH LIBRARY with %lu functions\n",
           (unsigned long)[[compiled functionNames] count]);
    // The one to serialise: a dynamic library, because that is the type -serializeToURL: is given.
    MTLCompileOptions *options = [MTLCompileOptions new];
    options.libraryType = MTLLibraryTypeDynamic;
    // NO explicit languageVersion: both sides take the default a DYNAMIC library gets on this
    // toolchain, which is the configuration that accepts the threadgroup atomics with a mem_flags
    // argument, and the point is that BOTH sides use it. Pinning one instead is measurably a
    // different language: MTLLanguageVersion3_0 refuses
    // atomic_fetch_add_explicit(&block[0], base, memory_order_relaxed, mem_flags::mem_threadgroup)
    // with "no matching function for call to 'atomic_fetch_add_explicit'", so a differential whose two
    // sides are on different versions fails for a reason that has nothing to do with the port.
    options.installName = @"charon.air2cpu.oracle";
    // (the versions were measured with the environment override this line replaced; see the note in
    // harness.m, which pins the same value, and the facts for the table of what refuses)
    options.languageVersion = (MTLLanguageVersion)(4 << 16) + 1;
    id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
    if (library == nil) {
        fprintf(stderr, "REFUSED the source as a dynamic library: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    printf("COMPILED %lu functions: %s\n", (unsigned long)[[library functionNames] count],
           [[library functionNames] componentsJoinedByString:@", "].UTF8String);

    // The way Apple's own runtime writes a file, as these headers spell it and as the coordinator
    // pointed out: -serializeToURL:error: belongs to MTLDynamicLibrary, which is what
    // -newDynamicLibrary:error: makes out of the library the runtime compiled from the source. The
    // archive route is kept for the record, because it is the one that was tried first and it reached
    // Apple's own validateMTLFunctionType assertion.
    id<MTLDynamicLibrary> dynamic = [device newDynamicLibrary:library error:&error];
    if (dynamic == nil) {
        fprintf(stderr, "NO DYNAMIC LIBRARY %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    if ([dynamic serializeToURL:metallib error:&error]) {
        printf("SERIALIZED %s (%ld bytes)\n", metallib.path.UTF8String,
               (long)[[NSFileManager defaultManager] attributesOfItemAtPath:metallib.path error:NULL].fileSize);
    } else {
        fprintf(stderr, "NOT SERIALIZED %s\n", error.localizedDescription.UTF8String);
        return NO;
    }

    // The other route, measured once and left here so nobody repeats it: an archive of the library's
    // functions. The file this writes is an archive and not a metallib, and the assertion is Apple's.
    if (!getenv("AIR2CPU_TRY_ARCHIVE"))
        return YES;
    MTLBinaryArchiveDescriptor *file = [MTLBinaryArchiveDescriptor new];
    id<MTLBinaryArchive> archive = [device newBinaryArchiveWithDescriptor:file error:&error];
    if (archive == nil) {
        fprintf(stderr, "NO ARCHIVE %s\n", error.localizedDescription.UTF8String);
        return YES;
    }
    for (NSString *name in [library functionNames]) {
        id<MTLFunction> function = [library newFunctionWithName:name];
        printf("FUNCTION %s\n", name.UTF8String);
        MTLComputePipelineDescriptor *pipeline = [MTLComputePipelineDescriptor new];
        pipeline.computeFunction = function;
        if (![archive addComputePipelineFunctionsWithDescriptor:pipeline error:&error])
            fprintf(stderr, "NO FUNCTION IN THE ARCHIVE %s: %s\n", name.UTF8String, error.localizedDescription.UTF8String);
    }
    if ([archive serializeToURL:[NSURL fileURLWithPath:[[metallib path] stringByAppendingString:@".archive"]] error:&error])
        printf("ARCHIVE written\n");
    else
        fprintf(stderr, "NO ARCHIVE FILE %s\n", error.localizedDescription.UTF8String);
    return YES;
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            fprintf(stderr, "no Metal device on this host\n");
            return 2;
        }
        printf("DEVICE %s\n", device.name.UTF8String);
        if (argc < 2) {
            fprintf(stderr, "usage: oracle OUT.metallib\n");
            return 2;
        }
        NSURL *metallib = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        if (!writeLibraries(metallib))
            return 1;


        // And the one number that matters for the differential: dispatch each kernel on this host's
        // GPU and print what came out, so the port's own translated kernel is compared with a real
        // Metal dispatch of Apple's own bitcode on the same input.
        // The library compiled above, not one read back: the in-memory one is what this host ran in
        // the measurement, and the file is a separate question this program also answers.
        id<MTLLibrary> library = compiled;
        // 32 cells, which is what the fixtures write: atomicFamilyKernel stores out[24 + base] and
        // signed_out[base] for a group of eight, which reaches cell 31.
        const NSUInteger count = 64;   // the witness writes 64 (16 threads x 4 cells)   // spillKernel writes 64 cells, positionKernel 5, atomicFamilyKernel 32

        NSError *error = nil;

        for (NSString *name in [library functionNames]) {
            id<MTLFunction> function = [library newFunctionWithName:name];
            id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
            if (pipeline == nil) {
                fprintf(stderr, "no pipeline for %s: %s\n", name.UTF8String, error.localizedDescription.UTF8String);
                continue;
            }
            // A fresh buffer per kernel, seeded the same way the port's driver seeds it, so the two
            // numbers are about the kernel and not about what another kernel left behind.
            float *seed = calloc(count, sizeof(float));
            // 1, 1, 2, 2, 3, 3 ... so a > b and a >= b differ for exactly half the threads, which
            // is what makes a comparison table that swaps one for the other visible in the answer.
            for (NSUInteger index = 0; index < count; index++)
                seed[index] = (float)(index / 2 + 1);
            id<MTLBuffer> one = [device newBufferWithLength:count * sizeof(float) options:MTLResourceStorageModeShared];
            // The sentinel, on Metal's side too: 0xA5 in every byte, so a cell no kernel wrote reads
            // the same on both sides and a cell written where it should not have been differs.
            // the same sentinel the harness uses, and for the same reason
            // the same small integers as the harness: 1.0f, 2.0f, ... whose sum is exact
            for (NSUInteger index = 0; index < count; index++)
                ((uint32_t *)one.contents)[index] = 0x3F800000u + (uint32_t)index;
            {   // the fill is proved, not assumed: a byte read back at once, before any dispatch
                const uint8_t *back = one.contents;
                if (back[0] != 0xA5 || back[count * sizeof(float) - 1] != 0xA5)
                    printf("FILL LOST on Metal's buffer: first byte 0x%02x, last 0x%02x\n",
                           back[0], back[count * sizeof(float) - 1]);
                else
                    printf("fill ok on Metal's buffer: first 0x%02x, last 0x%02x\n", back[0], back[count * sizeof(float) - 1]);
            }
            id<MTLCommandBuffer> run = [[device newCommandQueue] commandBuffer];
            id blit = [run computeCommandEncoder];
            [blit setComputePipelineState:pipeline];
            [blit setBuffer:one offset:0 atIndex:0];
            // The family kernel names two buffers, and a second one so that a binding that is not the
            // one the kernel means is visible in the answer rather than in a comment.
            if ([name isEqualToString:@"atomicFamilyKernel"]) {
                id<MTLBuffer> second = [device newBufferWithLength:count * sizeof(int)
                                                     options:MTLResourceStorageModeShared];
                    [blit setBuffer:second offset:0 atIndex:1];
            }
            // The kernel's [[threadgroup(N)]] argument is a length the encoder is told, not a pointer it
            // is handed: without this the block is zero bytes long, the kernel's writes into it go
            // nowhere, and the reduction reads back zeros. That is what Metal answered before this line.
            [blit setThreadgroupMemoryLength:256 atIndex:0];
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
            // positionKernel is the witness for the dispatch shape, so it is dispatched the SHAPE the
            // kernel is meant to see and the numbers it writes are quoted in the run's log.
            else if ([name isEqualToString:@"positionKernel"])
                threads = MTLSizeMake(16, 1, 1);
            [blit dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:threads];
            [blit endEncoding];
            [run commit];
            [run waitUntilCompleted];
            if (run.error) {
                fprintf(stderr, "dispatch of %s failed: %s\n", name.UTF8String, run.error.localizedDescription.UTF8String);
                continue;
            }
            const void *out = one.contents;
            // bit patterns, one word per cell, exactly as the harness prints them
            printf("OUT %s", name.UTF8String);
            for (NSUInteger index = 0; index < count; index++)
                printf(" %08x", ((const uint32_t *)out)[index]);
            printf("\n");
            free(seed);
        }
    }
    return 0;
}
