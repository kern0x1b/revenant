#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
int main(void)
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = [device newCommandQueue];
        const NSUInteger n = 401, c = 200;
        static float px[401 * 401], out[401 * 401];
        MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float width:n height:n mipmapped:NO];
        td.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        td.storageMode = MTLStorageModeShared;
        id<MTLTexture> src = [device newTextureWithDescriptor:td];
        id<MTLTexture> dst = [device newTextureWithDescriptor:td];
        for (int k = 1; k <= 120; k++) {
            float sigma = k * 0.1f;
            memset(px, 0, sizeof px);
            px[c * n + c] = 1.0f;
            [src replaceRegion:MTLRegionMake2D(0, 0, n, n) mipmapLevel:0 withBytes:px bytesPerRow:n * 4];
            MPSImageGaussianBlur *blur = [[MPSImageGaussianBlur alloc] initWithDevice:device sigma:sigma];
            id<MTLCommandBuffer> cb = [queue commandBuffer];
            [blur encodeToCommandBuffer:cb sourceTexture:src destinationTexture:dst];
            [cb commit];
            [cb waitUntilCompleted];
            [dst getBytes:out bytesPerRow:n * 4 fromRegion:MTLRegionMake2D(0, 0, n, n) mipmapLevel:0];
            int half = 0;
            for (NSUInteger x = 0; x < n; x++)
                if (out[c * n + x] != 0.0f && (int)x - (int)c > half) half = (int)x - (int)c;
            printf("%.1f %d %.9g %.9g\n", sigma, half, out[c * n + c], out[c * n + c + half]);
        }
    }
    return 0;
}
