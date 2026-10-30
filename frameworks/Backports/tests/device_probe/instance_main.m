#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdlib.h>
#include <string.h>

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    [REVENANT_LOG appendFormat:@"%@ %@\n", ok ? @"PASS" : @"FAIL", name];
}

static const float REVENANT_CORNERS[8] = {0.0f, -1.0f, 0.0f, 1.0f, 1.0f, -1.0f, 1.0f, 1.0f};
static const uint16_t REVENANT_INDICES[4] = {0, 1, 2, 3};

static id<MTLRenderPipelineState> revenant_pipeline(id<MTLDevice> device)
{
    NSError *error = nil;
    id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:@"/var/revenant/instance/instance.metallib"] error:&error];
    id<MTLFunction> vertex = [library newFunctionWithName:@"instance_column_vertex"];
    id<MTLFunction> fragment = [library newFunctionWithName:@"instance_column_fragment"];
    if (!vertex || !fragment) {
        [REVENANT_LOG appendFormat:@"INFO no instance functions in the library: %@\n", error];
        return nil;
    }
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = vertex;
    descriptor.fragmentFunction = fragment;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipeline)
        [REVENANT_LOG appendFormat:@"INFO the instance pipeline did not link: %@\n", error];
    return pipeline;
}

static id<MTLTexture> revenant_target(id<MTLDevice> device)
{
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:3 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget;
    return [device newTextureWithDescriptor:descriptor];
}

static void revenant_draw(id<MTLDevice> device, id<MTLRenderPipelineState> pipeline, id<MTLTexture> target, NSUInteger instances, BOOL indexed)
{
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLBuffer> corners = [device newBufferWithBytes:REVENANT_CORNERS length:sizeof REVENANT_CORNERS options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> buffer = [[device newCommandQueue] commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    [encoder setVertexBuffer:corners offset:0 atIndex:0];
    if (indexed) {
        id<MTLBuffer> indices = [device newBufferWithBytes:REVENANT_INDICES length:sizeof REVENANT_INDICES options:MTLResourceStorageModeShared];
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangleStrip indexCount:4 indexType:MTLIndexTypeUInt16 indexBuffer:indices indexBufferOffset:0 instanceCount:instances];
    } else {
        [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:instances];
    }
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
}

static NSUInteger revenant_mismatches(id<MTLTexture> texture, const uint8_t expected[12])
{
    uint8_t bytes[3 * 4];
    [texture getBytes:bytes bytesPerRow:12 fromRegion:MTLRegionMake2D(0, 0, 3, 1) mipmapLevel:0];
    NSUInteger bad = 0;
    for (NSUInteger i = 0; i < sizeof bytes; i++)
        if (bytes[i] != expected[i])
            bad++;
    if (bad)
        [REVENANT_LOG appendFormat:@"INFO columns read (%u,%u,%u,%u) (%u,%u,%u,%u) (%u,%u,%u,%u)\n",
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11]];
    return bad;
}

static void revenant_instance_checks(id<MTLDevice> device)
{
    id<MTLRenderPipelineState> pipeline = revenant_pipeline(device);
    revenant_check(pipeline != nil, @"the translated instance shaders link as a render pipeline");
    if (!pipeline)
        return;

    const uint8_t three[12] = {1, 0, 0, 255, 2, 0, 0, 255, 3, 0, 0, 255};
    id<MTLTexture> target = revenant_target(device);
    revenant_draw(device, pipeline, target, 3, NO);
    revenant_check(revenant_mismatches(target, three) == 0, @"a 3-instance draw writes instance ids 0, 1, 2 in order, one column each");

    const uint8_t one[12] = {1, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0};
    target = revenant_target(device);
    revenant_draw(device, pipeline, target, 1, NO);
    revenant_check(revenant_mismatches(target, one) == 0, @"a 1-instance draw writes instance id 0 only");

    target = revenant_target(device);
    revenant_draw(device, pipeline, target, 3, YES);
    revenant_check(revenant_mismatches(target, three) == 0, @"an indexed 3-instance draw writes the same three columns in order");
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        REVENANT_LOG = [NSMutableString string];
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        revenant_check(device != nil, @"MTLCreateSystemDefaultDevice returns a device");
        if (device)
            revenant_instance_checks(device);
        [REVENANT_LOG appendFormat:@"REVENANT-DONE failures %lu\n", (unsigned long)REVENANT_FAILURES];
        [REVENANT_LOG writeToFile:@"/var/revenant/instance-probe.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("%s", [REVENANT_LOG UTF8String]);
        return REVENANT_FAILURES ? 1 : 0;
    }
}
