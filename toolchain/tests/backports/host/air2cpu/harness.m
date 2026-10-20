#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "../../../../packages/frameworks/apple-backports/air2cpu-abi.h"

@interface RevenantHostRevenantMetalBuffer : NSObject
- (instancetype)initWithLength:(NSUInteger)length bytes:(const void *)bytes;
- (void *)bytes;
- (NSUInteger)length;
@end

@interface RevenantHostRevenantMetalComputePipeline : NSObject
- (instancetype)initWithFunction:(id<MTLFunction>)function error:(NSError **)error;
- (id)revenantKernelFunction;
- (uint32_t)revenantBlockBytes;
- (uint32_t)revenantThreads;
@end

@interface RevenantHostRevenantMetalComputeEncoder : NSObject
- (void)setComputePipelineState:(id)pipeline;
- (void)setBuffer:(id)buffer offset:(NSUInteger)offset atIndex:(NSUInteger)index;
- (void)setBytes:(const void *)bytes length:(NSUInteger)length atIndex:(NSUInteger)index;
- (void)setThreadgroupMemoryLength:(NSUInteger)length atIndex:(NSUInteger)index;
- (void)dispatchThreadgroups:(MTLSize)groups threadsPerThreadgroup:(MTLSize)threads;
- (void)endEncoding;
@end

@interface RevenantHostDevice : NSObject
- (id)newComputePipelineStateWithFunction:(id<MTLFunction>)function error:(NSError **)error;
- (id)computeCommandEncoder;
@end

@implementation RevenantHostDevice
- (id)newComputePipelineStateWithFunction:(id<MTLFunction>)function error:(NSError **)error
{
    return [[RevenantHostRevenantMetalComputePipeline alloc] initWithFunction:function error:error];
}

- (id)computeCommandEncoder
{
    return [[RevenantHostRevenantMetalComputeEncoder alloc] init];
}
@end

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSString *source = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]
                                                encoding:NSUTF8StringEncoding error:NULL];
        if (source == nil) {
            fprintf(stderr, "harness: cannot read %s\n", argv[1]);
            return 2;
        }
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSError *error = nil;
        MTLCompileOptions *options = [MTLCompileOptions new];
        options.languageVersion = (MTLLanguageVersion)(4 << 16) + 1;

        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
        if (library == nil) {
            fprintf(stderr, "harness: the source does not compile: %s\n", error.localizedDescription.UTF8String);
            return 2;
        }
        printf("kernels=%lu\n", (unsigned long)[[library functionNames] count]);

        RevenantHostDevice *port = [RevenantHostDevice new];
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
                fprintf(stderr, "refused %s: %s\n", name.UTF8String,
                        pipelineError.localizedDescription.UTF8String);
                continue;
            }
            const NSUInteger count = 64;
            float *seed = calloc(count, sizeof(float));
            for (NSUInteger index = 0; index < count; index++)
                seed[index] = (float)(index / 2 + 1);
            uint8_t *filled = malloc(count * sizeof(float));
            for (NSUInteger index = 0; index < count; index++)
                ((uint32_t *)filled)[index] = 0x3F800000u + (uint32_t)index;
            RevenantHostRevenantMetalBuffer *buffer =
                [[RevenantHostRevenantMetalBuffer alloc] initWithLength:count * sizeof(float) bytes:filled];

            RevenantHostRevenantMetalComputeEncoder *encoder = [port computeCommandEncoder];
            [encoder setComputePipelineState:pipeline];
            [encoder setBuffer:buffer offset:0 atIndex:0];
            RevenantHostRevenantMetalBuffer *second = NULL;
            if ([name isEqualToString:@"atomicFamilyKernel"]) {
                int *signedValues = malloc(count * sizeof(int));
                memset(signedValues, 0xA5, count * sizeof(int));
                second = [[RevenantHostRevenantMetalBuffer alloc] initWithLength:count * sizeof(int)
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

            printf("OUT %s", name.UTF8String);
            const uint32_t *out = buffer.bytes;
            for (NSUInteger index = 0; index < count; index++)
                printf(" %08x", out[index]);
            printf("\n");
        }
    }
    return 0;
}
