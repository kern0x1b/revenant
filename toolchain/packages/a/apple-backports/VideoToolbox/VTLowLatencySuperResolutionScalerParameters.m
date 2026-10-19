#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTLowLatencySuperResolutionScalerParameters)

@implementation VTLowLatencySuperResolutionScalerParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, destinationFrame, @"destinationFrame");
    return self;
}

@end
