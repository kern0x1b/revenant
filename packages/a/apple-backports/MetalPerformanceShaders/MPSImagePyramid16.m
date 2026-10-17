// MPSImagePyramid, the base class "for creating different kinds of pyramid images"
// (MPSImageConvolution.h:495), from the iPhoneOS 16.4 surface of MPSImageConvolution.h.
//
// One object for one release, and the release's own measurement is the judge rather than the header's
// annotation. MPSImageConvolution.h:519 annotates this class ios(10.0), and the registry's
// sdk-26.2-surface.tsv carries 10.0 for it, so this object's registry rows keep `introduced` at what
// the SDK declares. But the release does not EXPORT it until 16.0, and an object's placement is
// decided by what a client can bind, not by whether the name is in the cache:
//
//   * tools/cache-index/first-rung.lua answers 10.0.1 for _OBJC_CLASS_$_MPSImagePyramid, and that is
//     TRUE and not the question: first-rung measures whether a rung CARRIES a name, and this one
//     carries it from 10.0.1 because MPSImageGaussianPyramid's super_class points at it.
//   * tools/release-split.lua measures what a rung EXPORTS, and answers 16.0 - which is what
//     modules/apple/backports.lua's band() places an object by, and what makes an object carrying
//     this class and MPSImageGaussianPyramid (10.0.1) a file that band() refuses with "an object
//     carries API that arrived in one release, so split it". Both run over the held ladder and agree.
//
// MEASURED over the held armv7/armv7s ladder, the MPS* names each rung's export trie carries that
// contain "Pyramid": 10.0.1 and 11.0 export MPSImageGaussianPyramid and no MPSImagePyramid; 12.0 adds
// MPSImageLaplacianPyramid, +Add and +Subtract and still no MPSImagePyramid; 16.0 adds
// _OBJC_CLASS_$_MPSImagePyramid and _OBJC_METACLASS_$_MPSImagePyramid. So the kernels over this class
// are exported BEFORE it, which is why MPSImagePyramid10.m and MPSImageLaplacianPyramid12.m can both
// read the filter this object publishes and neither needs to ask whether it is there: a band keeps an
// object exactly when the release does not export it, so a band that keeps either kernel - below 10.0.1
// and below 12.0 respectively - is below 16.0 and keeps this one too. What the three objects share is in
// CharonMPSPyramid.h.
//
// AND THE NAME IS AN ALIAS, because from 10.0.1 the release carries this class without exporting it,
// which is the window MPSImagePyramid10.m's own comment above describes: carried from 10.0.1 (measured
// with apple.objc.inventory over the armv7s caches of 10.0.1, 10.1, 10.2, 10.3 and 10.3.4 - superclass
// MPSUnaryImageKernel, seven own methods: -initWithDevice:, -initWithDevice:centerWeight:,
// -initWithDevice:kernelWidth:kernelHeight:weights:, -kernelWidth, -kernelHeight, -dealloc and
// -copyWithZone:device:) and exported by no image of any of them, measured with apple.dyld over the
// same caches' export tries; 11.0 (arm64) carries it in MPSImage.framework and still exports no
// symbol). So a band of 10.0.1 to 10.3.4 that linked a class implementation of this name held two
// classes of one name in every process, and the runtime keeps the one it registered first. The name
// goes through charon_alias.h, which is what modules/apple/backports.lua's own check_categories asks
// for when it reads this reading ("the release carries MPSImagePyramid in MetalPerformanceShaders
// without exporting it: alias it through charon_alias.h") and what MDLMeshBufferZoneDefault,
// HKCDADocument, NSTextList and NSTextTab already are for the same one.
//
// What that costs this file, measured over the same caches and read out of attach.c:
//
//   * On a band below 10.0.1 the release has no class of this name at all, the proxy IS the class, and
//     every member below answers out of the state beside it - which is what MPSImagePyramid10.m's
//     Gaussian kernel and MPSImageLaplacianPyramid12.m's two inherit and read.
//   * On 10.0.1 to 10.3.4 the release's class is found, the proxy is re-parented under it, and
//     attach.c's charon_adopt_methods REPLACES the proxy's own copy of every member the release's class
//     already has - which here is all five of them (the list above). So on those bands a subclass of
//     ours that a program constructs gets the RELEASE's initializers, and the filter's weights are then
//     in the release's own private storage, which no header declares and which this port therefore
//     cannot read. MPSImageLaplacianPyramid12.m's two kernels read the weights through
//     -charon_mps_filter, and they refuse there with that reason rather than reading weights this port
//     never wrote. MPSImagePyramid10.m's Gaussian is not in those bands at all: the release exports
//     MPSImageGaussianPyramid from 10.0.1, so band() reexports that object there.
//   * From 16.0 the release exports the name and the band links neither this object nor the proxy. No
//     band of this machine reaches 16.0: the armv7 ladder ends at 9.3.6 and armv7s at 10.3.4.
//
// THE FILTER, which every pyramid here uses and which the header gives three ways.
//   the default (MPSImageConvolution.h:505-506): the outer product of w with itself, where
//     w = the binomial weights 1, 4, 6, 4 and 1, each divided by 16, as a column
//   by a centre weight (:527-528): the outer product of w with its own transpose, where
//     w = [ (0.25 - a/2),  0.25,  a,  0.25,  (0.25 - a/2) ]^T
//   or the caller's own (:548-552, row major, kernelWidth * kernelHeight values)
// The kernel must be odd in both directions (:562-569), and that is refused by name rather than
// answered with a filter the header does not describe.
//
// WHAT IS NOT CLAIMED. No number in this file is a measurement of Apple's code - the release's own MPS
// crashes on this family's encode, which facts/MetalPerformanceShaders/Elements10.md records with its
// transcript. What is written here is transcribed from the header above; what has been checked is the
// armv7 link, that this object defines the class it says.

