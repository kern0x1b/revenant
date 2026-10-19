#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"


typedef NSDictionary<NSString *, id> RevenantVTFrameAttributes;

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTFrameRateConversionConfiguration)

@implementation VTFrameRateConversionConfiguration

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

REVENANT_SCALAR_PROPERTY(BOOL, usePrecomputedFlow)

REVENANT_SCALAR_PROPERTY(VTFrameRateConversionConfigurationQualityPrioritization, qualityPrioritization)

REVENANT_SCALAR_PROPERTY(VTFrameRateConversionConfigurationRevision, revision)

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)RevenantValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTFrameRateConversionConfigurationRevision)defaultRevision
{
    return (VTFrameRateConversionConfigurationRevision)[RevenantValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        usePrecomputedFlow:(BOOL)usePrecomputedFlow
                        qualityPrioritization:(VTFrameRateConversionConfigurationQualityPrioritization)qualityPrioritization
                        revision:(VTFrameRateConversionConfigurationRevision)revision
{
    self = [super init];
    RevenantValueSet(self, @(frameWidth), @"frameWidth");
    RevenantValueSet(self, @(frameHeight), @"frameHeight");
    RevenantValueSet(self, @(usePrecomputedFlow), @"usePrecomputedFlow");
    RevenantValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    RevenantValueSet(self, @(revision), @"revision");
    return self;
}

@end
