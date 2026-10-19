#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTFrameRateConversionParameters)

@implementation VTFrameRateConversionParameters

#pragma mark - The protocol's own properties, implemented for this class

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, nextFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, opticalFlow)

CHARON_VALUE_PROPERTY(NSArray<NSNumber *> *, interpolationPhase)

CHARON_SCALAR_PROPERTY(VTFrameRateConversionParametersSubmissionMode, submissionMode)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame *)nextFrame
                        opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow
                        interpolationPhase:(NSArray<NSNumber *> *)interpolationPhase
                        submissionMode:(VTFrameRateConversionParametersSubmissionMode)submissionMode
                        destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrame
{
    self = [super init];
    CharonValueSet(self, sourceFrame, @"sourceFrame");
    CharonValueSet(self, nextFrame, @"nextFrame");
    CharonValueSet(self, opticalFlow, @"opticalFlow");
    CharonValueSet(self, interpolationPhase, @"interpolationPhase");
    CharonValueSet(self, @(submissionMode), @"submissionMode");
    CharonValueSet(self, destinationFrame, @"destinationFrames");
    return self;
}

@end
