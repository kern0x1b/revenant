#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include "mps-reference.h"
#import <objc/runtime.h>

@protocol RevenantImageUnaryEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 sourceImage:(MPSImage *)sourceImage
            destinationImage:(MPSImage *)destinationImage;
@end

@protocol RevenantImageBinaryEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                  primaryImage:(MPSImage *)primaryImage
                secondaryImage:(MPSImage *)secondaryImage
               destinationImage:(MPSImage *)destinationImage;
@end

@protocol RevenantHistogramEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
                     histogram:(id<MTLBuffer>)histogram
                histogramOffset:(NSUInteger)histogramOffset;
@end
@protocol RevenantNormalizedHistogramEncode
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                sourceTexture:(id<MTLTexture>)source
              minmaxTexture:(id<MTLTexture>)minmax
                     histogram:(id<MTLBuffer>)histogram
                histogramOffset:(NSUInteger)histogramOffset;
@end

@protocol RevenantMorphologyAreaInit
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth;
@end
@protocol RevenantMorphologyDilateInit
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth
                       values:(const float *)values;
@end

@protocol RevenantImageConvolutionEncode
@property (readwrite, nonatomic) float bias;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage;
@end

@protocol RevenantImageBoxEncode
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  kernelHeight:(NSUInteger)kernelHeight
                   kernelWidth:(NSUInteger)kernelWidth;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage;
@end

@protocol RevenantImageConvolutionInit
- (instancetype)initWithDevice:(id<MTLDevice>)device
                    kernelWidth:(NSUInteger)kernelWidth
                   kernelHeight:(NSUInteger)kernelHeight
                        weights:(const float *)kernelWeights;
@end

@protocol RevenantImageReduceEncode
@property (readwrite, nonatomic) MTLRegion clipRectSource;
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                   sourceImage:(MPSImage *)sourceImage
             destinationImage:(MPSImage *)destinationImage;
@end

static id<MTLDevice> gDevice = nil;

