#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Metal/MTLBinaryArchive.h>
#import <Metal/MTLDynamicLibrary.h>
#import <Metal/MTLFunctionDescriptor.h>
#import <Metal/MTLComputeCommandEncoder.h>
#import <Metal/MTLComputePipeline.h>

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
    compiled = [device newLibraryWithSource:source options:nil error:&error];
    if (compiled == nil) {
        fprintf(stderr, "REFUSED the source: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    printf("DISPATCH LIBRARY with %lu functions\n",
           (unsigned long)[[compiled functionNames] count]);
    MTLCompileOptions *options = [MTLCompileOptions new];
    options.libraryType = MTLLibraryTypeDynamic;
    options.installName = @"revenant.air2cpu.oracle";
    options.languageVersion = (MTLLanguageVersion)(4 << 16) + 1;
    id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
    if (library == nil) {
        fprintf(stderr, "REFUSED the source as a dynamic library: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    printf("COMPILED %lu functions: %s\n", (unsigned long)[[library functionNames] count],
           [[library functionNames] componentsJoinedByString:@", "].UTF8String);

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


        id<MTLLibrary> library = compiled;
        const NSUInteger count = 64;

        NSError *error = nil;

        for (NSString *name in [library functionNames]) {
            id<MTLFunction> function = [library newFunctionWithName:name];
            id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
            if (pipeline == nil) {
                fprintf(stderr, "no pipeline for %s: %s\n", name.UTF8String, error.localizedDescription.UTF8String);
                continue;
            }
            float *seed = calloc(count, sizeof(float));
            for (NSUInteger index = 0; index < count; index++)
                seed[index] = (float)(index / 2 + 1);
            id<MTLBuffer> one = [device newBufferWithLength:count * sizeof(float) options:MTLResourceStorageModeShared];
            for (NSUInteger index = 0; index < count; index++)
                ((uint32_t *)one.contents)[index] = 0x3F800000u + (uint32_t)index;
            {
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
            if ([name isEqualToString:@"atomicFamilyKernel"]) {
                id<MTLBuffer> second = [device newBufferWithLength:count * sizeof(int)
                                                     options:MTLResourceStorageModeShared];
                    [blit setBuffer:second offset:0 atIndex:1];
            }
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
            printf("OUT %s", name.UTF8String);
            for (NSUInteger index = 0; index < count; index++)
                printf(" %08x", ((const uint32_t *)out)[index]);
            printf("\n");
            free(seed);
        }
    }
    return 0;
}
