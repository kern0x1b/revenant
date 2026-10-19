// image-cases.m - the MPSImage arithmetic and threshold kernels, against the release's own answers.
//
// Compiled twice from this one file. The system build links the host's MetalPerformanceShaders and runs
// the release's own kernels. The port build is marked -DCHARON_PORT_BUILD, is renamed through
// `rename.h`, and links this package's objects and the Metal band's, so the MPSImage it builds and the
// answer it reads back are the port's own - not the release's class reached by accident, which is the
// failure the CNN harness had and now refuses.
//
// The images are filled and read through `image.texture` and its `replaceRegion:`/`getBytes:`, which
// both SDKs declare, rather than through the image-path `readBytes:`/`writeBytes:` the port's MPSImage
// implements. The two probes that decided it are in facts/MetalPerformanceShaders/Image.md; the short
// of it is that the host SDK declares neither image-path selector and the runtime answers neither, while
// the kernels themselves are reached through selectors it does answer.
//
// The two builds each print, per case, `case <name> <count> <values…>` and a line naming the classes
// each build resolved. The comparison is in run.sh.
//
// Three modes, and the third two exist to show the comparison can fail:
//   normal        the port's own arithmetic
//   all-wrong     every value the port prints is replaced by a constant, so every element of every
//                 case differs
//   one-wrong     every value but the first of the first case is right, so the grader has to name one
//                 wrong element rather than a case

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
// The reference this case is checked against, computed in plain C from the release's own
// formulas and NOT from this port. Why not the host: MPSImageThreshold.h and the host cannot
// answer on this machine, and the header of this file says so at length.
#include "mps-reference.h"
// class_getImageName, which the class line below prints: the sibling harness imports this for the
// same reason (cnn-cases.m:6), and without it the call does not compile at all.
#import <objc/runtime.h>

// Neither image-path encode is declared by the SDK this harness compiles against, and the two sides
// of the family do not use the same one - measured on this host, 2026-09-30:
//
//   MPSImageThresholdToZero  class present  initWithDevice:yes  threshold-init:yes  image-encode:yes
//   MPSImageArithmetic       class present  initWithDevice:yes  threshold-init:no  image-encode:no
//   MPSImageAdd              class present  initWithDevice:yes  threshold-init:no  image-encode:no
//   the three-image encode: the host answers it
//
// so the five thresholds are called through the first protocol and the four operations through the
// second, and both selectors are answered by the release and by this port.
@protocol CharonImageUnaryEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage;
@end

@protocol CharonImageBinaryEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  primaryImage:(MPSImage *)primaryImage
                secondaryImage:(MPSImage *)secondaryImage
               destinationImage:(MPSImage *)destinationImage;
@end

// MPSImageReduce's read window and its encode, from MPSImageReduce.h:42 and the unary encode at :29.
// The class is declared in MPSImage.framework's MPSImageReduce.h, which the umbrella this file imports
// does not carry, so the two are spelled out and the kernel is called through this protocol - the same
// reason CharonImageMatrixEncode exists for the copy's encode.
// MPSImageAreaMax/AreaMin take -initWithDevice:kernelHeight:kernelWidth: (MPSImageMorphology.h:42) and
// MPSImageDilate/Erode take the same plus -values: (:129), so the two are spelled out rather than merged.
// MPSImageHistogram's encode takes a texture and a buffer, not two MPSImages, and the normalized form
// adds a minmax texture between them (MPSImageHistogram.h:115 and :218), so both are spelled out here
// the way every other selector in this file is.
@protocol CharonHistogramEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
                     histogram:(id<MTLBuffer>)histogram
                histogramOffset:(NSUInteger)histogramOffset;
@end
@protocol CharonNormalizedHistogramEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
              minmaxTexture:(id<MTLTexture>)minmax
                     histogram:(id<MTLBuffer>)histogram
                histogramOffset:(NSUInteger)histogramOffset;
@end

@protocol CharonMorphologyAreaInit
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth;
@end
@protocol CharonMorphologyDilateInit
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth
                       values:(const float *)values;
@end

@protocol CharonImageConvolutionEncode
@property (readwrite, nonatomic) float bias;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage;
@end

@protocol CharonImageBoxEncode
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage;
@end

@protocol CharonImageConvolutionInit
- (instancetype)initWithDevice:(id<MTLDevice>)device
                    kernelWidth:(NSUInteger)kernelWidth
                   kernelHeight:(NSUInteger)kernelHeight
                        weights:(const float *)kernelWeights;
@end

@protocol CharonImageReduceEncode
@property (readwrite, nonatomic) MTLRegion clipRectSource;
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage;
@end

// The nine classes MPSImageReduce.h:29-184 declares need no local declaration: clang reports a duplicate
// interface if they are written out here, so the SDK's own declarations are what this file compiles
// against. What DOES have to be local is the two selectors below, because they are declared in
// MPSImage.framework's MPSImageReduce.h rather than in the umbrella - the same reason
// CharonImageMatrixEncode exists for the copy's encode. Declaring them through a protocol is also what
// lets the harness's generated rename header reach the port's classes: a string literal is not
// rewritten, so NSClassFromString here would reach the RELEASE's MPSImageReduce instead of this port's,
// and the first version of this case did exactly that and crashed inside the release's own encoder.
static id<MTLDevice> gDevice = nil;

