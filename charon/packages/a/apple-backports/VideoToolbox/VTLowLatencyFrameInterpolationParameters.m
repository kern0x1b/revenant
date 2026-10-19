#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTLowLatencyFrameInterpolationParameters)

@implementation VTLowLatencyFrameInterpolationParameters

#pragma mark - The protocol's own properties, implemented for this class

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, previousFrame)

CHARON_VALUE_PROPERTY(NSArray<NSNumber *> *, interpolationPhase)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        previousFrame:(VTFrameProcessorFrame *)previousFrame
                        interpolationPhase:(NSArray<NSNumber *> *)interpolationPhase
                        destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrames
{
    self = [super init];
    CharonValueSet(self, sourceFrame, @"sourceFrame");
    CharonValueSet(self, previousFrame, @"previousFrame");
    CharonValueSet(self, interpolationPhase, @"interpolationPhase");
    CharonValueSet(self, destinationFrames, @"destinationFrames");
    return self;
}

@end
