#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTOpticalFlowParameters)

@implementation VTOpticalFlowParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, nextFrame)

REVENANT_SCALAR_PROPERTY(VTOpticalFlowParametersSubmissionMode, submissionMode)

REVENANT_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, destinationOpticalFlow)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame *)nextFrame
                        submissionMode:(VTOpticalFlowParametersSubmissionMode)submissionMode
                        destinationOpticalFlow:(VTFrameProcessorOpticalFlow *)destinationOpticalFlow
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, nextFrame, @"nextFrame");
    RevenantValueSet(self, @(submissionMode), @"submissionMode");
    RevenantValueSet(self, destinationOpticalFlow, @"destinationOpticalFlow");
    return self;
}

@end