// One case: a source image of the given values, a destination, and the kernel's answer written into it
// and read back out. The read is through the destination's own texture, which on the port side is the
// port's MPSImage and on the system side the release's.
static void runUnary(const char *name, id<CharonImageUnaryEncode> kernel, MPSImage *destination,
                     MPSImage *source, NSUInteger rows, NSUInteger cols, NSUInteger values,
                     const float *input, CharonRefThreshold which, double threshold, double maximum)
{
    @autoreleasepool {
        float out[256] = {0};
        // the source, written through its own writeBytes: on both sides
        for (NSUInteger y = 0; y < rows; y++) {
            for (NSUInteger x = 0; x < cols; x++) {
                out[y * cols + x] = input[y * cols + x];
            }
        }
        NSUInteger perRow = cols * sizeof(float);
        [[source texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                             withBytes:out bytesPerRow:perRow];
        memset(out, 0, sizeof(out));
        [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                         sourceImage:source
                    destinationImage:destination];
        // the answer, read through the destination's own texture
        float answer[256] = {0};
        [[destination texture] getBytes:answer bytesPerRow:perRow
                              fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
        // The red control is not here. It used to be - it perturbed what this file PRINTS - and that was
        // the weaker control of the two: it proved the comparison can read two numbers, not that it
        // notices a wrong kernel, and it could not reach the two kernels that print their own lines.
        // It now perturbs what a kernel writes, in the shared store layer (CharonMPSStore and
        // CharonMPSImageWriteRegion), so every case in the family is under it. See CharonMPS.h.
        printf("case %s %lu", name, (unsigned long)values);
        for (NSUInteger i = 0; i < values; i++)
            printf(" %.9g", (double)answer[i]);
        printf("\n");
        CharonCompareUnary(name, input, values, answer, which, threshold, maximum);
    }
}

// The same, for the four operations: two images in, one out, through the three-image encode.
static void runBinary(const char *name, id<CharonImageBinaryEncode> kernel, MPSImage *destination,
                      MPSImage *primary, MPSImage *secondary, NSUInteger rows, NSUInteger cols,
                      NSUInteger values, const float *input, const float *other, CharonRefOperation op)
{
    @autoreleasepool {
        NSUInteger perRow = cols * sizeof(float);
        float out[256] = {0};
        for (NSUInteger i = 0; i < values; i++)
            out[i] = input[i];
        [[primary texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                              withBytes:out bytesPerRow:perRow];
        for (NSUInteger i = 0; i < values; i++)
            out[i] = other[i];
        [[secondary texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                                 withBytes:out bytesPerRow:perRow];
        memset(out, 0, sizeof(out));
        [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                        primaryImage:primary
                      secondaryImage:secondary
                     destinationImage:destination];
        float answer[256] = {0};
        [[destination texture] getBytes:answer bytesPerRow:perRow
                              fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
        printf("case %s %lu", name, (unsigned long)values);
        for (NSUInteger i = 0; i < values; i++)
            printf(" %.9g", (double)answer[i]);
        printf("\n");
        CharonCompareBinary(name, input, other, values, answer, op);
    }
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) { printf("no metal device\n"); return 2; }
        printf("device: %s\n", [[gDevice name] UTF8String]);

        // The two builds each say which MPSImage and which kernels they resolved, so a case that ran
        // against the wrong class is visible in the output rather than in a number.
        // Through the class EXPRESSION, not through NSClassFromString of a literal: the rename header
        // rewrites a class name in an expression and does not rewrite the contents of a string literal, so
        // a literal lookup on the port build asks the runtime for the HOST's class by name. Measured,
        // before this change, on the port build:
        //   -[MPSImageThresholdToZero charon_mps_hasThreshold]: unrecognized selector sent to instance
        Class listed[] = {MPSImage.class, MPSImageDescriptor.class,
                          MPSImageThresholdToZero.class, MPSImageThresholdToZeroInverse.class,
                          MPSImageThresholdBinary.class, MPSImageThresholdBinaryInverse.class,
                          MPSImageThresholdTruncate.class, MPSImageArithmetic.class,
                          MPSImageAdd.class, MPSImageSubtract.class, MPSImageMultiply.class,
                          MPSImageDivide.class};
        const char *names[] = {"MPSImage", "MPSImageDescriptor", "MPSImageThresholdToZero",
                               "MPSImageThresholdToZeroInverse", "MPSImageThresholdBinary",
                               "MPSImageThresholdBinaryInverse", "MPSImageThresholdTruncate",
                               "MPSImageArithmetic", "MPSImageAdd", "MPSImageSubtract",
                               "MPSImageMultiply", "MPSImageDivide"};
        for (unsigned i = 0; i < sizeof(listed) / sizeof(listed[0]); i++) {
            Class c = listed[i];
            // The IMAGE NAME, as the sibling harness prints it and as facts/MetalPerformanceShaders/Image.md
            // quotes. A name is not enough: the rename header rewrites a class name in an EXPRESSION and not
            // the contents of a string, so `names[i]` is the same twelve lines on both builds and cannot
            // say whether a case ran against the port's class or the release's. The image name can.
            const char *image = c ? (class_getImageName(c) ?: "(none)") : "(absent)";
            printf("class %-32s %-38s %s%s\n", names[i], image, c ? "present" : "ABSENT",
                   (c && [c instancesRespondToSelector:@selector(initWithDevice:)]) ? ", answers initWithDevice:" : "");
        }

        // The four arithmetic subclasses, built the way a caller builds them - through the class
        // expression, so the port build builds the port's four - and each is asked whether it answers
        // -initWithDevice: before it is called, because a compile that succeeds is not a call that answers.
        id arithmetic[4] = {nil, nil, nil, nil};
        Class arith[4] = {MPSImageAdd.class, MPSImageSubtract.class,
                          MPSImageMultiply.class, MPSImageDivide.class};
        const char *arithNames[4] = {"MPSImageAdd", "MPSImageSubtract", "MPSImageMultiply", "MPSImageDivide"};
        for (int i = 0; i < 4; i++) {
            BOOL answers = [arith[i] instancesRespondToSelector:@selector(initWithDevice:)];
            arithmetic[i] = answers ? [[arith[i] alloc] initWithDevice:gDevice] : nil;
            printf("built %-18s responds %s, %s\n", arithNames[i], answers ? "yes" : "no",
                   arithmetic[i] ? "an object" : "NIL");
        }

        // The source every case reads: 4x3, with a value below, at and above each threshold.
        NSUInteger rows = 3, cols = 4, values = 12;
        const float input[12] = {-1.5f, -0.25f, 0.0f, 0.25f, 0.5f, 0.5f, 0.75f, 1.0f, 1.5f, 2.0f, -0.75f, 0.1f};
        const float second[12] = {0.5f, 0.5f, 0.5f, 0.5f, 1.0f, 2.0f, 4.0f, 0.5f, 0.25f, 0.5f, 1.5f, 2.0f};

        MPSImageDescriptor *descriptor =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                            width:cols height:rows featureChannels:1];
        MPSImage *source = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSImage *left = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSImage *right = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];

        // the five thresholds, each at 0.5, which the source straddles
        Class thresholds[5] = {MPSImageThresholdToZero.class, MPSImageThresholdToZeroInverse.class,
                               MPSImageThresholdBinary.class, MPSImageThresholdBinaryInverse.class,
                               MPSImageThresholdTruncate.class};
        const char *thresholdNames[5] = {"threshold-to-zero", "threshold-to-zero-inverse",
                                         "threshold-binary", "threshold-binary-inverse",
                                         "threshold-truncate"};
        for (int i = 0; i < 5; i++) {
            if (!thresholds[i]) { printf("case %s 0\n", thresholdNames[i]); continue; }
            id kernel = [[thresholds[i] alloc] initWithDevice:gDevice
                                                 thresholdValue:0.5f
                                        linearGrayColorTransform:NULL];
            static const CharonRefThreshold kinds[5] = {CharonRefToZero, CharonRefToZeroInverse,
                                                        CharonRefBinary, CharonRefBinaryInverse,
                                                        CharonRefTruncate};
            runUnary(thresholdNames[i], (id<CharonImageUnaryEncode>)kernel, left, source,
                     rows, cols, values, input, kinds[i], 0.5, 1.0);
        }

        // the four arithmetic operations over the two images, at the header's default scales
        for (int i = 0; i < 4; i++) {
            if (!arithmetic[i]) continue;
            static const CharonRefOperation ops[4] = {CharonRefAdd, CharonRefSubtract,
                                                        CharonRefMultiply, CharonRefDivide};
            runBinary(arithNames[i], (id<CharonImageBinaryEncode>)arithmetic[i], right, source, left,
                      rows, cols, values, input, second, ops[i]);
        }

        // MPSImageTranspose, over a 3x4 destination from the same 4x3 source, so the permutation is
        // visible: a destination of width x height is height x wide, and destination(row, column) takes
        // source(column, row). The destination is a different shape from the source on purpose.
        {
            NSUInteger dstCols = rows, dstRows = cols;            // 3 wide, 4 tall
            MPSImageDescriptor *wide =
                [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                width:dstCols height:dstRows featureChannels:1];
            MPSImage *narrow = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
            MPSImage *transposed = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:wide];
            id kernel = [[MPSImageTranspose alloc] initWithDevice:gDevice];
            printf("built %-24s %s\n", "MPSImageTranspose",
                   kernel ? "an object" : "NIL (absent)");
            if (kernel) {
                float fed[12];
                for (NSUInteger i = 0; i < 12; i++)
                    fed[i] = input[i];
                // the source is filled through its own texture, as the other cases do, so the case
                // does not depend on which -writeBytes: form the SDK declares
                [[narrow texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                                        withBytes:fed bytesPerRow:cols * sizeof(float)];
                [(id<CharonImageUnaryEncode>)kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                                              sourceImage:narrow
                                                         destinationImage:transposed];
                float got[12] = {0};
                [[transposed texture] getBytes:got bytesPerRow:dstCols * sizeof(float)
                                       fromRegion:MTLRegionMake2D(0, 0, dstCols, dstRows) mipmapLevel:0];
                printf("case transpose %lu", (unsigned long)(dstCols * dstRows));
                for (NSUInteger i = 0; i < dstCols * dstRows; i++)
                    printf(" %.9g", (double)got[i]);
                printf("\n");
                CharonReferenceTranspose("transpose", fed, cols, rows, got, dstCols, dstRows);
            }
        }

        // MPSImageCopyToMatrix, under both of the header's two data layouts, into a matrix whose rows are
        // longer than one image and whose origin is not [0, 0], so the placement is checked as well as
        // the order. The image has TWO feature channels on purpose: MPSImage.h:300-303's two orders are
        // the same order with one channel, so a one-channel image cannot tell them apart.
        {
            NSUInteger channels = 2, images = 2;
            NSUInteger perImage = cols * rows * channels;
            NSUInteger originRow = 1, originColumn = 3;
            NSUInteger rowElements = perImage + 5;         // longer than the header's minimum
            NSUInteger matrixRows = originRow + images;    // one row per image, from the origin's row
            NSUInteger rowBytes = rowElements * sizeof(float);
            // two matrices, so the kernel's destinationMatrixBatchIndex of 1 has somewhere to land and the
            // first one must come back untouched, which is what the case checks
            id<MTLBuffer> buffer = [gDevice newBufferWithLength:matrixRows * rowBytes * 2
                                                      options:MTLResourceStorageModeShared];
            if (!buffer) { printf("case image-copy-to-matrix 0 (no buffer)\n"); }
            else {
                memset([buffer contents], 0, matrixRows * rowBytes * 2);
                MPSMatrixDescriptor *md =
                    [MPSMatrixDescriptor matrixDescriptorWithRows:matrixRows columns:rowElements matrices:2
                                                         rowBytes:rowBytes matrixBytes:matrixRows * rowBytes
                                                         dataType:MPSDataTypeFloat32];
                MPSMatrix *matrix = [[MPSMatrix alloc] initWithBuffer:buffer descriptor:md];
                printf("built %-24s %s\n", "MPSImageCopyToMatrix",
                       MPSImageCopyToMatrix.class ? "an object" : "NIL (absent)");
                {
                    static const MPSDataLayout layouts[2] = {MPSDataLayoutFeatureChannelsxHeightxWidth,
                                                            MPSDataLayoutHeightxWidthxFeatureChannels};
                    static const char *layoutNames[2] = {"featureChannelsxHeightxWidth",
                                                         "heightxWidthxFeatureChannels"};
                    float fed[perImage * images];
                    for (NSUInteger i = 0; i < perImage * images; i++)
                        fed[i] = input[i % values];
                    // fill both slices through the image's own texture, two channels per pixel
                    MPSImageDescriptor *two =
                        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                        width:cols height:rows
                                                              featureChannels:channels];
                    two.numberOfImages = images;
                    MPSImage *batch = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:two];
                    for (NSUInteger slice = 0; slice < images; slice++) {
                        float pixels[cols * rows * channels];
                        for (NSUInteger i = 0; i < cols * rows * channels; i++)
                            pixels[i] = fed[slice * perImage + i];
                        [[batch texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:slice
                                            withBytes:pixels bytesPerRow:cols * channels * sizeof(float)];
                    }
                    for (int l = 0; l < 2; l++) {
                        memset([buffer contents], 0, matrixRows * rowBytes * 2);
                        MPSImageCopyToMatrix *kernel =
                            [[MPSImageCopyToMatrix alloc] initWithDevice:gDevice dataLayout:layouts[l]];
                        if (!kernel) { printf("case %s 0\n", layoutNames[l]); continue; }
                        kernel.destinationMatrixOrigin = MTLOriginMake(originRow, originColumn, 0);
                        kernel.destinationMatrixBatchIndex = 1;   // the second matrix of the batch
                        [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                          sourceImage:batch
                                    destinationMatrix:matrix];
                        // the whole matrix the batch index named, from its own row 0, because the
                        // reference indexes it by the kernel's origin row
                        float got[matrixRows * rowElements];
                        memcpy(got, (char *)[buffer contents] + matrix.matrixBytes * 1,
                               matrixRows * rowElements * sizeof(float));
                        // MPSImageCopy.h:19-24 says each image lands in one row of the matrix, so the
                        // first matrix of the batch is not one of them and must still be the zero it was.
                        NSUInteger untouched = 0;
                        float *first = (float *)[buffer contents];
                        for (NSUInteger i = 0; i < matrixRows * rowElements; i++)
                            if (first[i] != 0.0f) untouched++;
                        gCompared++;
                        if (untouched) {
                            gMismatches++;
                            printf("\n  MISMATCH %s: %lu elements of the matrix the batch index did not name"
                                   " were written\n", layoutNames[l], (unsigned long)untouched);
                        }
                        printf("case image-copy-to-matrix layout %s %lu", layoutNames[l],
                               (unsigned long)(perImage * images));
                        for (NSUInteger i = 0; i < perImage * images; i++)
                            printf(" %.9g", (double)got[originColumn + i]);
                        printf("\n");
                        CharonReferenceImageCopyToMatrix(layoutNames[l], fed, cols, rows, channels, images,
                                                         layouts[l], originRow, originColumn,
                                                         got, rowElements);
                    }
                }
            }
        }
        // MPSImageReduce, MPSImageReduce.h:53-176's eight concrete classes. A Row class returns one value
        // per row of the source and a Column class one per column - that count is the header's own
        // wording - so a Row destination is 1 wide by `rows` tall and a Column one `cols` wide by 1 tall.
        // The header never states the destination's width and height, and this host cannot measure it: its
        // AGX family lacks computeCommandEncoderWithDispatchType: and the release's own kernel dies
        // encoding. So the shape here is the one the class names imply, it is not claimed to be the
        // release's measured one, and every row of this family carries that AGX reason.
        //
        // The read window is clipRectSource, which :31-42 says REPLACES the unary offset and is
        // INTERSECTED with the image, so the case uses the default (:36, MPSRectNoClip, the whole texture)
        // and the reference clamps the same way. offset is deliberately never set here: for this filter
        // the header says it is ignored, so setting it would test nothing.
        //
        // The classes are named as CLASSES and not as strings, which is the whole point: the harness
        // renames the port's classes with a generated header and a string literal is not rewritten by it,
        // so NSClassFromString here would silently reach the RELEASE's MPSImageReduce rather than this
        // port's. That is not hypothetical - it is what the first version of this case did, and it
        // crashed in the release's own encoder.
        {
            static const char *classNames[8] = {"MPSImageReduceRowMin", "MPSImageReduceColumnMin",
                                                "MPSImageReduceRowMax", "MPSImageReduceColumnMax",
                                                "MPSImageReduceRowMean", "MPSImageReduceColumnMean",
                                                "MPSImageReduceRowSum", "MPSImageReduceColumnSum"};
            static const char *reduceNames[8] = {"reduce-row-min", "reduce-column-min",
                                                 "reduce-row-max", "reduce-column-max",
                                                 "reduce-row-mean", "reduce-column-mean",
                                                 "reduce-row-sum", "reduce-column-sum"};
            static const char *renamed[8] = {"CharonMPSImageReduceRowMin", "CharonMPSImageReduceColumnMin",
                                             "CharonMPSImageReduceRowMax", "CharonMPSImageReduceColumnMax",
                                             "CharonMPSImageReduceRowMean", "CharonMPSImageReduceColumnMean",
                                             "CharonMPSImageReduceRowSum", "CharonMPSImageReduceColumnSum"};
            Class reduceClasses[8] = {[MPSImageReduceRowMin class], [MPSImageReduceColumnMin class],
                                      [MPSImageReduceRowMax class], [MPSImageReduceColumnMax class],
                                      [MPSImageReduceRowMean class], [MPSImageReduceColumnMean class],
                                      [MPSImageReduceRowSum class], [MPSImageReduceColumnSum class]};
            static const CharonRefReduce kinds[8] = {CharonRefReduceMin, CharonRefReduceMin,
                                                      CharonRefReduceMax, CharonRefReduceMax,
                                                      CharonRefReduceMean, CharonRefReduceMean,
                                                      CharonRefReduceSum, CharonRefReduceSum};
            for (int i = 0; i < 8; i++) {
                int byColumn = (i % 2) == 1;
                NSUInteger dstCols = byColumn ? cols : 1;
                NSUInteger dstRows = byColumn ? 1 : rows;
                NSUInteger want = byColumn ? cols : rows;
                // Presence is tested by the RENAMED name. The port's classes are Charon-prefixed in this
                // build and the release's are not, so this asks the only question that matters - does
                // THIS PORT have the kernel - without touching the release's, which is what calling the
                // unrenamed name would do.
                //
                // An absent kernel is a MISMATCH, not a case that reports nothing: a case line with no
                // values would leave the reference nothing to compare, gCompared would not move, and the
                // harness would report success over zero elements. That is the defect this whole harness
                // has been about, so a missing family fails here loudly instead.
                if (!NSClassFromString([NSString stringWithUTF8String:renamed[i]])) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: this port has no %s (looked for %s), so the case is absent"
                           " and not merely wrong\n", reduceNames[i], classNames[i], renamed[i]);
                    printf("case %s 0\n", reduceNames[i]);
                    continue;
                }
                MPSImageDescriptor *rd =
                    [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                    width:dstCols height:dstRows
                                                          featureChannels:1];
                MPSImage *out = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:rd];
                id<CharonImageReduceEncode> kernel = [[reduceClasses[i] alloc] initWithDevice:gDevice];
                if (!kernel) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: %s exists but would not instantiate\n", reduceNames[i],
                           classNames[i]);
                    printf("case %s 0\n", reduceNames[i]);
                    continue;
                }
                kernel.clipRectSource = MPSRectNoClip;              // the default, stated by :36
                [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                  sourceImage:source
                            destinationImage:out];
                float got[4] = {0};
                [[out texture] getBytes:got bytesPerRow:dstCols * sizeof(float)
                           fromRegion:MTLRegionMake2D(0, 0, dstCols, dstRows) mipmapLevel:0];
                printf("case %s %lu", reduceNames[i], (unsigned long)want);
                for (NSUInteger v = 0; v < want; v++)
                    printf(" %.9g", (double)got[v]);
                printf("\n");
                CharonReferenceImageReduce(reduceNames[i], input, rows, cols, 0, 0, byColumn,
                                           kinds[i], got, want);
            }
        }

        // MPSImageConvolution, MPSImageConvolution.h:49's base and the three fixed-weight subclasses whose
        // whole behaviour is a weighted sum: MPSImageBox (:146), MPSImageTent (:219) and
        // MPSImageGaussianBlur (:237, which cannot be built - see the file). The weights below are chosen
        // to be ASYMMETRIC and to sum to something other than one, so a kernel that transposed the window,
        // flipped it, or ignored a weight cannot pass: a symmetric blur of a symmetric-looking image would.
        //
        // The edge rule is MPSUnaryImageKernel's edgeMode, whose default MPSImageKernel.h gives as "usually
        // MPSImageEdgeModeZero", and the case uses a 5x5 window over a 4x3 image on purpose so the window
        // runs off the edge and the zero rule is actually exercised rather than assumed.
        //
        // :62-72 - the bias is added BEFORE the store, so it is set to a value no weight could produce.
        {
            static const char *convNames[4] = {"convolution", "box", "tent", "gaussian-blur"};
            static const char *convRenamed[4] = {"CharonMPSImageConvolution", "CharonMPSImageBox",
                                                 "CharonMPSImageTent", "CharonMPSImageGaussianBlur"};
            Class convClasses[4] = {[MPSImageConvolution class], [MPSImageBox class],
                                    [MPSImageTent class], [MPSImageGaussianBlur class]};
            NSUInteger kw = 5, kh = 5;
            static float weights[25] = {0.5f, 0.25f, 0.0f, 0.25f, 0.5f,
                                        0.25f, 0.5f, 1.0f, 0.5f, 0.25f,
                                        0.0f,  1.0f, 2.0f, 1.0f, 0.0f,
                                        0.25f, 0.5f, 1.0f, 0.5f, 0.25f,
                                        0.5f,  0.25f, 0.0f, 0.25f, 0.5f};
            // The reference needs the SAME weights each class actually uses. A Box's weights are its own
            // 1/area array and a Tent's are its own falling-off array, so they are computed here rather
            // than assumed, and the kernel is not compared against weights it was not given.
            float boxWeights[25], tentWeights[25];
            for (NSUInteger i = 0; i < 25; i++)
                boxWeights[i] = (float)(1.0 / 25.0);
            double tentTotal = 0.0;
            for (NSUInteger ky = 0; ky < 5; ky++)
                for (NSUInteger kx = 0; kx < 5; kx++) {
                    double wx = (double)(1 + (5 / 2) - (kx < 5 / 2 ? kx : 5 - 1 - kx));
                    double wy = (double)(1 + (5 / 2) - (ky < 5 / 2 ? ky : 5 - 1 - ky));
                    tentTotal += wx * wy;
                }
            for (NSUInteger ky = 0; ky < 5; ky++)
                for (NSUInteger kx = 0; kx < 5; kx++) {
                    double wx = (double)(1 + (5 / 2) - (kx < 5 / 2 ? kx : 5 - 1 - kx));
                    double wy = (double)(1 + (5 / 2) - (ky < 5 / 2 ? ky : 5 - 1 - ky));
                    tentWeights[ky * 5 + kx] = (float)(wx * wy / tentTotal);
                }
            const float *each[4] = {weights, boxWeights, tentWeights, weights};
            for (int i = 0; i < 4; i++) {
                if (!NSClassFromString([NSString stringWithUTF8String:convRenamed[i]])) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: this port has no %s (looked for %s), so the case is absent"
                           " and not merely wrong\n", convNames[i], convRenamed[i], convRenamed[i]);
                    printf("case %s 0\n", convNames[i]);
                    continue;
                }
                MPSImage *out = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
                id kernel = nil;
                if (i == 0) {
                    id<CharonImageConvolutionInit> made =
                        [[convClasses[i] alloc] initWithDevice:gDevice kernelWidth:kw
                                                 kernelHeight:kh weights:each[i]];
                    ((id<CharonImageConvolutionEncode>)made).bias = 0.125f;   // :62-72, before the store
                    kernel = made;
                } else if (i == 1 || i == 2) {
                    Class box = convClasses[i];
                    kernel = [[box alloc] initWithDevice:gDevice kernelHeight:kh kernelWidth:kw];
                } else {
                    kernel = [[convClasses[i] alloc] initWithDevice:gDevice sigma:1.5f];
                    if (!kernel) {
                        // The header does not say how many taps a sigma implies, so the object refuses to
                        // be built. That refusal is the measured behaviour of this class on this port and
                        // the case records it rather than pretending a blur was compared.
                        gCompared++;
                        printf("\n  INERT %s: MPSImageGaussianBlur builds no object here -"
                               " MPSImageConvolution.h:252 needs a tap count the header does not state\n",
                               convNames[i]);
                        printf("case %s 0\n", convNames[i]);
                        continue;
                    }
                }
                if (!kernel) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: %s exists but would not instantiate\n", convNames[i],
                           convRenamed[i]);
                    printf("case %s 0\n", convNames[i]);
                    continue;
                }
                [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                 sourceImage:source
                           destinationImage:out];
                float got[12] = {0};
                [[out texture] getBytes:got bytesPerRow:cols * sizeof(float)
                           fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
                printf("case %s %lu", convNames[i], (unsigned long)values);
                for (NSUInteger v = 0; v < values; v++)
                    printf(" %.9g", (double)got[v]);
                printf("\n");
                CharonReferenceImageConvolution(convNames[i], input, rows, cols, kw, kh, each[i],
                                                i == 0 ? 0.125 : 0.0, 0, 0, got, values);
            }
        }

        // MPSImageMorphology, MPSImageMorphology.h:22, :72, :96 and :174 - four classes that are all the
        // same walk with two choices in it. The window is 5x5 over a 4x3 image, so it runs off every edge
        // on purpose: :69 and :93 say the edge mode is fixed at clamp for this filter, so an off-edge tap
        // takes the nearest edge VALUE. A
        // convolution case over the same image and window would use MPSImageEdgeModeZero and get a
        // different answer, and having both is what makes the edge rule visible rather than asserted.
        //
        // The probe is asymmetric and not all ones, so a Dilate that ignored it, or used it as a
        // multiplier rather than an add, cannot pass. The comparison is for EQUALITY: a maximum and a
        // minimum select a value the source already holds, so there is no rounding to absorb.
        {
            static const char *morphNames[4] = {"area-max", "area-min", "dilate", "erode"};
            static const char *morphRenamed[4] = {"CharonMPSImageAreaMax", "CharonMPSImageAreaMin",
                                                   "CharonMPSImageDilate", "CharonMPSImageErode"};
            Class morphClasses[4] = {[MPSImageAreaMax class], [MPSImageAreaMin class],
                                     [MPSImageDilate class], [MPSImageErode class]};
            NSUInteger mw = 5, mh = 5;
            static float probe[25] = {0.0f,  0.5f, 0.0f, 0.5f, 0.0f,
                                      0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
                                      0.0f,  0.5f, 0.0f, 0.5f, 0.0f,
                                      0.5f, 0.5f, 0.5f, 0.5f, 0.5f,
                                      0.0f,  0.5f, 0.0f, 0.5f, 0.0f};
            for (int i = 0; i < 4; i++) {
                if (!NSClassFromString([NSString stringWithUTF8String:morphRenamed[i]])) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: this port has no %s (looked for %s), so the case is absent"
                           " and not merely wrong\n", morphNames[i], morphRenamed[i], morphRenamed[i]);
                    printf("case %s 0\n", morphNames[i]);
                    continue;
                }
                Class mc = morphClasses[i];
                id kernel = (i < 2)
                    ? [[mc alloc] initWithDevice:gDevice kernelHeight:mh kernelWidth:mw]
                    : [[mc alloc] initWithDevice:gDevice kernelHeight:mh kernelWidth:mw values:probe];
                if (!kernel) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: %s exists but would not instantiate\n", morphNames[i],
                           morphRenamed[i]);
                    printf("case %s 0\n", morphNames[i]);
                    continue;
                }
                [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                 sourceImage:source
                           destinationImage:left];
                float got[12] = {0};
                [[left texture] getBytes:got bytesPerRow:cols * sizeof(float)
                           fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
                printf("case %s %lu", morphNames[i], (unsigned long)values);
                for (NSUInteger v = 0; v < values; v++)
                    printf(" %.9g", (double)got[v]);
                printf("\n");
                CharonReferenceImageMorphology(morphNames[i], input, rows, cols, 1, mw, mh,
                                              i < 2 ? NULL : probe, (i == 0 || i == 2), 0, 0, got, values);
            }
        }

        // MPSImageHistogram, MPSImageHistogram.h:33 and :145. A histogram COUNTS, so its answer is exact
        // and is compared exactly - the same argument as the morphology family and the opposite of the
        // convolution's. The bins are CHANNEL-MAJOR (:206-215: all the R bins come first, then G, B and A), so a kernel
        // that wrote them bin-major would produce a
        // plausible-looking array in the wrong order and this catches it.
        //
        // histogramForAlpha is set NO (:208 gives the rule for an RGBA source with that flag off, so only RGB is stored), and the alpha channel's
        // bins are therefore not compared at all - and a kernel that wrote four channels where three belong would
        // show up as the first three matching and the buffer size disagreeing.
        {
            static const char *histNames[2] = {"histogram", "normalized-histogram"};
            static const char *histRenamed[2] = {"CharonMPSImageHistogram", "CharonMPSImageNormalizedHistogram"};
            Class histClasses[2] = {[MPSImageHistogram class], [MPSImageNormalizedHistogram class]};
            NSUInteger bins = 8;
            double lo = 0.0, hi = 1.0;
            MPSImageHistogramInfo info;
            info.numberOfHistogramEntries = bins;
            info.histogramForAlpha = NO;
            info.minPixelValue = (vector_float4){(float)lo, (float)lo, (float)lo, (float)lo};
            info.maxPixelValue = (vector_float4){(float)hi, (float)hi, (float)hi, (float)hi};
            // the unorm8 bytes the reference and the kernel both see, written through the image's texture
            unsigned char pixels[rows * cols * 4];
            for (NSUInteger p = 0; p < rows * cols; p++)
                for (NSUInteger c = 0; c < 4; c++)
                    pixels[p * 4 + c] = (unsigned char)(c == 3 ? 255 : (p * 37 + c * 11) % 256);
            // The port's descriptor is channel-format based, and MPSImage13's own table maps
            // MPSImageFeatureChannelFormatUnorm8 to MTLPixelFormatRGBA8Unorm - which is the format the
            // histogram's :208 wording talks about ("if the source image is RGBA").
            MPSImageDescriptor *u8 =
                [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatUnorm8
                                                                width:cols height:rows featureChannels:4];
            MPSImage *src8 = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:u8];
            [[src8 texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                                withBytes:pixels bytesPerRow:cols * 4];
            for (int i = 0; i < 2; i++) {
                if (!NSClassFromString([NSString stringWithUTF8String:histRenamed[i]])) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: this port has no %s (looked for %s), so the case is absent"
                           " and not merely wrong\n", histNames[i], histRenamed[i], histRenamed[i]);
                    printf("case %s 0\n", histNames[i]);
                    continue;
                }
                size_t want = (size_t)bins * 3 * sizeof(uint32_t);
                id<MTLBuffer> out = [gDevice newBufferWithLength:want options:MTLResourceStorageModeShared];
                id<MTLTexture> minmax = nil;
                if (i) {
                    MTLTextureDescriptor *mmd = [[MTLTextureDescriptor alloc] init];
                    mmd.textureType = MTLTextureType2D;
                    mmd.pixelFormat = MTLPixelFormatRGBA8Unorm;
                    mmd.width = 1;
                    mmd.height = 1;
                    mmd.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
                    minmax = [gDevice newTextureWithDescriptor:mmd];
                }
                memset([out contents], 0, want);
                MPSImageHistogramInfo use = info;
                if (i) {
                    // the normalized form measures its own range; give it a range it will replace, so a
                    // kernel that used the caller's range instead of the image's is visible
                    use.minPixelValue = (vector_float4){0.25f, 0.25f, 0.25f, 0.25f};
                    use.maxPixelValue = (vector_float4){0.75f, 0.75f, 0.75f, 0.75f};
                }
                Class hc = histClasses[i];
                id kernel = [[hc alloc] initWithDevice:gDevice histogramInfo:&use];
                if (!kernel) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: %s exists but would not instantiate\n", histNames[i],
                           histRenamed[i]);
                    printf("case %s 0\n", histNames[i]);
                    continue;
                }
                if (i)
                    [(id<CharonNormalizedHistogramEncode>)kernel
                        encodeToCommandBuffer:[gDevice newCommandBuffer] sourceTexture:[src8 texture]
                      minmaxTexture:minmax histogram:out histogramOffset:0];
                else
                    [(id<CharonHistogramEncode>)kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                                             sourceTexture:[src8 texture]
                                                                    histogram:out
                                                              histogramOffset:0];
                double rangeLo = lo, rangeHi = hi;
                if (i) {
                    unsigned char mm[4] = {0, 0, 0, 0};
                    [minmax getBytes:mm bytesPerRow:4 fromRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0];
                    rangeLo = (double)mm[0] / 255.0;
                    rangeHi = (double)mm[1] / 255.0;
                }
                uint32_t *binsOut = (uint32_t *)[out contents];
                printf("case %s %lu", histNames[i], (unsigned long)want);
                for (NSUInteger b = 0; b < (want / sizeof(uint32_t)); b++)
                    printf(" %lu", (unsigned long)binsOut[b]);
                printf("\n");
                CharonReferenceImageHistogram(histNames[i], pixels, rows, cols, bins, rangeLo, rangeHi,
                                              NO, binsOut, 4);
            }
        }
    }
    printf("COMPARED %lu  MISMATCHES %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return gMismatches ? 1 : 0;
}
