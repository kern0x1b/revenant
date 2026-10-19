#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"


typedef NSDictionary<NSString *, id> CharonVTFrameAttributes;

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTSuperResolutionScalerConfiguration)

@implementation VTSuperResolutionScalerConfiguration

#pragma mark - The protocol's own properties, implemented for this class

+ (BOOL)isSupported
{
    return NO;
}

CHARON_VALUE_PROPERTY(NSArray<NSNumber *> *, frameSupportedPixelFormats)

CHARON_VALUE_PROPERTY(CharonVTFrameAttributes *, sourcePixelBufferAttributes)

CHARON_VALUE_PROPERTY(CharonVTFrameAttributes *, destinationPixelBufferAttributes)

CHARON_SCALAR_PROPERTY(NSInteger, nextFrameCount)

CHARON_SCALAR_PROPERTY(NSInteger, previousFrameCount)

+ (CMVideoDimensions)maximumDimensions
{
    CMVideoDimensions value = {0};
    NSValue *boxed = CharonValueStoreOfClass([self class])[@"maximumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

+ (CMVideoDimensions)minimumDimensions
{
    CMVideoDimensions value = {0};
    NSValue *boxed = CharonValueStoreOfClass([self class])[@"minimumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}


#pragma mark - This class's own properties

CHARON_SCALAR_PROPERTY(NSInteger, frameWidth)

CHARON_SCALAR_PROPERTY(NSInteger, frameHeight)

CHARON_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationInputType, inputType)

- (BOOL)usesPrecomputedFlow
{
    return (BOOL)[CharonValueStore(self)[@"precomputedFlow"] longLongValue];
}

CHARON_SCALAR_PROPERTY(NSInteger, scaleFactor)

CHARON_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationQualityPrioritization, qualityPrioritization)

CHARON_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationRevision, revision)

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)CharonValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTSuperResolutionScalerConfigurationRevision)defaultRevision
{
    return (VTSuperResolutionScalerConfigurationRevision)[CharonValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}

CHARON_SCALAR_PROPERTY(VTSuperResolutionScalerConfigurationModelStatus, configurationModelStatus)

CHARON_DOUBLE_PROPERTY(float, configurationModelPercentageAvailable)

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
    CharonValueSet(self, @(frameWidth), @"frameWidth");
    CharonValueSet(self, @(frameHeight), @"frameHeight");
    CharonValueSet(self, @(scaleFactor), @"scaleFactor");
    CharonValueSet(self, @(inputType), @"inputType");
    CharonValueSet(self, @(usePrecomputedFlow), @"precomputedFlow");
    CharonValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    CharonValueSet(self, @(revision), @"revision");
    return self;
}

@end
