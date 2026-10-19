// graph-cases.m - this port's MPSNNGraph, against the release's own MPSNNGraph, on the same inputs.
//
// Compiled twice from this one file:
//   * the SYSTEM build links the host's MetalPerformanceShaders and builds the graph out of Apple's own
//     MPSNNImageNode, MPSNNAdditionNode and MPSNNGraph. That is the oracle.
//   * the PORT build is marked -DCHARON_PORT_BUILD, is renamed through `rename.h`, and links this
//     package's objects, so the nodes and the graph that build the case are the port's own. A case that
//     ran against the release's class would compare the release with itself, and the `class` lines below
//     say which class each build resolved.
//
// WHY THERE IS A SYSTEM-SIDE BUILD HERE, when tests/backports/host/mpsimage has none: because Apple's own
// MPSNNGraph runs on this machine. Measured, in tests/backports/host/mpsnn/probe.txt, built fresh and
// linked against Metal.framework and MetalPerformanceShaders.framework:
//
//   MTLCreateSystemDefaultDevice: class AGXG16SDevice name Apple M4 Pro
//   queue commandBuffer: class AGXG16XFamilyCommandBuffer
//   empty commit + waitUntilCompleted: OK, status 4, error (none)
//   Apple's MPSNNGraph answers: 11 22 33 44
//
// So the graph's answers are checked against the release's answers, not against numbers written beside
// the inputs. What the previous round of this work recorded instead - that this host's Metal cannot
// commit a command buffer, and that nine of the graph's node classes are absent from the framework - is
// not what the host says. Both of those came out of a probe that asked for four class names no Apple
// header declares (MPSNNAddNode, MPSNNConvolutionNode, MPSNNPoolingMaxNode, MPSNNActivationNode; the
// real ones are MPSNNAdditionNode, MPSCNNConvolutionNode, MPSCNNPoolingMaxNode and MPSCNNNeuronNode) and
// built its command buffer with -[MTLDevice newCommandBuffer], which MTLDevice.h:507-518 does not
// declare: -commandBuffer belongs to MTLCommandQueue, so the object the blame named was never the
// receiver. probe.txt answers both questions with the right names and the framework's own order.
//
// THE FORMAT IS SET TO FLOAT32 ON BOTH SIDES, and that is not cosmetic. MPSNNGraph.h:196 makes a graph's
// `format` default to MPSImageFeatureChannelFormatFloat16, so Apple's result image came back R16Float and
// its four bytes of halfs are 0x4980 0x4d80 0x5020 0x5180 - which decode as 11 22 33 44, and read as
// float32 are 2.69038e+08 6.88875e+10 0 0. The port's destination is allocated from the SOURCE image's own
// channel format ([MPSImage charon_mps_descriptor]), so the port's result is float32 whichever way the
// graph's property is set. Setting the property to Float32 makes the two agree, and the shape line below
// prints the format each side actually produced so a future drift is a printed difference rather than a
// silent one.
//
// Every case prints `case <name> <width>x<height>x<channels> <values...>`, and the values are printed with
// %g so that a float32 the two sides compute differently in the last bit shows as a differing number
// rather than as two spellings of one. What each side said on stderr is kept out of the data: a Metal
// assertion is written to stderr by the driver and would land mid-line in a merged stream.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>

// MPSHandle. +nodeWithHandle: takes an id<MPSHandle> and the release's MPSImage conforms to it; this
// port's MPSImage13.m does not declare the conformance, so every -nodeWithHandle: in this file is a
// pointer-type warning. It is turned off here, locally and with the reason, rather than as a file-wide
// build flag: the same file compiles against the release's MPSImage with no warning at all, and the
// difference is MPSImage13.m's and not this case's. Nothing about the graph's answers changes.
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"

// THE RECEIPT IS THE `class` LINES, and the rename is what makes them a receipt rather than decoration.
// The host's MetalPerformanceShaders defines every class this object defines, so an unrenamed port build
// would hold two classes of each name and a message would be answered by whichever loaded first. run.sh
// renames the port's - so the system build prints `MPSNNAdditionNode` and the port build prints
// `CharonMPSNNAdditionNode`, and a case that ran against Apple's class would print the unrenamed name and
// be caught. No port-only selector is asked for, so this object needs no seam and the registry needs no
// row for one.
static void Report(const char *what, id object)
{
    printf("class %-22s %s\n", what, object ? [NSStringFromClass([object class]) UTF8String] : "(nil)");
}

// THE FILL AND THE READBACK, AND EACH SIDE CALLS ITS OWN MPSImage FOR THEM. That asymmetry is a
// measurement, and it is the third thing that had to be measured before this case could run at all:
//
//   * the three-argument pair -writeBytes:dataLayout:imageIndex: and -readBytes:dataLayout:imageIndex: is
//     what the SDK of this machine declares (MPSImage.h:814 and :797) and what the release's MPSImage
//     answers. Measured: with it the release's own image reads back the values written into it.
//   * the port's MPSImage13.m implements the six-argument pair (:334/:353) and the five-argument pair
//     (:372/:382) and neither SDK declares the five-argument one, so it is spelled out through the
//     protocol below. Measured: the release's MPSImage does NOT answer it -
//     "-[MPSImage writeBytes:dataLayout:bytesPerRow:region:imageIndex:]: unrecognized selector sent to
//     instance".
//   * -bytesPerRow on the texture is not a route either: it is a property of the MTLTexture CLASS and not
//     of the MTLTexture protocol, and this host's AGXG16XFamilyTexture does not answer the selector.
//
// So the two helpers below call the pair their own side has. Everything after this point is the same code
// on both sides, which is what makes the comparison one of the graph's answers rather than of the fill.
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

