#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>

#pragma clang diagnostic ignored "-Wincompatible-pointer-types"

static void Report(const char *what, id object)
{
    printf("class %-22s %s\n", what, object ? [NSStringFromClass([object class]) UTF8String] : "(nil)");
}

@protocol CharonImageBytesFive <NSObject>
- (void)writeBytes:(const void *)dataBytes
        dataLayout:(MPSDataLayout)dataLayout
       bytesPerRow:(NSUInteger)bytesPerRow
            region:(MTLRegion)region
        imageIndex:(NSUInteger)imageIndex;
- (void)readBytes:(void *)dataBytes
       dataLayout:(MPSDataLayout)dataLayout
      bytesPerRow:(NSUInteger)bytesPerRow
           region:(MTLRegion)region
       imageIndex:(NSUInteger)imageIndex;
@end

#pragma mark - the images

static void FillImage(MPSImage *image, NSUInteger cols, NSUInteger rows, NSUInteger channels,
                      const float *values)
{
#ifdef CHARON_PORT_BUILD
    [(id<CharonImageBytesFive>)image writeBytes:values
                                    dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
                                   bytesPerRow:cols * channels * sizeof(float)
                                        region:MTLRegionMake3D(0, 0, 0, cols, rows, 1)
                                    imageIndex:0];
#else
    [image writeBytes:values
          dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
          imageIndex:0];
#endif
}

static MPSImage *MakeImage(id<MTLDevice> device, NSUInteger cols, NSUInteger rows, NSUInteger channels,
                           const float *values)
{
    MPSImageDescriptor *descriptor = [MPSImageDescriptor new];
    descriptor.width = cols;
    descriptor.height = rows;
    descriptor.featureChannels = channels;
    descriptor.numberOfImages = 1;
    descriptor.channelFormat = MPSImageFeatureChannelFormatFloat32;
    MPSImage *image = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
    FillImage(image, cols, rows, channels, values);
    return image;
}

static void PrintValues(const char *name, MPSImage *image, NSUInteger cols, NSUInteger rows,
                        NSUInteger channels)
{
    if (!image) {
        printf("case %-18s NIL\n", name);
        return;
    }
    NSUInteger count = cols * rows * channels;
    float values[256];
    if (count > 256) {
        printf("case %-18s too many values to print\n", name);
        return;
    }
#ifdef CHARON_PORT_BUILD
    [(id<CharonImageBytesFive>)image readBytes:values
                                   dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
                                  bytesPerRow:cols * channels * sizeof(float)
                                       region:MTLRegionMake3D(0, 0, 0, cols, rows, 1)
                                   imageIndex:0];
#else
    [image readBytes:values
         dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels
         imageIndex:0];
#endif
    printf("case %-18s %lux%lux%lu", name, (unsigned long)image.width, (unsigned long)image.height,
           (unsigned long)image.featureChannels);
    for (NSUInteger i = 0; i < count; i++)
        printf(" %g", values[i]);
    printf("\n");
}

static MPSImage *Run(id<MTLCommandQueue> queue, MPSNNGraph *graph, NSArray<MPSImage *> *sourceImages)
{
    graph.format = MPSImageFeatureChannelFormatFloat32;
    id<MTLCommandBuffer> buffer = [queue commandBuffer];
    MPSImage *result = [graph encodeToCommandBuffer:buffer sourceImages:sourceImages];
    [buffer commit];
    [buffer waitUntilCompleted];
    return result;
}

#pragma mark - the cases

static void Arithmetic(id<MTLDevice> device, id<MTLCommandQueue> queue, const char *name, int kind)
{
    static const float left[4] = {1, 2, 3, 4};
    static const float right[4] = {10, 20, 30, 40};
    MPSImage *a = MakeImage(device, 2, 2, 1, left);
    MPSImage *b = MakeImage(device, 2, 2, 1, right);
    MPSNNAdditionNode *addition = [MPSNNAdditionNode nodeWithLeftSource:[MPSNNImageNode nodeWithHandle:a]
                                                           rightSource:[MPSNNImageNode nodeWithHandle:b]];
    MPSNNFilterNode *node = nil;
    switch (kind) {
    case 1: node = [MPSNNSubtractionNode nodeWithLeftSource:[MPSNNImageNode nodeWithHandle:a]
                                               rightSource:[MPSNNImageNode nodeWithHandle:b]]; break;
    case 2: node = [MPSNNMultiplicationNode nodeWithLeftSource:[MPSNNImageNode nodeWithHandle:a]
                                                 rightSource:[MPSNNImageNode nodeWithHandle:b]]; break;
    case 3: node = [MPSNNDivisionNode nodeWithLeftSource:[MPSNNImageNode nodeWithHandle:a]
                                             rightSource:[MPSNNImageNode nodeWithHandle:b]]; break;
    default: node = addition; break;
    }
    if (kind == 0)
        Report("addition node", node);
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:node.resultImage resultImageIsNeeded:YES];
    Report("graph", graph);
    printf("walk  %-18s %lu source handles\n", name, (unsigned long)graph.sourceImageHandles.count);
    MPSImage *result = Run(queue, graph, @[a, b]);
    PrintValues(name, result, 2, 2, 1);
}

