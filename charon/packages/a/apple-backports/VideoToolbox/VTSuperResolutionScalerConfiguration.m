#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"


// A file-local spelling for the types the property macros cannot take. Each of these carries a
// comma, and the preprocessor counts arguments rather than template parameters, so the macro
// would be handed three arguments for one type. The declaration in CharonVideoToolbox.h keeps
// the SDK's own spelling: this is the same type, named once so the macro has one argument.
typedef NSDictionary<NSString *, id> CharonVTFrameAttributes;

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTSuperResolutionScalerConfiguration)

@implementation VTSuperResolutionScalerConfiguration

#pragma mark - The protocol's own properties, implemented for this class

+ (BOOL)isSupported
{
    // `supported` is a CLASS property in the protocol (class, nonatomic, readonly, getter=isSupported),
    // so the accessor belongs to the class and this is a class method rather than an instance one.
    //
    // The answer is NO, and it is the answer rather than a default: SDK 26.2 documents this property as
    // "whether the SYSTEM SUPPORTS this processor", and objc-inventory.lua over the armv7 6.1.3 dyld
    // cache finds no VTFrameProcessor class and no VTFrameProcessor* symbol there - the seventeen
    // configuration and parameter classes arrived with iOS 26.0 and the ladder this package builds for
    // ends at 10.3.4. The effects are motion estimation, interpolation, super resolution and temporal
    // noise filtering, which need the Neural Engine no armv7 device has. So this is a hardware answer,
    // and a store nothing writes would be NO by accident rather than by measurement.
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
    // SDK 26.2 gives the scale factors a super-resolution scaler may be initialized with, as a set
    // for its configuration. There is no scaler to initialize on this release, so the set is empty - which is
    // an answer and not a default: -initWithFrameWidth:frameHeight:scaleFactor:inputType:... above takes
    // the scale factor the caller wants and the same empty set is what says which values are allowed.
    return @[];
}

- (void)downloadConfigurationModelWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    // SDK 26.2 on this method says it downloads the model assets the current configuration needs, in the background.
    // A failed download invokes the completion handler with an NSError, and the
    // configurationModelStatus goes back to DownloadRequired.
    //
    // No request is made, and that is the whole of the behaviour rather than half of it: the port has
    // no VideoToolbox to download from (objc-inventory.lua over the armv7 6.1.3 cache finds no
    // VTFrameProcessor class and no VTFrameProcessor* symbol) and no processor whose model would be
    // needed. The completion RUNS, once, with VTFrameProcessorAssetDownloadFailed - the code SDK 26.2
    // defines for the case where a required model asset cannot be fetched, which
    // leaves -configurationModelStatus at the DownloadRequired the header's own enumeration starts at,
    // so the two agree, and a caller that waits on the completion is never left waiting.
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
