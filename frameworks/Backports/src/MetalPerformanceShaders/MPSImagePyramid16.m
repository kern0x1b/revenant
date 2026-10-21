#import "RevenantMPSPyramid.h"
#import "../revenant_alias.h"

@interface RevenantMPSPyramidFilter : NSObject
@property (nonatomic, strong) NSMutableData *weights;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@end

@implementation RevenantMPSPyramidFilter

@synthesize weights = _weights;
@synthesize width = _width;
@synthesize height = _height;

@end

REVENANT_ALIAS_OF(MPSImagePyramid, MPSUnaryImageKernel)

@implementation REVENANT_ALIAS_CLASS(MPSImagePyramid) (RevenantMPSPyramidFilter)

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static RevenantMPSPyramidFilter *RevenantMPSPyramidFilterOf(id pyramid)
{
    static const void *key = &key;
    RevenantMPSPyramidFilter *filter = objc_getAssociatedObject(pyramid, key);
    if (!filter) {
        filter = [[RevenantMPSPyramidFilter alloc] init];
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
        RevenantMPSRefuse(@"MPSImagePyramid: a %lu by %lu kernel with weights %s is refused;"
                        @" the width and the height must be odd",
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight,
                        kernelWeights ? "given" : "not given");
        return nil;
    }
    RevenantMPSPyramidFilter *filter = RevenantMPSPyramidFilterOf(self);
    filter.width = kernelWidth;
    filter.height = kernelHeight;
    filter.weights = [NSMutableData dataWithLength:kernelWidth * kernelHeight * sizeof(float)];
    if (!filter.weights) {
        RevenantMPSRefuse(@"MPSImagePyramid: no memory for a %lux%lu kernel, so no object was made",
                        (unsigned long)kernelWidth, (unsigned long)kernelHeight);
        return nil;
    }
    [filter.weights replaceBytesInRange:NSMakeRange(0, kernelWidth * kernelHeight * sizeof(float)) withBytes:kernelWeights];
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    float w[5] = { 1.0f / 16.0f, 1.0f / 4.0f, 3.0f / 8.0f, 1.0f / 4.0f, 1.0f / 16.0f };
    float kernel[25];
    for (NSUInteger ky = 0; ky < 5; ky++)
        for (NSUInteger kx = 0; kx < 5; kx++)
            kernel[ky * 5 + kx] = w[ky] * w[kx];
    return [self initWithDevice:device kernelWidth:5 kernelHeight:5 weights:kernel];
}

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
    (void)aDecoder;
    (void)device;
    RevenantMPSRefuse(@"MPSImagePyramid: -initWithCoder:device: is not carried - the release's keys for a"
                    @" pyramid's filter are in no header, so a decoder cannot rebuild them honestly");
    return nil;
}

- (NSUInteger)kernelWidth { return RevenantMPSPyramidFilterOf(self).width; }
- (NSUInteger)kernelHeight { return RevenantMPSPyramidFilterOf(self).height; }

- (const float *)revenant_mps_filter { return (const float *)[RevenantMPSPyramidFilterOf(self).weights bytes]; }
- (NSUInteger)revenant_mps_filterWidth { return RevenantMPSPyramidFilterOf(self).width; }
- (NSUInteger)revenant_mps_filterHeight { return RevenantMPSPyramidFilterOf(self).height; }

@end
