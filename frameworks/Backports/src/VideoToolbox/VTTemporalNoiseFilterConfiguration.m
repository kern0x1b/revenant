#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"


typedef NSDictionary<NSString *, id> RevenantVTFrameAttributes;

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTTemporalNoiseFilterConfiguration)

@implementation VTTemporalNoiseFilterConfiguration{ OSType _sourcePixelFormat;}

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

+ (NSArray<NSNumber *> *)supportedSourcePixelFormats
{
    return (NSArray<NSNumber *> *)RevenantValueStoreOfClass([self class])[@"supportedSourcePixelFormats"];
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        sourcePixelFormat:(OSType)sourcePixelFormat
{
    self = [super init];
    RevenantValueSet(self, @(frameWidth), @"frameWidth");
    RevenantValueSet(self, @(frameHeight), @"frameHeight");
    self->_sourcePixelFormat = (OSType)sourcePixelFormat;
    return self;
}

@end