static void runUnary(const char *name, id<RevenantImageUnaryEncode> kernel, MPSImage *destination,
                     MPSImage *source, NSUInteger rows, NSUInteger cols, NSUInteger values,
                     const float *input, RevenantRefThreshold which, double threshold, double maximum)
{
    @autoreleasepool {
        float out[256] = {0};
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
        float answer[256] = {0};
        [[destination texture] getBytes:answer bytesPerRow:perRow
                              fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
        printf("case %s %lu", name, (unsigned long)values);
        for (NSUInteger i = 0; i < values; i++)
            printf(" %.9g", (double)answer[i]);
        printf("\n");
        RevenantCompareUnary(name, input, values, answer, which, threshold, maximum);
    }
}

static void runBinary(const char *name, id<RevenantImageBinaryEncode> kernel, MPSImage *destination,
                      MPSImage *primary, MPSImage *secondary, NSUInteger rows, NSUInteger cols,
                      NSUInteger values, const float *input, const float *other, RevenantRefOperation op)
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
        RevenantCompareBinary(name, input, other, values, answer, op);
    }
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) { printf("no metal device\n"); return 2; }
        printf("device: %s\n", [[gDevice name] UTF8String]);

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
            const char *image = c ? (class_getImageName(c) ?: "(none)") : "(absent)";
            printf("class %-32s %-38s %s%s\n", names[i], image, c ? "present" : "ABSENT",
                   (c && [c instancesRespondToSelector:@selector(initWithDevice:)]) ? ", answers initWithDevice:" : "");
        }

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

        NSUInteger rows = 3, cols = 4, values = 12;
        const float input[12] = {-1.5f, -0.25f, 0.0f, 0.25f, 0.5f, 0.5f, 0.75f, 1.0f, 1.5f, 2.0f, -0.75f, 0.1f};
        const float second[12] = {0.5f, 0.5f, 0.5f, 0.5f, 1.0f, 2.0f, 4.0f, 0.5f, 0.25f, 0.5f, 1.5f, 2.0f};

        MPSImageDescriptor *descriptor =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                            width:cols height:rows featureChannels:1];
        MPSImage *source = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSImage *left = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];
        MPSImage *right = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:descriptor];

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
            static const RevenantRefThreshold kinds[5] = {RevenantRefToZero, RevenantRefToZeroInverse,
                                                        RevenantRefBinary, RevenantRefBinaryInverse,
                                                        RevenantRefTruncate};
            runUnary(thresholdNames[i], (id<RevenantImageUnaryEncode>)kernel, left, source,
                     rows, cols, values, input, kinds[i], 0.5, 1.0);
        }

        for (int i = 0; i < 4; i++) {
            if (!arithmetic[i]) continue;
            static const RevenantRefOperation ops[4] = {RevenantRefAdd, RevenantRefSubtract,
                                                        RevenantRefMultiply, RevenantRefDivide};
            runBinary(arithNames[i], (id<RevenantImageBinaryEncode>)arithmetic[i], right, source, left,
                      rows, cols, values, input, second, ops[i]);
        }

        {
            NSUInteger dstCols = rows, dstRows = cols;
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
                [[narrow texture] replaceRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0
                                        withBytes:fed bytesPerRow:cols * sizeof(float)];
                [(id<RevenantImageUnaryEncode>)kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                                              sourceImage:narrow
                                                         destinationImage:transposed];
                float got[12] = {0};
                [[transposed texture] getBytes:got bytesPerRow:dstCols * sizeof(float)
                                       fromRegion:MTLRegionMake2D(0, 0, dstCols, dstRows) mipmapLevel:0];
                printf("case transpose %lu", (unsigned long)(dstCols * dstRows));
                for (NSUInteger i = 0; i < dstCols * dstRows; i++)
                    printf(" %.9g", (double)got[i]);
                printf("\n");
                RevenantReferenceTranspose("transpose", fed, cols, rows, got, dstCols, dstRows);
            }
        }

        {
            NSUInteger channels = 2, images = 2;
            NSUInteger perImage = cols * rows * channels;
            NSUInteger originRow = 1, originColumn = 3;
            NSUInteger rowElements = perImage + 5;
            NSUInteger matrixRows = originRow + images;
            NSUInteger rowBytes = rowElements * sizeof(float);
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
                        kernel.destinationMatrixBatchIndex = 1;
                        [kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
                                          sourceImage:batch
                                    destinationMatrix:matrix];
                        float got[matrixRows * rowElements];
                        memcpy(got, (char *)[buffer contents] + matrix.matrixBytes * 1,
                               matrixRows * rowElements * sizeof(float));
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
                        RevenantReferenceImageCopyToMatrix(layoutNames[l], fed, cols, rows, channels, images,
                                                         layouts[l], originRow, originColumn,
                                                         got, rowElements);
                    }
                }
            }
        }
        {
            static const char *classNames[8] = {"MPSImageReduceRowMin", "MPSImageReduceColumnMin",
                                                "MPSImageReduceRowMax", "MPSImageReduceColumnMax",
                                                "MPSImageReduceRowMean", "MPSImageReduceColumnMean",
                                                "MPSImageReduceRowSum", "MPSImageReduceColumnSum"};
            static const char *reduceNames[8] = {"reduce-row-min", "reduce-column-min",
                                                 "reduce-row-max", "reduce-column-max",
                                                 "reduce-row-mean", "reduce-column-mean",
                                                 "reduce-row-sum", "reduce-column-sum"};
            static const char *renamed[8] = {"RevenantMPSImageReduceRowMin", "RevenantMPSImageReduceColumnMin",
                                             "RevenantMPSImageReduceRowMax", "RevenantMPSImageReduceColumnMax",
                                             "RevenantMPSImageReduceRowMean", "RevenantMPSImageReduceColumnMean",
                                             "RevenantMPSImageReduceRowSum", "RevenantMPSImageReduceColumnSum"};
            Class reduceClasses[8] = {[MPSImageReduceRowMin class], [MPSImageReduceColumnMin class],
                                      [MPSImageReduceRowMax class], [MPSImageReduceColumnMax class],
                                      [MPSImageReduceRowMean class], [MPSImageReduceColumnMean class],
                                      [MPSImageReduceRowSum class], [MPSImageReduceColumnSum class]};
            static const RevenantRefReduce kinds[8] = {RevenantRefReduceMin, RevenantRefReduceMin,
                                                      RevenantRefReduceMax, RevenantRefReduceMax,
                                                      RevenantRefReduceMean, RevenantRefReduceMean,
                                                      RevenantRefReduceSum, RevenantRefReduceSum};
            for (int i = 0; i < 8; i++) {
                int byColumn = (i % 2) == 1;
                NSUInteger dstCols = byColumn ? cols : 1;
                NSUInteger dstRows = byColumn ? 1 : rows;
                NSUInteger want = byColumn ? cols : rows;
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
                id<RevenantImageReduceEncode> kernel = [[reduceClasses[i] alloc] initWithDevice:gDevice];
                if (!kernel) {
                    gMismatches++;
                    printf("\n  MISMATCH %s: %s exists but would not instantiate\n", reduceNames[i],
                           classNames[i]);
                    printf("case %s 0\n", reduceNames[i]);
                    continue;
                }
                kernel.clipRectSource = MPSRectNoClip;
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
                RevenantReferenceImageReduce(reduceNames[i], input, rows, cols, 0, 0, byColumn,
                                           kinds[i], got, want);
            }
        }

        {
            static const char *convNames[4] = {"convolution", "box", "tent", "gaussian-blur"};
            static const char *convRenamed[4] = {"RevenantMPSImageConvolution", "RevenantMPSImageBox",
                                                 "RevenantMPSImageTent", "RevenantMPSImageGaussianBlur"};
            Class convClasses[4] = {[MPSImageConvolution class], [MPSImageBox class],
                                    [MPSImageTent class], [MPSImageGaussianBlur class]};
            NSUInteger kw = 5, kh = 5;
            static float weights[25] = {0.5f, 0.25f, 0.0f, 0.25f, 0.5f,
                                        0.25f, 0.5f, 1.0f, 0.5f, 0.25f,
                                        0.0f,  1.0f, 2.0f, 1.0f, 0.0f,
                                        0.25f, 0.5f, 1.0f, 0.5f, 0.25f,
                                        0.5f,  0.25f, 0.0f, 0.25f, 0.5f};
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
                    id<RevenantImageConvolutionInit> made =
                        [[convClasses[i] alloc] initWithDevice:gDevice kernelWidth:kw
                                                 kernelHeight:kh weights:each[i]];
                    ((id<RevenantImageConvolutionEncode>)made).bias = 0.125f;
                    kernel = made;
                } else if (i == 1 || i == 2) {
                    Class box = convClasses[i];
                    kernel = [[box alloc] initWithDevice:gDevice kernelHeight:kh kernelWidth:kw];
                } else {
                    kernel = [[convClasses[i] alloc] initWithDevice:gDevice sigma:1.5f];
                    if (!kernel) {
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
                RevenantReferenceImageConvolution(convNames[i], input, rows, cols, kw, kh, each[i],
                                                i == 0 ? 0.125 : 0.0, 0, 0, got, values);
            }
        }

        {
            static const char *morphNames[4] = {"area-max", "area-min", "dilate", "erode"};
            static const char *morphRenamed[4] = {"RevenantMPSImageAreaMax", "RevenantMPSImageAreaMin",
                                                   "RevenantMPSImageDilate", "RevenantMPSImageErode"};
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
                RevenantReferenceImageMorphology(morphNames[i], input, rows, cols, 1, mw, mh,
                                              i < 2 ? NULL : probe, (i == 0 || i == 2), 0, 0, got, values);
            }
        }

        {
            static const char *histNames[2] = {"histogram", "normalized-histogram"};
            static const char *histRenamed[2] = {"RevenantMPSImageHistogram", "RevenantMPSImageNormalizedHistogram"};
            Class histClasses[2] = {[MPSImageHistogram class], [MPSImageNormalizedHistogram class]};
            NSUInteger bins = 8;
            double lo = 0.0, hi = 1.0;
            MPSImageHistogramInfo info;
            info.numberOfHistogramEntries = bins;
            info.histogramForAlpha = NO;
            info.minPixelValue = (vector_float4){(float)lo, (float)lo, (float)lo, (float)lo};
            info.maxPixelValue = (vector_float4){(float)hi, (float)hi, (float)hi, (float)hi};
            unsigned char pixels[rows * cols * 4];
            for (NSUInteger p = 0; p < rows * cols; p++)
                for (NSUInteger c = 0; c < 4; c++)
                    pixels[p * 4 + c] = (unsigned char)(c == 3 ? 255 : (p * 37 + c * 11) % 256);
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
                    [(id<RevenantNormalizedHistogramEncode>)kernel
                        encodeToCommandBuffer:[gDevice newCommandBuffer] sourceTexture:[src8 texture]
                      minmaxTexture:minmax histogram:out histogramOffset:0];
                else
                    [(id<RevenantHistogramEncode>)kernel encodeToCommandBuffer:[gDevice newCommandBuffer]
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
                RevenantReferenceImageHistogram(histNames[i], pixels, rows, cols, bins, rangeLo, rangeHi,
                                              NO, binsOut, 4);
            }
        }
    }
    printf("COMPARED %lu  MISMATCHES %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return gMismatches ? 1 : 0;
}
