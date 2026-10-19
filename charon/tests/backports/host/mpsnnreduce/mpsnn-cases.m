// mpsnn-cases.m - is this port's MPSNNReduce the same arithmetic as the header's own sentence?
//
// Compiled twice and run twice, the way tests/backports/host/mpscnn/run.sh does it: once against the
// system's own MPS, once against this port's classes with the MPS names mapped to Charon names and
// their selectors prefixed, so the port's implementations are reached under names of their own and
// cannot be the system's.
//
// WHAT IS COMPARED, and what is not. The system run exists so the harness can say what the RELEASE
// answers, and on this machine it answers nothing: the system's own MPSNNReduceRowSum dies encoding
// with '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized
// selector, because this host's AGX family does not implement the encoder the framework calls. So the
// comparison that carries weight is port against CharonNNReduceReference.h, which is the header's
// twelve per-class sentences written as arithmetic in plain C and never names the port's class. The
// system run is kept and its result printed, because "the release could not be asked" is a fact a
// reader wants on the transcript rather than in a comment.
//
// THE CLASSES ARE NAMED AS CLASSES and not as strings, which is the whole point of the rename header:
// NSClassFromString is not rewritten by it, so a string literal here would silently reach the
// RELEASE's class and the case would measure the release twice. That is not hypothetical - it is what
// the first version of the mpsimage reduce case did, and it crashed in the release's own encoder.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import "CharonNNReduceReference.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

NSUInteger gCompared = 0;
NSUInteger gMismatches = 0;

static id<MTLDevice> CharonDevice(void)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        fprintf(stderr, "no Metal device on this host, so there is nothing to walk an image with\n");
        exit(2);
    }
    return device;
}

// The source: values chosen so that every operation is distinguishable. A window of 3 rows by 4
// columns by 3 channels, filled with a fixed arithmetic sequence rather than a constant, because a
// constant source makes min, max and sum agree with each other and a walk that transposed its axes
// would still pass. These are the numbers, and the reference reads the same array:
//
//   channel 0:   1   2   3   4        channel 1:  10  20  30  40
//                5   6   7   8                     50  60  70  80
//               9  10  11  12                    90 100 110 120
//   channel 2: -1  -2  -3  -4                    -5  -6  -7  -8
//               -9 -10 -11 -12                   -13 -14 -15 -16
//              -17 -18 -19 -20                   -21 -22 -23 -24
//   channel 3: 0.5 1.5 2.5 3.5                    -0.5 -1.5 -2.5 -3.5
//               4.5 5.5 6.5 7.5                     8.5 9.5 10.5 11.5
//              12.5 13.5 14.5 15.5                 -12.5 -13.5 -14.5 -15.5
//
// FOUR channels, not three, and the reason is the port's own and the release's: MPSImage13.m:50-72 maps
// a channel count to a Metal pixel format for 1, 2 and 4 only, and refuses anything else by name
// ("channel format 4 with 3 feature channels has no Metal pixel format, so no texture was made"), so a
// three-channel image holds no texture on either side and there is nothing to walk. Four is also the
// stronger test of a feature-channel reduction: the fourth channel is the only one holding fractions, so
// a walk that scaled by the weight but read the wrong plane would answer in a way no other axis could.
//
// A negative channel is in the source on purpose: a reduction that seeded its running minimum from
// src[0] would answer 1.0 for every row run, and the first value of channel 0 is 1 while the rest of
// its rows start at 5 and 9. Channel 2 is negative throughout, so a min over it cannot be confused with
// a max, and the four channels are far enough apart that a feature-channel reduction over one pixel
// cannot be satisfied by reading a single channel.
static const float kSource[3 * 4 * 4] = {
     1,  10,  -1, 0.5,   2,  20,  -2, 1.5,   3,  30,  -3, 2.5,   4,  40,  -4, 3.5,
     5,  50,  -5, 4.5,   6,  60,  -6, 5.5,   7,  70,  -7, 6.5,   8,  80,  -8, 7.5,
     9,  90,  -9, 8.5,  10, 100, -10, 9.5,  11, 110, -11, 10.5,  12, 120, -12, 11.5,
};

