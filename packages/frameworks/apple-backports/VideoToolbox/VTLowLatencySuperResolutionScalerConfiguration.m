#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"


typedef NSDictionary<NSString *, id> RevenantVTFrameAttributes;

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTLowLatencySuperResolutionScalerConfiguration)

@implementation VTLowLatencySuperResolutionScalerConfiguration

#pragma mark - The protocol's own properties, implemented for this class

+ (BOOL)isSupported
{
    return NO;
}

REVENANT_VALUE_PROPERTY(NSArray<NSNumber *> *, frameSupportedPixelFormats)

REVENANT_VALUE_PROPERTY(RevenantVTFrameAttributes *, sourcePixelBufferAttributes)

REVENANT_VALUE_PROPERTY(RevenantVTFrameAttributes *, destinationPixelBufferAttributes)

REVENANT_SCALAR_PROPERTY(NSInteger, nextFrameCount)

REVENANT_SCALAR_PROPERTY(NSInteger, previousFrameCount)

+ (CMVideoDimensions)maximumDimensions
{
    CMVideoDimensions value = {0};
    NSValue *boxed = RevenantValueStoreOfClass([self class])[@"maximumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

+ (CMVideoDimensions)minimumDimensions
{
    CMVideoDimensions value = {0};
    NSValue *boxed = RevenantValueStoreOfClass([self class])[@"minimumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}


#pragma mark - This class's own properties

REVENANT_SCALAR_PROPERTY(NSInteger, frameWidth)

REVENANT_SCALAR_PROPERTY(NSInteger, frameHeight)

REVENANT_DOUBLE_PROPERTY(float, scaleFactor)

+ (NSArray<NSNumber *> *)supportedScaleFactorsForFrameWidth:(NSInteger)frameWidth
                                                 frameHeight:(NSInteger)frameHeight
{
    return @[];
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        scaleFactor:(float)scaleFactor
{
    self = [super init];
    RevenantValueSet(self, @(frameWidth), @"frameWidth");
    RevenantValueSet(self, @(frameHeight), @"frameHeight");
    RevenantValueSet(self, @(scaleFactor), @"scaleFactor");
    return self;
}

@end
