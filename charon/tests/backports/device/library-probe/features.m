#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

int main(int argc, const char *argv[])
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        printf("device.present=%d\n", device != nil);
        if (!device)
            return 2;
        printf("device.name=%s\n", [[device name] UTF8String]);
        printf("device.supportsRaytracing=%d\n", (int)[device supportsRaytracing]);
        printf("device.supportsFamilyApple7=%d\n", [device supportsFamily:MTLGPUFamilyApple7]);
        printf("device.supportsFamilyMac1=%d\n", [device supportsFamily:MTLGPUFamilyMac1]);
        MTLSize tile = [device sparseTileSizeWithTextureType:MTLTextureType2D
                                                 pixelFormat:MTLPixelFormatRGBA8Unorm
                                                 sampleCount:1];
        printf("device.sparseTileSize=%lux%lux%lu\n", (unsigned long)tile.width,
               (unsigned long)tile.height, (unsigned long)tile.depth);

        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> buffer = [queue commandBuffer];
        id<MTLAccelerationStructureCommandEncoder> accel = [buffer accelerationStructureCommandEncoder];
        printf("factory.accelerationStructureCommandEncoder.present=%d\n", accel != nil);
        [accel endEncoding];

        MTLResourceStatePassDescriptor *pass = [MTLResourceStatePassDescriptor resourceStatePassDescriptor];
        id<MTLResourceStateCommandEncoder> state = [buffer resourceStateCommandEncoderWithDescriptor:pass];
        printf("factory.resourceStateCommandEncoderWithDescriptor.present=%d\n", state != nil);
        [state endEncoding];
        [buffer commit];
        [buffer waitUntilCompleted];

        if (argc > 1) {
            NSError *error = nil;
            NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
            id<MTLLibrary> library = [device newLibraryWithURL:url error:&error];
            printf("library.present=%d\n", library != nil);
            if (library) {
                MTLIntersectionFunctionDescriptor *descriptor = [[MTLIntersectionFunctionDescriptor alloc] init];
                descriptor.name = @"composite";
                NSError *intersectionError = nil;
                id<MTLFunction> function = [library newFunctionWithDescriptor:descriptor error:&intersectionError];
                printf("intersection.function.present=%d\n", function != nil);
                printf("intersection.error=%s\n",
                       intersectionError ? [[intersectionError localizedDescription] UTF8String] : "(nil)");
            }
        }
    }
    return 0;
}