#define ROWS 3
#define COLS 4
#define CHANNELS 4

static MPSImage *CharonMakeSource(id<MTLDevice> device)
{
    MPSImageDescriptor *descriptor =
        [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                         width:COLS
                                                        height:ROWS
                                                featureChannels:CHANNELS];
    MPSImage *image = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
    [[image texture] replaceRegion:MTLRegionMake2D(0, 0, COLS, ROWS) mipmapLevel:0
                          withBytes:kSource bytesPerRow:COLS * CHANNELS * sizeof(float)];
    return image;
}

// The stride is the IMAGE's own width times its own channel count, never the source's: a row or column
// reduction's destination is 1 wide and a feature-channel one's holds a single plane, so reading either
// with the source's 4-wide stride reads past the end of the row. That was the first run's defect and it
// showed up as mismatches on exactly the runs whose row is shorter than the source's.
static void CharonReadBack(MPSImage *image, float *out, NSUInteger cols, NSUInteger rows, NSUInteger channels)
{
    memset(out, 0, cols * rows * channels * sizeof(float));
    [[image texture] getBytes:out bytesPerRow:cols * channels * sizeof(float)
                     fromRegion:MTLRegionMake2D(0, 0, cols, rows) mipmapLevel:0];
}

// The twelve concrete classes, in the header's own order: min, max, mean and sum for each of the three
// axes. The class is named as a CLASS so the rename header rewrites it and this build reaches the
// port's class rather than the release's.
static Class CharonReduceClass(int index)
{
    // a LOCAL, not a static: `[MPSNNReduceRowMin class]` is a message send and not a compile-time
    // constant, so it cannot initialise a static array. mpsimage/image-cases.m:449 builds the same
    // table as a local for the same reason.
    Class classes[12] = {
        [MPSNNReduceRowMin class],              [MPSNNReduceColumnMin class],
        [MPSNNReduceFeatureChannelsMin class],  [MPSNNReduceRowMax class],
        [MPSNNReduceColumnMax class],           [MPSNNReduceFeatureChannelsMax class],
        [MPSNNReduceRowMean class],             [MPSNNReduceColumnMean class],
        [MPSNNReduceFeatureChannelsMean class], [MPSNNReduceRowSum class],
        [MPSNNReduceColumnSum class],           [MPSNNReduceFeatureChannelsSum class],
    };
    return classes[index];
}

static const char *CharonReduceName(int index)
{
    static const char *names[12] = {
        "reduce-row-min",              "reduce-column-min",              "reduce-feature-channels-min",
        "reduce-row-max",              "reduce-column-max",              "reduce-feature-channels-max",
        "reduce-row-mean",             "reduce-column-mean",             "reduce-feature-channels-mean",
        "reduce-row-sum",              "reduce-column-sum",              "reduce-feature-channels-sum",
    };
    return names[index];
}

static int CharonReduceByColumn(int index)  { return (index % 3) == 1; }
static int CharonReduceByFeature(int index) { return (index % 3) == 2; }
static CharonNNReduceOp CharonReduceOp(int index) { return (CharonNNReduceOp)(index / 3); }

