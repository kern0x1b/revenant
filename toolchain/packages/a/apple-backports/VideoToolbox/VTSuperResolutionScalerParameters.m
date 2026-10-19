#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTSuperResolutionScalerParameters)

@implementation VTSuperResolutionScalerParameters

#pragma mark - The protocol's own properties, implemented for this class

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, previousFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, previousOutputFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, opticalFlow)

CHARON_SCALAR_PROPERTY(VTSuperResolutionScalerParametersSubmissionMode, submissionMode)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        previousFrame:(VTFrameProcessorFrame * _Nullable)previousFrame
                        previousOutputFrame:(VTFrameProcessorFrame * _Nullable)previousOutputFrame
                        opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow
                        submissionMode:(VTSuperResolutionScalerParametersSubmissionMode)submissionMode
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
{
    self = [super init];
    CharonValueSet(self, sourceFrame, @"sourceFrame");
    CharonValueSet(self, previousFrame, @"previousFrame");
    CharonValueSet(self, previousOutputFrame, @"previousOutputFrame");
    CharonValueSet(self, opticalFlow, @"opticalFlow");
    CharonValueSet(self, @(submissionMode), @"submissionMode");
    CharonValueSet(self, destinationFrame, @"destinationFrame");
    return self;
}

@end
