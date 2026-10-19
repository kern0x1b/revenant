// cases.m - the convolutional elements iOS 10 added, run twice: once against the system's own MPS
// and once against this port's classes under names of their own. Every case prints the bytes of a
// result the case owns, so the two runs are compared for the results that are exact and against a
// written-down float tolerance for the ones that are not.
//
// The point of the second run is that the port's MPSImage is what holds the values, and it is a
// different class from the host's MPSImage - so a case that reached the host's MPSImage on the port
// side would be comparing the host with itself. `require` says so rather than passing quietly.
//
// What is compared, and what each case is FOR - every rule this harness pins was solved from the
// first run of these cases against the host, and each is one a header-only reading gets wrong:
//   neuron-relu-a0-negative          ReLU is x>=0?x:a*x, so a zero leaves negatives at zero, not at
//                                    their own value. A positive-only source cannot tell this from
//                                    the identity, which is why the source here is negative.
//   neuron-tanh-a3-b0.5              a outside, b inside: 3*tanh(0.5x), not tanh(3x) or 3*tanh(x).
//   cnn-softmax                      ACROSS FEATURE CHANNELS, not across pixels. Two channels whose
//                                    values differ at each pixel, so a pixel-wise softmax would answer
//                                    sixteen different numbers where the right answer is two.
//   cnn-softmax-3ch                  three channels, so a rule that only holds for two is visible.
//   spatial-norm-defaults            the header gives no window at all for this class.
//   spatial-norm-k2                   an EVEN kernel's window reaches BACK: its top left is one pixel
//                                    before the output, which the header's forward rule does not give.
//   local-contrast-defaults          alpha 0 - the declared default - is a local mean subtraction, and
//                                    p0's 1.0 default is what makes the answer negative at the corner.
//   local-contrast-alpha1            the same walk with the denominator carrying a variance.
//   cross-channel-k3                 the divisor is the kernelSize and not the window's length, and
//                                    Q(k) is asymmetric so channel 0 sees two channels and channel 1
//                                    sees all three.
//   cross-channel-k1                 a one-channel window, where the rule reduces to X/(delta+alpha*X^2).
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static id<MTLDevice> gDevice;
static id<MTLCommandQueue> gQueue;

// Which image every compared class resolved in, printed before anything else. A class of the port's
// with the same name as one of the host's is registered once, and a message sent to it reaches
// whichever loaded first - so the comparison says which that was, on every run.
static void printClassImages(void)
{
    NSString *names[] = {
        @"MPSCNNKernel", @"MPSCNNNeuron", @"MPSCNNNeuronLinear", @"MPSCNNNeuronReLU",
        @"MPSCNNNeuronSigmoid", @"MPSCNNNeuronTanH", @"MPSCNNNeuronAbsolute",
        @"MPSCNNSoftMax", @"MPSCNNLogSoftMax", @"MPSCNNSpatialNormalization",
        @"MPSCNNLocalContrastNormalization", @"MPSCNNCrossChannelNormalization",
    };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        Class cls = NSClassFromString(names[i]);
        const char *image = cls ? (class_getImageName(cls) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", names[i].UTF8String, image);
        NSString *charon = [@"Charon" stringByAppendingString:names[i]];
        Class mine = NSClassFromString(charon);
        const char *where = mine ? (class_getImageName(mine) ?: "(none)") : "(absent)";
        printf("image %-38s %s\n", charon.UTF8String, where);
    }
}

// Whether the port has its own copy of a class, under the name the rename header gives it. The rename
// header is generated from the classes the port's objects define, so a class the port does not
// implement is not renamed and the case reaches the host's class instead - which means the case
// compares the host's implementation with the host's implementation and says nothing about this port
// on that class. It is a check that examined nothing, and it has to fail rather than pass quietly.
static BOOL portHas(const char *name)
{
#ifdef CHARON_PORT_BUILD
    NSString *charon = [@"Charon" stringByAppendingString:[NSString stringWithUTF8String:name]];
    return NSClassFromString(charon) != Nil;
#else
    (void)name;
    // The system build links the release's own classes and has no port to ask about, so the question
    // is not asked on that side. The guard is a claim about the port's build, and the port's
    // transcript is the one that carries it; the comparison fails when the port's side has an
    // uncompared case.
    return YES;
#endif
}

static NSUInteger gCompared = 0, gNotCompared = 0;