static void Chained(id<MTLDevice> device, id<MTLCommandQueue> queue, const char *name, int subtractSecond)
{
    static const float left[4] = {1, 2, 3, 4};
    static const float right[4] = {10, 20, 30, 40};
    MPSImage *a = MakeImage(device, 2, 2, 1, left);
    MPSImage *b = MakeImage(device, 2, 2, 1, right);
    MPSNNImageNode *an = [MPSNNImageNode nodeWithHandle:a];
    MPSNNImageNode *bn = [MPSNNImageNode nodeWithHandle:b];
    MPSNNAdditionNode *first = [MPSNNAdditionNode nodeWithLeftSource:an rightSource:bn];
    MPSNNFilterNode *second = subtractSecond
        ? [MPSNNSubtractionNode nodeWithLeftSource:first.resultImage rightSource:bn]
        : [MPSNNAdditionNode nodeWithLeftSource:first.resultImage rightSource:bn];
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:second.resultImage resultImageIsNeeded:YES];
    printf("walk  %-18s %lu source handles\n", name, (unsigned long)graph.sourceImageHandles.count);
    MPSImage *result = Run(queue, graph, @[a, b]);
    PrintValues(name, result, 2, 2, 1);
}

static void Scaled(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    static const float left[4] = {1, 2, 3, 4};
    static const float right[4] = {10, 20, 30, 40};
    MPSImage *a = MakeImage(device, 2, 2, 1, left);
    MPSImage *b = MakeImage(device, 2, 2, 1, right);
    MPSNNAdditionNode *node = [MPSNNAdditionNode nodeWithLeftSource:[MPSNNImageNode nodeWithHandle:a]
                                                        rightSource:[MPSNNImageNode nodeWithHandle:b]];
    node.primaryScale = 2.0f;
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:node.resultImage resultImageIsNeeded:YES];
    MPSImage *result = Run(queue, graph, @[a, b]);
    PrintValues("add-scaled", result, 2, 2, 1);
}

static void Concat(id<MTLDevice> device, id<MTLCommandQueue> queue, const char *name, NSUInteger channels)
{
    float values[4] = {1, 2, 3, 4};
    MPSImage *a = MakeImage(device, 1, 1, channels, values);
    MPSNNConcatenationNode *node = [MPSNNConcatenationNode nodeWithSources:@[[MPSNNImageNode nodeWithHandle:a]]];
    if (channels == 1)
        Report("concatenation node", node);
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:node.resultImage resultImageIsNeeded:YES];
    MPSImage *result = Run(queue, graph, @[a]);
    PrintValues(name, result, 1, 1, 4);
}

static void ConcatTwo(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    float left[2] = {1, 2};
    float right[2] = {5, 6};
    MPSImage *a = MakeImage(device, 1, 1, 1, left);
    MPSImage *b = MakeImage(device, 1, 1, 1, right);
    MPSNNConcatenationNode *node = [MPSNNConcatenationNode nodeWithSources:@[[MPSNNImageNode nodeWithHandle:a],
                                                                           [MPSNNImageNode nodeWithHandle:b]]];
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:node.resultImage resultImageIsNeeded:YES];
    MPSImage *result = Run(queue, graph, @[a, b]);
    PrintValues("concat-1+1-unholdable", result, 1, 1, 8);
}

static void Pooling(id<MTLDevice> device, id<MTLCommandQueue> queue, const char *name, int kind)
{
    static const float source[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    MPSImage *a = MakeImage(device, 3, 3, 1, source);
    MPSNNImageNode *an = [MPSNNImageNode nodeWithHandle:a];
    MPSNNFilterNode *node = kind
        ? (MPSNNFilterNode *)[MPSCNNPoolingMaxNode nodeWithSource:an filterSize:2 stride:1]
        : (MPSNNFilterNode *)[MPSCNNPoolingAverageNode nodeWithSource:an filterSize:2 stride:1];
    if (kind)
        Report("pooling max node", node);
    node.paddingPolicy = [MPSNNDefaultPadding paddingWithMethod:MPSNNPaddingMethodSizeSame];
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:node.resultImage resultImageIsNeeded:YES];
    MPSImage *result = Run(queue, graph, @[a]);
    if (!result) {
        printf("case %-18s NIL\n", name);
        return;
    }
    printf("case %-18s %lux%lux%lu\n", name, (unsigned long)result.width, (unsigned long)result.height,
           (unsigned long)result.featureChannels);
}

static void ResultNotNeeded(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    static const float left[4] = {1, 2, 3, 4};
    static const float right[4] = {10, 20, 30, 40};
    MPSImage *a = MakeImage(device, 2, 2, 1, left);
    MPSImage *b = MakeImage(device, 2, 2, 1, right);
    MPSNNAdditionNode *node = [MPSNNAdditionNode nodeWithLeftSource:[MPSNNImageNode nodeWithHandle:a]
                                                        rightSource:[MPSNNImageNode nodeWithHandle:b]];
    MPSNNGraph *graph = [MPSNNGraph graphWithDevice:device resultImage:node.resultImage resultImageIsNeeded:NO];
    MPSImage *result = Run(queue, graph, @[a, b]);
    PrintValues("result-not-needed", result, 0, 0, 0);
}

int main(void)
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = [device newCommandQueue];
        printf("device %s\n", [[device name] UTF8String]);
        Report("MPSNNImageNode", [MPSNNImageNode alloc]);
        Arithmetic(device, queue, "add", 0);
        Arithmetic(device, queue, "subtract", 1);
        Arithmetic(device, queue, "multiply", 2);
        Arithmetic(device, queue, "divide", 3);
        Chained(device, queue, "add-chained", 0);
        Chained(device, queue, "add-then-sub", 1);
        Scaled(device, queue);
        Concat(device, queue, "concat-1", 1);
        Concat(device, queue, "concat-2", 2);
        ConcatTwo(device, queue);
        Pooling(device, queue, "pool-avg-shape", 0);
        Pooling(device, queue, "pool-max-shape", 1);
        ResultNotNeeded(device, queue);
    }
    return 0;
}
