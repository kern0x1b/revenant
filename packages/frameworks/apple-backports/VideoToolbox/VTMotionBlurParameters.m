#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTMotionBlurParameters)

@implementation VTMotionBlurParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, nextFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, previousFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, nextOpticalFlow)

REVENANT_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, previousOpticalFlow)

REVENANT_SCALAR_PROPERTY(NSInteger, motionBlurStrength)

REVENANT_SCALAR_PROPERTY(VTMotionBlurParametersSubmissionMode, submissionMode)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame * _Nullable)nextFrame
                        previousFrame:(VTFrameProcessorFrame * _Nullable)previousFrame
                        nextOpticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)nextOpticalFlow
                        previousOpticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)previousOpticalFlow
                        motionBlurStrength:(NSInteger)motionBlurStrength
                        submissionMode:(VTMotionBlurParametersSubmissionMode)submissionMode
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, nextFrame, @"nextFrame");
    RevenantValueSet(self, previousFrame, @"previousFrame");
    RevenantValueSet(self, nextOpticalFlow, @"nextOpticalFlow");
    RevenantValueSet(self, previousOpticalFlow, @"previousOpticalFlow");
    RevenantValueSet(self, @(motionBlurStrength), @"motionBlurStrength");
    RevenantValueSet(self, @(submissionMode), @"submissionMode");
    RevenantValueSet(self, destinationFrame, @"destinationFrame");
    return self;
}

@end
