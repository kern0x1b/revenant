#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

@implementation VTMotionBlurConfiguration

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                       frameHeight:(NSInteger)frameHeight
                 usePrecomputedFlow:(BOOL)usePrecomputedFlow
             qualityPrioritization:(VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
                           revision:(VTMotionBlurConfigurationRevision)revision
{
    self = [super init];
    if (!self)
        return nil;
    CharonValueSet(self, @(frameWidth), @"frameWidth");
    CharonValueSet(self, @(frameHeight), @"frameHeight");
    CharonValueSet(self, @(usePrecomputedFlow), @"usePrecomputedFlow");
    CharonValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    CharonValueSet(self, @(revision), @"revision");
    return self;
}


#pragma mark - The protocol's own properties

+ (BOOL)isSupported
{
    return NO;
}

- (NSArray<NSNumber *> *)frameSupportedPixelFormats
{
    return (NSArray<NSNumber *> *)CharonValueStore(self)[@"frameSupportedPixelFormats"];
}

- (NSDictionary<NSString *, id> *)sourcePixelBufferAttributes
{
    return (NSDictionary<NSString *, id> *)CharonValueStore(self)[@"sourcePixelBufferAttributes"];
}

- (NSDictionary<NSString *, id> *)destinationPixelBufferAttributes
{
    return (NSDictionary<NSString *, id> *)CharonValueStore(self)[@"destinationPixelBufferAttributes"];
}

- (NSInteger)nextFrameCount
{
    return (NSInteger)[CharonValueStore(self)[@"nextFrameCount"] longLongValue];
}

- (NSInteger)previousFrameCount
{
    return (NSInteger)[CharonValueStore(self)[@"previousFrameCount"] longLongValue];
}

+ (CMVideoDimensions)maximumDimensions
{
    CMVideoDimensions value = {0, 0};
    NSValue *boxed = CharonValueStoreOfClass([self class])[@"maximumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

+ (CMVideoDimensions)minimumDimensions
{
    CMVideoDimensions value = {0, 0};
    NSValue *boxed = CharonValueStoreOfClass([self class])[@"minimumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

#pragma mark - This class's own properties

- (NSInteger)frameWidth
{
    return (NSInteger)[CharonValueStore(self)[@"frameWidth"] longLongValue];
}

- (NSInteger)frameHeight
{
    return (NSInteger)[CharonValueStore(self)[@"frameHeight"] longLongValue];
}

- (BOOL)usePrecomputedFlow
{
    return (BOOL)[CharonValueStore(self)[@"usePrecomputedFlow"] longLongValue];
}

- (VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
{
    return (VTMotionBlurConfigurationQualityPrioritization)[CharonValueStore(self)[@"qualityPrioritization"] longLongValue];
}

- (VTMotionBlurConfigurationRevision)revision
{
    return (VTMotionBlurConfigurationRevision)[CharonValueStore(self)[@"revision"] longLongValue];
}

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)CharonValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTMotionBlurConfigurationRevision)defaultRevision
{
    return (VTMotionBlurConfigurationRevision)[CharonValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}

#pragma mark - Initialisation, the one the header leaves open

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                          frameHeight:(NSInteger)frameHeight
                 usePrecomputedFlow:(BOOL)usePrecomputedFlow
              qualityPrioritization:(VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
{
    if ((self = [super init])) {
        CharonValueStore(self)[@"frameWidth"] = @(frameWidth);
        CharonValueStore(self)[@"frameHeight"] = @(frameHeight);
        CharonValueStore(self)[@"usePrecomputedFlow"] = @(usePrecomputedFlow);
        CharonValueStore(self)[@"qualityPrioritization"] = @(qualityPrioritization);
    }
    return self;
}

@end