// One encode of one graph. `commandBuffer` is the caller's, so the caller commits it - the port's kernels
// are synchronous and a result is in the image when -encodeToCommandBuffer: returns, which is at least as
// strong as the release's own "valid once the command buffer completes".
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

// Two 2x2 single channel images and one arithmetic node over them. `kind` is 0 add, 1 subtract,
// 2 multiply, 3 divide - the four MPSNNBinaryArithmeticNode subclasses this object carries.
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
    // sourceImageHandles.count is the walk's own receipt and it is public API on both sides: it is the
    // number of graph inputs the walk found, and a walk that read every node as an input would report the
    // whole node list here instead.
    printf("walk  %-18s %lu source handles\n", name, (unsigned long)graph.sourceImageHandles.count);
    MPSImage *result = Run(queue, graph, @[a, b]);
    PrintValues(name, result, 2, 2, 1);
}

// The two cases that decide whether the walk orders anything at all: ((a + b) + b) and ((a + b) - b).
// A graph that ran its filters in the order they were made, or that handed a node the original input
// instead of its predecessor's output, fails both.
static void Chained(id<MTLDevice> device, id<MTLCommandQueue> queue, const char *name, int subtractSecond)
{
    static const float left[4] = {1, 2, 3, 4};
    static const float right[4] = {10, 20, 30, 40};
    MPSImage *a = MakeImage(device, 2, 2, 1, left);
    MPSImage *b = MakeImage(device, 2, 2, 1, right);
    // ONE node per image, held by the caller and given to both filters. Two nodes over the same image is
    // two graph inputs, and the walk reports both: a first version of this case built a fresh node for the
    // right-hand side of the second filter, the graph then reported three source handles for a two-input
    // graph, and the release's own -encodeToCommandBuffer: died of "index 2 beyond bounds [0 .. 1]".
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

// The node's own scale, and not the kernel's default: 2 * (1,2,3,4) + (10,20,30,40). A node whose
// primaryScale defaulted to zero would answer the right shape and the wrong numbers, which is what the
// header's own default (MPSImageMath.h:31-32) exists to prevent.
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

// ONE image and one concatenation node, which is the case the four-channel rule of MPSNNGraphNodes.h:2443
// exists for: a source of fewer than four channels is padded out to four, and the value that lands in the
// padding is half of what this checks.
//
// ONE source, and that is a limit of the substrate rather than of the graph. A concatenation of two
// sources is eight channels wide for one-channel sources - MPSNNGraphNodes.h:2443-2446 pads EACH source
// out to a multiple of four - and MPSImage13.m holds one, two and four channels and refuses the rest, so
// the port has no image to allocate for the destination of any two-source concatenation. The release's own
// node answers 1x1x8 for one-channel sources; the port answers 0x0x8 and refuses in the log
// ("MPSImage: channel format 4 with 8 feature channels has no Metal pixel format, so no texture was
// made"). That limit is MPSImage's row and not this object's, and the refusal line below is printed rather
// than compared so that the transcript carries it instead of hiding it.
//
// The value in the padding is measured, not assumed: probe-concat.m sweeps the release's own node over five
// channel widths and gets, for a 1x1 image of channels 1..4 and a second of the same,
//   1+1 -> 1 0 0 1 5 0 0 1     2+2 -> 1 2 0 1 5 6 0 1     4+4 -> 1 2 3 4 5 6 7 8
//   1+4 -> 1 0 0 1 5 6 7 8     3+1 -> 1 2 3 0 5 0 0 1
// - zeros, and a 1 in the block's fourth channel for a source of one or two channels, and a zero for a
// source of three. The two cases below are the one- and two-channel rows of that table, which are the two
// a destination of four channels can hold.
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

// Two sources, which is the case the port's MPSImage cannot hold a destination for. Both sides are run and
// the port's answer is printed, so the transcript says what it refuses and why; the line is not compared,
// because the release's eight-channel destination and the port's refused one are not two answers to one
// question.
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

// A 3x3 source and a 2x2 window with a stride of one, and the destination's SHAPE and not its values.
//
// The shape is the whole of what this object decides about a pooling node: MPSNNDefaultPadding is this
// object's class, it is what a node's destination descriptor is asked for, and SizeSame is what makes the
// destination the source's three by three rather than two by two. Comparing it with the release's own
// MPSNNDefaultPadding measures the padding arithmetic against Apple's compiled arithmetic, which is a
// stronger oracle than transcribing the C block out of MPSNeuralNetworkTypes.h and comparing the port with
// itself - and it is the check the earlier version of this case could not make, because it had no
// release-side run at all.
//
// The VALUES are deliberately not compared here, and the reason is whose row they are: the divisor is the
// pooling KERNEL's, not the node's. This object hands the window to MPSCNNPooling and does not repeat a
// divisor (see the comment above @implementation MPSCNNPoolingNode), and MPSCNNPooling10.m is the 10.0
// object's file. facts/MetalPerformanceShaders/Cnn.md:75-76 carries that kernel's measured table and
// MPSCNNPoolingMax's known defect against it. Comparing the values here would make this script red for a
// reason no edit in this object can fix.
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

// resultImageIsNeeded:NO, which MPSNNGraph.h:72 says answers nil on the left of the -encode call, and the work that would make the final image may be dropped.
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