#import "CharonMPSPyramid.h"
#import "../charon_alias.h"

// The filter's own weights, row major, and the two sizes, held beside the pyramid: a category cannot
// add an instance variable and neither can the class behind an alias, because attach.c lays the proxy
// out from the release's class and takes that write back when the two instance sizes differ. It is one
// NSMutableData and two integers rather than the three ivars this object used to have, and the three
// seams below are the same three readers either way.
@interface CharonMPSPyramidFilter : NSObject
@property (nonatomic, strong) NSMutableData *weights;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@end

@implementation CharonMPSPyramidFilter

@synthesize weights = _weights;
@synthesize width = _width;
@synthesize height = _height;

@end

// The class the release's name stands for, and nothing else: its superclass is the SDK's own
// MPSUnaryImageKernel, which is the port's own below 10.0.1 (the release exports MPSUnaryImageKernel
// from 10.0.1, measured with apple.dyld over the armv7s caches of 10.0.1 and 10.3.4) and the release's
// own above it, which is what CHARON_ALIAS_OF declares.
CHARON_ALIAS_OF(MPSImagePyramid, MPSUnaryImageKernel)

@implementation CHARON_ALIAS_CLASS(MPSImagePyramid) (CharonMPSPyramidFilter)

// MPSImageConvolution.h marks -initWithDevice:kernelWidth:kernelHeight:weights: the designated
// initializer of MPSImagePyramid (:578 area) and -initWithCoder:device: another, and this class refuses
// the coder form because the release's keys for a filter are in no header, so it cannot chain to a
// designated initializer of its own. The same pragma MPSImage9.m carries for the same reason.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static CharonMPSPyramidFilter *CharonMPSPyramidFilterOf(id pyramid)
{
    static const void *key = &key;
    CharonMPSPyramidFilter *filter = objc_getAssociatedObject(pyramid, key);
    if (!filter) {
        filter = [[CharonMPSPyramidFilter alloc] init];
        objc_setAssociatedObject(pyramid, key, filter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return filter;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device kernelWidth:(NSUInteger)kernelWidth kernelHeight:(NSUInteger)kernelHeight weights:(const float *)kernelWeights
{
    if (!(self = [super initWithDevice:device]))
        return nil;
    if (!kernelWidth || !kernelHeight || !kernelWeights ||
        (kernelWidth % 2) == 0 || (kernelHeight % 2) == 0) {
        CharonMPSRefuse(@"MPSImagePyramid: a %lu by %lu kernel with weights %s is refused;"
                        @" the width and the height must be odd",
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight,
                        kernelWeights ? "given" : "not given");
        return nil;
    }
    CharonMPSPyramidFilter *filter = CharonMPSPyramidFilterOf(self);
    filter.width = kernelWidth;
    filter.height = kernelHeight;
    filter.weights = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
    if (!filter.weights) {
        CharonMPSRefuse(@"MPSImagePyramid: no memory for a %lux%lu kernel, so no object was made",
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return nil;
    }
    [filter.weights replaceBytesInRange:NSMakeRange(0, kernelWidth * kernelHeight * sizeof(float)) withBytes:kernelWeights];
    return self;
}

// The default filter of :505-506, w = [ 1/16, 1/4, 3/8, 1/4, 1/16 ]^T as the outer product ww^T.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    float w[5] = { 1.0f / 16.0f, 1.0f / 4.0f, 3.0f / 8.0f, 1.0f / 4.0f, 1.0f / 16.0f };
    float kernel[25];
    for (NSUInteger ky = 0; ky < 5; ky++)
        for (NSUInteger kx = 0; kx < 5; kx++)
            kernel[ky * 5 + kx] = w[ky] * w[kx];
    return [self initWithDevice:device kernelWidth:5 kernelHeight:5 weights:kernel];
}

// The centre weight of :527-528: w = [ (1/4 - a/2),  1/4,  a,  1/4,  (1/4 - a/2) ]^T as the outer product.
- (instancetype)initWithDevice:(id<MTLDevice>)device centerWeight:(float)centerWeight
{
    float edge = 1.0f / 4.0f - centerWeight / 2.0f;
    float w[5] = { edge, 1.0f / 4.0f, centerWeight, 1.0f / 4.0f, edge };
    float kernel[25];
    for (NSUInteger ky = 0; ky < 5; ky++)
        for (NSUInteger kx = 0; kx < 5; kx++)
            kernel[ky * 5 + kx] = w[ky] * w[kx];
    return [self initWithDevice:device kernelWidth:5 kernelHeight:5 weights:kernel];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    // For the reason MPSImageConvolution13.m gives for its own: the release's keys for a kernel's filter
    // are in no header, so an invented key would read an archive the release never wrote. Not recorded
    // as round-tripping; the initializers above are the way to make one.
    (void)aDecoder;
    (void)device;
    CharonMPSRefuse(@"MPSImagePyramid: -initWithCoder:device: is not carried - the release's keys for a"
                    @" pyramid's filter are in no header, so a decoder cannot rebuild them honestly");
    return nil;
}

- (NSUInteger)kernelWidth { return CharonMPSPyramidFilterOf(self).width; }
- (NSUInteger)kernelHeight { return CharonMPSPyramidFilterOf(self).height; }

// The three the kernels over this class read. The names are Charon's own: no SDK header declares them.
// A pyramid made on a band where the release's own class took over the initializers has no state here,
// and its readers answer NULL and 0 - which is what MPSImageLaplacianPyramid12.m refuses on, by name,
// rather than reading weights it never wrote.
- (const float *)charon_mps_filter { return (const float *)[CharonMPSPyramidFilterOf(self).weights bytes]; }
- (NSUInteger)charon_mps_filterWidth { return CharonMPSPyramidFilterOf(self).width; }
- (NSUInteger)charon_mps_filterHeight { return CharonMPSPyramidFilterOf(self).height; }

@end