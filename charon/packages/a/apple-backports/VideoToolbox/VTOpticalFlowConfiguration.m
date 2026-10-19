#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"


// A file-local spelling for the types the property macros cannot take. Each of these carries a
// comma, and the preprocessor counts arguments rather than template parameters, so the macro
// would be handed three arguments for one type. The declaration in CharonVideoToolbox.h keeps
// the SDK's own spelling: this is the same type, named once so the macro has one argument.
typedef NSDictionary<NSString *, id> CharonVTFrameAttributes;

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTOpticalFlowConfiguration)

@implementation VTOpticalFlowConfiguration

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

CHARON_SCALAR_PROPERTY(VTOpticalFlowConfigurationQualityPrioritization, qualityPrioritization)

CHARON_SCALAR_PROPERTY(VTOpticalFlowConfigurationRevision, revision)

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)CharonValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTOpticalFlowConfigurationRevision)defaultRevision
{
    return (VTOpticalFlowConfigurationRevision)[CharonValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        qualityPrioritization:(VTOpticalFlowConfigurationQualityPrioritization)qualityPrioritization
                        revision:(VTOpticalFlowConfigurationRevision)revision
{
    self = [super init];
    CharonValueSet(self, @(frameWidth), @"frameWidth");
    CharonValueSet(self, @(frameHeight), @"frameHeight");
    CharonValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    CharonValueSet(self, @(revision), @"revision");
    return self;
}

@end