static BOOL require(const char *caseName, const char *className)
{
    if (portHas(className))
        return YES;
    static NSMutableSet *said = nil;
    if (!said) said = [NSMutableSet set];
    NSString *key = [NSString stringWithFormat:@"%s|%s", caseName, className];
    if (![said containsObject:key]) {
        [said addObject:key];
        printf("case %-28s NOT COMPARED: the port has no %s, so this case reached the host's class"
               " on both sides and compared the host with itself\n", caseName, className);
    }
    gNotCompared++;
    return NO;
}

static void counted(BOOL ran)
{
    if (ran)
        gCompared++;
}

// How many float values one pixel of this texture holds, read off the texture's own pixel format.
// MPSImage13.m picks the Metal format from the channel format and the channel count, and a
// three-channel float image is RGBA32Float - four values wide, not three - so this is asked for rather
// than assumed. Getting it wrong is what answered all zeros on the first run of these cases.
static NSUInteger valuesPerPixelOf(id<MTLTexture> t)
{
    switch (t.pixelFormat) {
    case MTLPixelFormatR32Float: return 1;
    case MTLPixelFormatRG32Float: return 2;
    case MTLPixelFormatRGBA32Float: return 4;
    default: return 4;
    }
}

// The row stride every read and write here uses. A macOS MTLTexture declares no row stride at all -
// -bytesPerRow is an unrecognized selector on AGXG16XFamilyTexture, measured - so it is chosen here,
// 256-byte aligned, which is what Metal wants and is never narrower than the row.
static size_t strideFor(NSUInteger width, NSUInteger valuesPerPixel)
{
    size_t row = width * valuesPerPixel * sizeof(float);
    size_t aligned = ((row + 255) / 256) * 256;
    return aligned ? aligned : 256;
}

static MPSImage *make(NSUInteger w, NSUInteger h, NSUInteger channels, const float *planes)
{
    MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                          width:w height:h featureChannels:channels];
    MPSImage *image = [[MPSImage alloc] initWithDevice:gDevice imageDescriptor:d];
    if (planes) {
        NSUInteger perPixel = valuesPerPixelOf(image.texture);
        size_t stride = strideFor(w, perPixel);
        float *row = calloc(stride / sizeof(float), sizeof(float));
        for (NSUInteger y = 0; y < h; y++) {
            memset(row, 0, stride);
            for (NSUInteger x = 0; x < w; x++)
                for (NSUInteger ch = 0; ch < channels && ch < perPixel; ch++)
                    row[x * perPixel + ch] = planes[ch * w * h + y * w + x];
            [[image texture] replaceRegion:MTLRegionMake2D(0, (NSUInteger)y, w, 1) mipmapLevel:0
                                 withBytes:row bytesPerRow:stride];
        }
        free(row);
    }
    return image;
}

// One case's result: the name, the element count, then the values, in the transcript's own order -
// row-major, and within a row one line per channel, which is the order the transcript is parsed in.
static void dump(const char *name, MPSImage *image, NSUInteger w, NSUInteger h, NSUInteger channels)
{
    NSUInteger perPixel = valuesPerPixelOf(image.texture);
    size_t stride = strideFor(w, perPixel);
    float *row = calloc(stride / sizeof(float), sizeof(float));
    printf("%s %zu\n", name, (size_t)(w * h * channels));
    for (NSUInteger y = 0; y < h; y++) {
        memset(row, 0, stride);
        [[image texture] getBytes:row bytesPerRow:stride
                        fromRegion:MTLRegionMake2D(0, (NSUInteger)y, w, 1) mipmapLevel:0];
        for (NSUInteger ch = 0; ch < channels && ch < perPixel; ch++) {
            printf("  ch%lu row%lu", (unsigned long)ch, (unsigned long)y);
            for (NSUInteger x = 0; x < w; x++)
                printf(" %.9g", row[x * perPixel + ch]);
            printf("\n");
        }
    }
    free(row);
}

static id<MTLCommandBuffer> buffer(void)
{
    return [gQueue commandBufferWithUnretainedReferences];
}

static void run(id<MTLCommandBuffer> b)
{
    [b commit];
    [b waitUntilCompleted];
    if (b.error)
        printf("   buffer error: %s\n", [[b.error description] UTF8String]);
}

