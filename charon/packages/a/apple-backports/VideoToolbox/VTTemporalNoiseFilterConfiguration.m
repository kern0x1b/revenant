#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"


typedef NSDictionary<NSString *, id> CharonVTFrameAttributes;

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTTemporalNoiseFilterConfiguration)

@implementation VTTemporalNoiseFilterConfiguration{ OSType _sourcePixelFormat;}

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

+ (NSArray<NSNumber *> *)supportedSourcePixelFormats
{
    return (NSArray<NSNumber *> *)CharonValueStoreOfClass([self class])[@"supportedSourcePixelFormats"];
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        sourcePixelFormat:(OSType)sourcePixelFormat
{
    self = [super init];
    CharonValueSet(self, @(frameWidth), @"frameWidth");
    CharonValueSet(self, @(frameHeight), @"frameHeight");
    self->_sourcePixelFormat = (OSType)sourcePixelFormat;
    return self;
}

@end
