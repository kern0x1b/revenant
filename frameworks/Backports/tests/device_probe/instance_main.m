#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <math.h>
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

static id<MTLRenderPipelineState> revenant_pipeline(id<MTLDevice> device, NSString *vertexName, NSString *fragmentName)
{
    NSError *error = nil;
    id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:@"/var/revenant/instance/instance.metallib"] error:&error];
    id<MTLFunction> vertex = [library newFunctionWithName:vertexName];
    id<MTLFunction> fragment = [library newFunctionWithName:fragmentName];
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

// The element draw binds the corners at 0, the quads at 1, the frame at 2 and the pick at 3. The quad of each instance
// is its own element, so the instance count sets how many elements are read.
static void revenant_element_draw(id<MTLDevice> device, id<MTLRenderPipelineState> pipeline, id<MTLTexture> target, NSUInteger instances, const float quads[24], const float frame[12], int pick)
{
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLBuffer> corners = [device newBufferWithBytes:REVENANT_CORNERS length:sizeof REVENANT_CORNERS options:MTLResourceStorageModeShared];
    id<MTLBuffer> quadBuffer = [device newBufferWithBytes:quads length:24 * sizeof(float) options:MTLResourceStorageModeShared];
    id<MTLBuffer> frameBuffer = [device newBufferWithBytes:frame length:12 * sizeof(float) options:MTLResourceStorageModeShared];
    id<MTLBuffer> pickBuffer = [device newBufferWithBytes:&pick length:sizeof pick options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> buffer = [[device newCommandQueue] commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    [encoder setVertexBuffer:corners offset:0 atIndex:0];
    [encoder setVertexBuffer:quadBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:frameBuffer offset:0 atIndex:2];
    [encoder setVertexBuffer:pickBuffer offset:0 atIndex:3];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:instances];
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
}

static void revenant_element_checks(id<MTLDevice> device)
{
    id<MTLRenderPipelineState> pipeline = revenant_pipeline(device, @"element_column_vertex", @"element_column_fragment");
    revenant_check(pipeline != nil, @"the translated element shaders link as a render pipeline");
    if (!pipeline)
        return;

    // Instance i has tint (1,0,0), (0,1,0), (0,0,1) in its x, y and z. The color of a column is (tint.x, gain[pick].y, tint.z),
    // so gain[1].y = 1 is the only green, and the blue of column 2 comes from its own element.
    const float quads[24] = {0, 0, 0, 0, 1, 0, 0, 1,  0, 0, 0, 0, 0, 1, 0, 1,  0, 0, 0, 0, 0, 0, 1, 1};
    const float frame[12] = {0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1};
    const uint8_t lit[12] = {255, 255, 0, 255, 0, 255, 0, 255, 0, 255, 255, 255};
    id<MTLTexture> target = revenant_target(device);
    revenant_element_draw(device, pipeline, target, 3, quads, frame, 1);
    revenant_check(revenant_mismatches(target, lit) == 0, @"an instanced draw reads each instance's element and picks gain[1] for pick 1");

    const uint8_t dark[12] = {255, 0, 0, 255, 0, 0, 0, 255, 0, 0, 255, 255};
    target = revenant_target(device);
    revenant_element_draw(device, pipeline, target, 3, quads, frame, 2);
    revenant_check(revenant_mismatches(target, dark) == 0, @"pick 2 picks gain[2], so the green of every column is 0");

    const uint8_t first[12] = {255, 255, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0};
    target = revenant_target(device);
    revenant_element_draw(device, pipeline, target, 1, quads, frame, 1);
    revenant_check(revenant_mismatches(target, first) == 0, @"a 1-instance draw reads element 0 only");
}

// The matrix frame as Metal lays it out: model and projection as column-major float4x4, then a float3x3 whose three columns
// are each padded to four floats.
static const float REVENANT_MATRIX_FRAME[44] = {
    1, 0, 2, 0,  0, 3, 0, 1,  4, 0, 1, 0,  0, 2, 0, 1,
    1, 1, 0, 0,  0, 2, 5, 1,  3, 0, 1, 0,  0, 0, 2, 1,
    1, 2, 0, 0,  0, 1, 3, 0,  2, 4, 1, 0};

// The reference product of the shader, with the same column-major reading as Metal: out[r] = sum over c of m[c][r] * v[c].
static void revenant_multiply(const float *m, const float *v, float *out)
{
    for (int r = 0; r < 4; r++) {
        out[r] = 0;
        for (int c = 0; c < 4; c++)
            out[r] += m[c * 4 + r] * v[c];
    }
}

// The bytes the matrix draw must write into each of its three pixels: the products x and y, model[3][1] and normal[2][1].
static void revenant_matrix_expected(const float *frame, uint8_t expected[12])
{
    float v[4] = {1, 2, 3, 1}, mv[4], p[4];
    revenant_multiply(frame, v, mv);
    revenant_multiply(frame + 16, mv, p);
    uint8_t pixel[4] = {(uint8_t)lrintf(p[0]), (uint8_t)lrintf(p[1]), (uint8_t)lrintf(frame[13]), (uint8_t)lrintf(frame[41])};
    memcpy(expected, pixel, sizeof pixel);
    memcpy(expected + 4, pixel, sizeof pixel);
    memcpy(expected + 8, pixel, sizeof pixel);
}

// The same matrices stored transposed, which is the layout error the matrix check must catch.
static void revenant_matrix_transposed(const float *frame, float *out)
{
    memset(out, 0, 44 * sizeof(float));
    for (int c = 0; c < 4; c++)
        for (int r = 0; r < 4; r++) {
            out[c * 4 + r] = frame[r * 4 + c];
            out[16 + c * 4 + r] = frame[16 + r * 4 + c];
        }
    for (int c = 0; c < 3; c++)
        for (int r = 0; r < 3; r++)
            out[32 + c * 4 + r] = frame[32 + r * 4 + c];
}

static void revenant_matrix_draw(id<MTLDevice> device, id<MTLRenderPipelineState> pipeline, id<MTLTexture> target, const float *frame)
{
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = target;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLBuffer> corners = [device newBufferWithBytes:REVENANT_CORNERS length:sizeof REVENANT_CORNERS options:MTLResourceStorageModeShared];
    id<MTLBuffer> frameBuffer = [device newBufferWithBytes:frame length:44 * sizeof(float) options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> buffer = [[device newCommandQueue] commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:pipeline];
    [encoder setVertexBuffer:corners offset:0 atIndex:0];
    [encoder setVertexBuffer:frameBuffer offset:0 atIndex:1];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:3];
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
}

static void revenant_matrix_checks(id<MTLDevice> device)
{
    id<MTLRenderPipelineState> pipeline = revenant_pipeline(device, @"matrix_column_vertex", @"matrix_column_fragment");
    revenant_check(pipeline != nil, @"the translated matrix shaders link as a render pipeline");
    if (!pipeline)
        return;

    uint8_t expected[12];
    revenant_matrix_expected(REVENANT_MATRIX_FRAME, expected);
    id<MTLTexture> target = revenant_target(device);
    revenant_matrix_draw(device, pipeline, target, REVENANT_MATRIX_FRAME);
    revenant_check(revenant_mismatches(target, expected) == 0, @"model and projection multiply a known vector in column-major order, and the element reads match the reference");

    float transposed[44];
    revenant_matrix_transposed(REVENANT_MATRIX_FRAME, transposed);
    target = revenant_target(device);
    revenant_matrix_draw(device, pipeline, target, transposed);
    revenant_check(revenant_mismatches(target, expected) > 0, @"negative control: the transposed matrices fail the same reference");
}

static void revenant_instance_checks(id<MTLDevice> device)
{
    id<MTLRenderPipelineState> pipeline = revenant_pipeline(device, @"instance_column_vertex", @"instance_column_fragment");
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
        if (device) {
            revenant_instance_checks(device);
            revenant_element_checks(device);
            revenant_matrix_checks(device);
        }
        [REVENANT_LOG appendFormat:@"REVENANT-DONE failures %lu\n", (unsigned long)REVENANT_FAILURES];
        [REVENANT_LOG writeToFile:@"/var/revenant/instance-probe.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("%s", [REVENANT_LOG UTF8String]);
        return REVENANT_FAILURES ? 1 : 0;
    }
}