// A 4x4 of 1..16 and a ramp of -8..7. The positive ramp tells a scale or an offset apart and the
// negative one tells a ReLU from the identity, which a positive-only source cannot.
static const float k4x4[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
static const float kNeg[16] = {-8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7};
// Two channels: the same ramp and a shuffled one, so a cross-channel rule is visible per pixel.
static const float k2ch[32] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15,
};
// FOUR channels, four ramps, so a channel-window rule is visible in each channel. Four and not three
// because the port's MPSImage has a Metal format for one, two and four feature channels and for no
// other count (MPSImage13.m:49-71) - a three-channel image is refused there, which is a substrate
// limit of that class and not of any kernel here. With kernelSize 3 and four channels every channel
// sees a window of three, and the two edge channels' windows are the clipped ones.
static const float k4ch[64] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32,
    5, 1, 5, 1, 5, 1, 5, 1, 5, 1, 5, 1, 5, 1, 5, 1,
    16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
};

static void neuronCases(void)
{
    if (!require("neuron-relu", "MPSCNNNeuronReLU") || !require("neuron-relu", "MPSImage") ||
        !require("neuron-relu", "MPSImageDescriptor")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronReLU *k = [[MPSCNNNeuronReLU alloc] initWithDevice:gDevice a:0.0f];
        printf("relu-defaults a=%g b=%g c=%g\n", k.a, k.b, k.c);
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-relu-a0-positive", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, kNeg), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronReLU *k = [[MPSCNNNeuronReLU alloc] initWithDevice:gDevice a:0.0f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-relu-a0-negative", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, kNeg), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronReLU *k = [[MPSCNNNeuronReLU alloc] initWithDevice:gDevice a:0.25f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-relu-a0.25-negative", d, 4, 4, 1);
    }
}

