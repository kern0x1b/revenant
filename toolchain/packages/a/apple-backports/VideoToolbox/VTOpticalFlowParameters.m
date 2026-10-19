#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTOpticalFlowParameters)

@implementation VTOpticalFlowParameters

#pragma mark - The protocol's own properties, implemented for this class

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, nextFrame)

CHARON_SCALAR_PROPERTY(VTOpticalFlowParametersSubmissionMode, submissionMode)

CHARON_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, destinationOpticalFlow)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame *)nextFrame
                        submissionMode:(VTOpticalFlowParametersSubmissionMode)submissionMode
                        destinationOpticalFlow:(VTFrameProcessorOpticalFlow *)destinationOpticalFlow
{
    self = [super init];
    CharonValueSet(self, sourceFrame, @"sourceFrame");
    CharonValueSet(self, nextFrame, @"nextFrame");
    CharonValueSet(self, @(submissionMode), @"submissionMode");
    CharonValueSet(self, destinationOpticalFlow, @"destinationOpticalFlow");
    return self;
}

@end
