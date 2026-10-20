#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"


typedef NSDictionary<NSString *, id> RevenantVTFrameAttributes;

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTSuperResolutionScalerConfiguration)

@implementation VTSuperResolutionScalerConfiguration

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

REVENANT_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationInputType, inputType)

- (BOOL)usesPrecomputedFlow
{
    return (BOOL)[RevenantValueStore(self)[@"precomputedFlow"] longLongValue];
}

REVENANT_SCALAR_PROPERTY(NSInteger, scaleFactor)

REVENANT_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationQualityPrioritization, qualityPrioritization)

REVENANT_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationRevision, revision)

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)RevenantValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTSuperResolutionScalerConfigurationRevision)defaultRevision
{
    return (VTSuperResolutionScalerConfigurationRevision)[RevenantValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}

REVENANT_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationModelStatus, configurationModelStatus)

REVENANT_DOUBLE_PROPERTY(float, configurationModelPercentageAvailable)

+ (NSArray<NSNumber*> *)supportedScaleFactors
{
    return @[];
}

- (void)downloadConfigurationModelWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler([NSError errorWithDomain:VTFrameProcessorErrorDomain
                                             code:VTFrameProcessorAssetDownloadFailed
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        @"This device has no VideoToolbox frame processor, "
                                                        @"so there are no model assets to download."}]);
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        scaleFactor:(NSInteger)scaleFactor
                        inputType:(VTSuperResolutionScalerConfigurationInputType)inputType
                        usePrecomputedFlow:(BOOL)usePrecomputedFlow
                        qualityPrioritization:(VTSuperResolutionScalerConfigurationQualityPrioritization)qualityPrioritization
                        revision:(VTSuperResolutionScalerConfigurationRevision)revision
{
    self = [super init];
    RevenantValueSet(self, @(frameWidth), @"frameWidth");
    RevenantValueSet(self, @(frameHeight), @"frameHeight");
    RevenantValueSet(self, @(scaleFactor), @"scaleFactor");
    RevenantValueSet(self, @(inputType), @"inputType");
    RevenantValueSet(self, @(usePrecomputedFlow), @"precomputedFlow");
    RevenantValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    RevenantValueSet(self, @(revision), @"revision");
    return self;
}

@end
