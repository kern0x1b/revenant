#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTLowLatencyFrameInterpolationParameters)

@implementation VTLowLatencyFrameInterpolationParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, previousFrame)

REVENANT_VALUE_PROPERTY(NSArray<NSNumber *> *, interpolationPhase)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        previousFrame:(VTFrameProcessorFrame *)previousFrame
                        interpolationPhase:(NSArray<NSNumber *> *)interpolationPhase
                        destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrames
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, previousFrame, @"previousFrame");
    RevenantValueSet(self, interpolationPhase, @"interpolationPhase");
    RevenantValueSet(self, destinationFrames, @"destinationFrames");
    return self;
}

@end
