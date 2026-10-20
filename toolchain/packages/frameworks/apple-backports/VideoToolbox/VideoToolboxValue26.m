#import "RevenantVideoToolbox.h"
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
    RevenantValueSet(self, @(frameWidth), @"frameWidth");
    RevenantValueSet(self, @(frameHeight), @"frameHeight");
    RevenantValueSet(self, @(usePrecomputedFlow), @"usePrecomputedFlow");
    RevenantValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    RevenantValueSet(self, @(revision), @"revision");
    return self;
}


#pragma mark - The protocol's own properties

+ (BOOL)isSupported
{
    return NO;
}

- (NSArray<NSNumber *> *)frameSupportedPixelFormats
{
    return (NSArray<NSNumber *> *)RevenantValueStore(self)[@"frameSupportedPixelFormats"];
}

- (NSDictionary<NSString *, id> *)sourcePixelBufferAttributes
{
    return (NSDictionary<NSString *, id> *)RevenantValueStore(self)[@"sourcePixelBufferAttributes"];
}

- (NSDictionary<NSString *, id> *)destinationPixelBufferAttributes
{
    return (NSDictionary<NSString *, id> *)RevenantValueStore(self)[@"destinationPixelBufferAttributes"];
}

- (NSInteger)nextFrameCount
{
    return (NSInteger)[RevenantValueStore(self)[@"nextFrameCount"] longLongValue];
}

- (NSInteger)previousFrameCount
{
    return (NSInteger)[RevenantValueStore(self)[@"previousFrameCount"] longLongValue];
}

+ (CMVideoDimensions)maximumDimensions
{
    CMVideoDimensions value = {0, 0};
    NSValue *boxed = RevenantValueStoreOfClass([self class])[@"maximumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

+ (CMVideoDimensions)minimumDimensions
{
    CMVideoDimensions value = {0, 0};
    NSValue *boxed = RevenantValueStoreOfClass([self class])[@"minimumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

#pragma mark - This class's own properties

- (NSInteger)frameWidth
{
    return (NSInteger)[RevenantValueStore(self)[@"frameWidth"] longLongValue];
}

- (NSInteger)frameHeight
{
    return (NSInteger)[RevenantValueStore(self)[@"frameHeight"] longLongValue];
}

- (BOOL)usePrecomputedFlow
{
    return (BOOL)[RevenantValueStore(self)[@"usePrecomputedFlow"] longLongValue];
}

- (VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
{
    return (VTMotionBlurConfigurationQualityPrioritization)[RevenantValueStore(self)[@"qualityPrioritization"] longLongValue];
}

- (VTMotionBlurConfigurationRevision)revision
{
    return (VTMotionBlurConfigurationRevision)[RevenantValueStore(self)[@"revision"] longLongValue];
}

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)RevenantValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTMotionBlurConfigurationRevision)defaultRevision
{
    return (VTMotionBlurConfigurationRevision)[RevenantValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}

#pragma mark - Initialisation, the one the header leaves open

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                          frameHeight:(NSInteger)frameHeight
                 usePrecomputedFlow:(BOOL)usePrecomputedFlow
              qualityPrioritization:(VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
{
    if ((self = [super init])) {
        RevenantValueStore(self)[@"frameWidth"] = @(frameWidth);
        RevenantValueStore(self)[@"frameHeight"] = @(frameHeight);
        RevenantValueStore(self)[@"usePrecomputedFlow"] = @(usePrecomputedFlow);
        RevenantValueStore(self)[@"qualityPrioritization"] = @(qualityPrioritization);
    }
    return self;
}

@end
