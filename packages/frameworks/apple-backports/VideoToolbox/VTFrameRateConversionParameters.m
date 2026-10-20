#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTFrameRateConversionParameters)

@implementation VTFrameRateConversionParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, nextFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, opticalFlow)

REVENANT_VALUE_PROPERTY(NSArray<NSNumber *> *, interpolationPhase)

REVENANT_SCALAR_PROPERTY(VTFrameRateConversionParametersSubmissionMode, submissionMode)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame *)nextFrame
                        opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow
                        interpolationPhase:(NSArray<NSNumber *> *)interpolationPhase
                        submissionMode:(VTFrameRateConversionParametersSubmissionMode)submissionMode
                        destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrame
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, nextFrame, @"nextFrame");
    RevenantValueSet(self, opticalFlow, @"opticalFlow");
    RevenantValueSet(self, interpolationPhase, @"interpolationPhase");
    RevenantValueSet(self, @(submissionMode), @"submissionMode");
    RevenantValueSet(self, destinationFrame, @"destinationFrames");
    return self;
}

@end