static void neuronRestCases(void)
{
    if (!require("neuron-rest", "MPSCNNNeuronLinear") || !require("neuron-rest", "MPSCNNNeuronSigmoid") ||
        !require("neuron-rest", "MPSCNNNeuronTanH") || !require("neuron-rest", "MPSCNNNeuronAbsolute")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronLinear *k = [[MPSCNNNeuronLinear alloc] initWithDevice:gDevice a:2.0f b:0.5f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-linear-a2-b0.5", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronSigmoid *k = [[MPSCNNNeuronSigmoid alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-sigmoid", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronTanH *k = [[MPSCNNNeuronTanH alloc] initWithDevice:gDevice a:1.0f b:1.0f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-tanh-a1-b1", d, 4, 4, 1);
    }
    {
        // a outside, b inside. 3*tanh(0.5) is 1.38635159 and tanh(1.5) is 0.905148253, so the two
        // orders are told apart by the first value alone.
        MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronTanH *k = [[MPSCNNNeuronTanH alloc] initWithDevice:gDevice a:3.0f b:0.5f];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-tanh-a3-b0.5", d, 4, 4, 1);
    }
    {
        MPSImage *s = make(4, 4, 1, kNeg), *d = make(4, 4, 1, NULL);
        MPSCNNNeuronAbsolute *k = [[MPSCNNNeuronAbsolute alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("neuron-absolute-negative", d, 4, 4, 1);
    }
}

static void softMaxCases(void)
{
    if (!require("softmax", "MPSCNNSoftMax") || !require("logsoftmax", "MPSCNNLogSoftMax")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 2, k2ch), *d = make(4, 4, 2, NULL);
        MPSCNNSoftMax *k = [[MPSCNNSoftMax alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cnn-softmax", d, 4, 4, 2);
    }
    {
        MPSImage *s = make(4, 4, 2, k2ch), *d = make(4, 4, 2, NULL);
        MPSCNNLogSoftMax *k = [[MPSCNNLogSoftMax alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cnn-logsoftmax", d, 4, 4, 2);
    }
    {
        // Four channels, so a rule that only holds for two is visible: every row of the answer must
        // be a probability distribution over the four channels at that pixel.
        MPSImage *s = make(4, 4, 4, k4ch), *d = make(4, 4, 4, NULL);
        MPSCNNSoftMax *k = [[MPSCNNSoftMax alloc] initWithDevice:gDevice];
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cnn-softmax-4ch", d, 4, 4, 4);
    }
}

static void normalizationCases(void)
{
    if (!require("spatial", "MPSCNNSpatialNormalization")) {
        counted(NO);
    } else {
        counted(YES);
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:3 kernelHeight:3];
            printf("spatial-defaults alpha=%g beta=%g delta=%g kw=%lu kh=%lu\n", k.alpha, k.beta, k.delta,
                   (unsigned long)k.kernelWidth, (unsigned long)k.kernelHeight);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-defaults", d, 4, 4, 1);
        }
        {
            // An EVEN kernel. Kept because its defaults are a case of their own, but note that kw=2
            // CANNOT tell a centred window from a backward one: -(2/2) = -1 and -2+1 = -1 are the same
            // two pixels. The case that pins the rule is kw=3 below.
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:2 kernelHeight:2];
            printf("spatial-k2 kw=%lu kh=%lu\n", (unsigned long)k.kernelWidth, (unsigned long)k.kernelHeight);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-k2", d, 4, 4, 1);
        }
        {
            // THE CASE THAT PINS THE WINDOW. kw=3 is where a centred window (first = -1) and a backward
            // one (first = -2) are different windows, so this case tells them apart; kw=2 does not, and
            // an earlier version of this harness leaned on kw=2 and so proved nothing. A 5-wide window
            // is here too: -(5/2) = -2 against -5+1 = -4, which is four pixels of difference.
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:3 kernelHeight:3];
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-k3", d, 4, 4, 1);
        }
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNSpatialNormalization *k = [[MPSCNNSpatialNormalization alloc] initWithDevice:gDevice
                                                                                   kernelWidth:5 kernelHeight:5];
            printf("spatial-k5 kw=%lu kh=%lu\n", (unsigned long)k.kernelWidth, (unsigned long)k.kernelHeight);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("spatial-norm-k5", d, 4, 4, 1);
        }
    }
    if (!require("local-contrast", "MPSCNNLocalContrastNormalization")) {
        counted(NO);
    } else {
        counted(YES);
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNLocalContrastNormalization *k = [[MPSCNNLocalContrastNormalization alloc] initWithDevice:gDevice
                                                                                                     kernelWidth:3 kernelHeight:3];
            printf("localcontrast-defaults alpha=%g beta=%g delta=%g p0=%g pm=%g ps=%g\n",
                   k.alpha, k.beta, k.delta, k.p0, k.pm, k.ps);
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("local-contrast-defaults", d, 4, 4, 1);
        }
        {
            MPSImage *s = make(4, 4, 1, k4x4), *d = make(4, 4, 1, NULL);
            MPSCNNLocalContrastNormalization *k = [[MPSCNNLocalContrastNormalization alloc] initWithDevice:gDevice
                                                                                                     kernelWidth:3 kernelHeight:3];
            k.alpha = 1.0f;
            id<MTLCommandBuffer> b = buffer();
            [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
            run(b);
            dump("local-contrast-alpha1", d, 4, 4, 1);
        }
    }
    if (!require("cross-channel", "MPSCNNCrossChannelNormalization")) {
        counted(NO);
        return;
    }
    counted(YES);
    {
        MPSImage *s = make(4, 4, 4, k4ch), *d = make(4, 4, 4, NULL);
        MPSCNNCrossChannelNormalization *k = [[MPSCNNCrossChannelNormalization alloc] initWithDevice:gDevice kernelSize:3];
        printf("crosschannel-defaults alpha=%g beta=%g delta=%g kernelSize=%lu\n",
               k.alpha, k.beta, k.delta, (unsigned long)k.kernelSize);
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cross-channel-k3", d, 4, 4, 4);
    }
    {
        MPSImage *s = make(4, 4, 4, k4ch), *d = make(4, 4, 4, NULL);
        MPSCNNCrossChannelNormalization *k = [[MPSCNNCrossChannelNormalization alloc] initWithDevice:gDevice kernelSize:1];
        printf("crosschannel-k1 kernelSize=%lu\n", (unsigned long)k.kernelSize);
        id<MTLCommandBuffer> b = buffer();
        [k encodeToCommandBuffer:b sourceImage:s destinationImage:d];
        run(b);
        dump("cross-channel-k1", d, 4, 4, 4);
    }
}

int main(void)
{
    @autoreleasepool {
        setbuf(stdout, NULL);
        gDevice = MTLCreateSystemDefaultDevice();
        if (!gDevice) { printf("no device\n"); return 1; }
        gQueue = [gDevice newCommandQueue];
        printf("device %s\n", [[gDevice name] UTF8String]);
        printClassImages();
        neuronCases();
        neuronRestCases();
        softMaxCases();
        normalizationCases();
        printf("compared: %lu cases, %lu not compared\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
        if (gCompared == 0) {
            printf("this run compared nothing: every case needs a class the port does not have, and a run"
                   " that compared nothing is not a pass\n");
            return 1;
        }
        if (gNotCompared) {
            printf("this run compared %lu cases and left %lu uncompared; the uncompared ones are named"
                   " above and are not passes\n", (unsigned long)gCompared, (unsigned long)gNotCompared);
            return 1;
        }
    }
    return 0;
}