int main(int argc, const char **argv)
{
    int fromSystem = (argc > 1 && strcmp(argv[1], "--system") == 0);
    id<MTLDevice> device = CharonDevice();
    // A command buffer from a QUEUE, which is how mpscnn/cnn-cases.m:129-131 gets one and the only
    // form that works on both sides of this comparison. NOT [device newCommandBuffer]: on this SDK
    // that returns an MTL4CommandBuffer, and its -commit is itself an unrecognized selector on this
    // host's AGX family - a second and separate reason the release's own kernel cannot run here, and
    // one this file records rather than trips over. The port's own MTLCommandBuffer is renamed with
    // the rest of the port's classes, so a queue's buffer reaches the port's kernel as the port's own.
    id<MTLCommandQueue> queue = [device newCommandQueue];

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);

    for (int index = 0; index < 12; index++) {
        // The base's -initWithDevice: is NS_UNAVAILABLE (MPSNNReduce.h:44-47), so every case names a
        // concrete class. An absent kernel is a MISMATCH and not a case that reports nothing: a case
        // line with no values would leave the reference nothing to compare, gCompared would not move,
        // and the harness would report success over zero elements.
        Class kernelClass = CharonReduceClass(index);
        NSString *present = kernelClass ? NSStringFromClass(kernelClass) : @"(nil)";
        printf("port  %-28s class %s\n", CharonReduceName(index), [present UTF8String]);

        if (fromSystem) {
            // The release's own kernel. On this host it dies here, and that is the measurement the
            // mpsimage facts record: the AGX family lacks computeCommandEncoderWithDispatchType:.
            // It is attempted, and what it does is what the transcript says.
            @try {
                id oneBuffer = [queue commandBufferWithUnretainedReferences];
                id kernel = [[kernelClass alloc] initWithDevice:device];
                MPSImage *source = CharonMakeSource(device);
                [kernel encodeToCommandBuffer:oneBuffer sourceImage:source destinationImage:source];
                [oneBuffer commit];
                [oneBuffer waitUntilCompleted];
                printf("      system: encoded\n");
            } @catch (NSException *exception) {
                printf("      system: %s: %s\n", [[exception name] UTF8String],
                       [[exception reason] UTF8String]);
            }
            continue;
        }

        MPSImage *source = CharonMakeSource(device);
        // The destination the header's count forces, and no larger: a row or column reduction answers
        // one value per row or column PER CHANNEL, a feature-channel reduction one per pixel into one
        // plane. The refusal in the port is exercised by the too-small destination at the end of this
        // function, so the shape is stated here and checked there.
        NSUInteger dstCols = CharonReduceByFeature(index) ? COLS : (CharonReduceByColumn(index) ? COLS : 1);
        NSUInteger dstRows = CharonReduceByFeature(index) ? ROWS : (CharonReduceByColumn(index) ? 1 : ROWS);
        NSUInteger dstChannels = CharonReduceByFeature(index) ? 1 : CHANNELS;
        MPSImageDescriptor *descriptor =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                             width:dstCols
                                                            height:dstRows
                                                    featureChannels:dstChannels];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];

        id kernel = [[kernelClass alloc] initWithDevice:device];
        // A FRESH command buffer per case: a committed one cannot be committed again, and the twelve
        // cases each encode once.
        id commandBuffer = [queue commandBufferWithUnretainedReferences];
        // Only MPSNNReduceFeatureChannelsSum declares `weight` (MPSNNReduce.h:413-420; the release's
        // own cache gives -weight and -setWeight: to that class alone). A weight of 0.5 is set here so
        // the multiply is a real one rather than a multiply by the 1.0 default, which would pass
        // whether the port applied it or not.
        int weighted = 0;
        if (CharonReduceByFeature(index) && [kernel respondsToSelector:@selector(setWeight:)]) {
            [kernel setWeight:0.5f];
            weighted = 1;
        }

        [kernel encodeToCommandBuffer:commandBuffer sourceImage:source destinationImage:destination];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        float got[ROWS * COLS * CHANNELS];
        CharonReadBack(destination, got, dstCols, dstRows, dstChannels);

        // The reference, in the destination's own layout. `weighted` is 1 only for the class that
        // declares the property, which is MPSNNReduceFeatureChannelsSum alone, so the three other
        // feature-channel classes reduce the source's own values.
        CharonNNReduceReference(CharonReduceName(index), kSource, ROWS, COLS, CHANNELS,
                                CharonReduceByColumn(index), CharonReduceByFeature(index),
                                CharonReduceOp(index), 0.5f, weighted, got, dstCols, dstChannels);
    }

    // The refusal, on its own: a destination too small for the count must be refused BY NAME and write
    // nothing, because a write past the edge of a texture is an assertion in the release and an
    // unreadable answer here. A case that only ever walks correctly-shaped destinations would not
    // notice a walk that wrote outside one.
    {
        Class kernelClass = CharonReduceClass(9);       // reduce-row-sum
        MPSImage *source = CharonMakeSource(device);
        // 1 wide and 1 tall with ONE channel, against a source of 3 rows, 4 columns and 4 channels:
        // a row reduction answers 3 rows x 4 channels = 12 values and this destination holds 1. The
        // numbers are named here so the case is a statement about the count rather than about the
        // guard's internals.
        MPSImageDescriptor *tooSmall =
            [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                             width:1
                                                            height:1
                                                    featureChannels:1];
        MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:tooSmall];
        // A KNOWN value in the destination before the encode, so "nothing was written" is a question
        // about the texture rather than about a local. The first version of this case set a local to
        // -1.0f and then read the TEXTURE back, which is a different object entirely and reads as
        // whatever was allocated - so the check compared two unrelated things and passed or failed by
        // accident. A refusal that left the destination alone is now visible as the value surviving.
        const float sentinel = -12345.0f;
        [[destination texture] replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
                                 withBytes:&sentinel bytesPerRow:sizeof(float)];
        id refusalBuffer = [queue commandBufferWithUnretainedReferences];
        id kernel = [[kernelClass alloc] initWithDevice:device];
        [kernel encodeToCommandBuffer:refusalBuffer sourceImage:source destinationImage:destination];
        [refusalBuffer commit];
        [refusalBuffer waitUntilCompleted];
        float got[1] = {0.0f};
        CharonReadBack(destination, got, 1, 1, 1);
        gCompared++;
        if (got[0] != sentinel) {
            gMismatches++;
            printf("\n  MISMATCH a destination too small for the count was written to anyway: %g,"
                   " and the value there was %g before the encode\n", got[0], sentinel);
        }
        printf("\n  refusal reduce-row-sum into a 1x1x1 destination: left as it was (%g)\n", got[0]);
    }

    // THE WEIGHT'S SCOPE, as its own case. MPSNNReduce.h:413-420 puts `weight` on
    // MPSNNReduceFeatureChannelsSum alone and says each channel is scaled by the weight before the sum or mean is formed, so a weight must not reach a minimum or a maximum, and that is a
    // claim about the BASE's storage, which every feature-channel class reads.
    //
    // It cannot be seen from the twelve cases above, and that is why it is here: the only class that
    // declares a property is a sum, so no case can set a weight on a min or a max through the API. What
    // this does is set a weight through the one class that has it - which writes the base's storage,
    // because the accessors are the base's - and then ask the MIN and MAX feature-channel classes what
    // they answer with that weight present. A port that applied the weight to every operation would
    // answer halved minima and maxima here, and the mutation campaign's weight-scope site is this case.
    {
        MPSImage *source = CharonMakeSource(device);
        // the class that declares the property, so the weight reaches the base's one piece of storage
        id sum = [[CharonReduceClass(11) alloc] initWithDevice:device];
        [sum setWeight:0.5f];

        for (int which = 2; which <= 5; which += 3) {   // 2 = feature-channel min, 5 = feature-channel max
            MPSImageDescriptor *descriptor =
                [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                 width:COLS
                                                                height:ROWS
                                                        featureChannels:1];
            MPSImage *destination = [[MPSImage alloc] initWithDevice:device imageDescriptor:descriptor];
            id kernel = [[CharonReduceClass(which) alloc] initWithDevice:device];
            id buffer = [queue commandBufferWithUnretainedReferences];
            [kernel encodeToCommandBuffer:buffer sourceImage:source destinationImage:destination];
            [buffer commit];
            [buffer waitUntilCompleted];
            float got[ROWS * COLS];
            CharonReadBack(destination, got, COLS, ROWS, 1);
            // the UNWEIGHTED reference: a weight is not this operation's
            CharonNNReduceReference(CharonReduceName(which), kSource, ROWS, COLS, CHANNELS,
                                    0, 1, CharonReduceOp(which), 1.0f, 0, got, COLS, 1);
        }
    }

    printf("compared %lu mismatches %lu\n", (unsigned long)gCompared, (unsigned long)gMismatches);
    return 0;
}
