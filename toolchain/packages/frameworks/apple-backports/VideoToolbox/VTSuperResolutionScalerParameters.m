#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTSuperResolutionScalerParameters)

@implementation VTSuperResolutionScalerParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, previousFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, previousOutputFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, opticalFlow)

REVENANT_SCALAR_PROPERTY(VTSuperResolutionScalerParametersSubmissionMode, submissionMode)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        previousFrame:(VTFrameProcessorFrame * _Nullable)previousFrame
                        previousOutputFrame:(VTFrameProcessorFrame * _Nullable)previousOutputFrame
                        opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow
                        submissionMode:(VTSuperResolutionScalerParametersSubmissionMode)submissionMode
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, previousFrame, @"previousFrame");
    RevenantValueSet(self, previousOutputFrame, @"previousOutputFrame");
    RevenantValueSet(self, opticalFlow, @"opticalFlow");
    RevenantValueSet(self, @(submissionMode), @"submissionMode");
    RevenantValueSet(self, destinationFrame, @"destinationFrame");
    return self;
}

@end
