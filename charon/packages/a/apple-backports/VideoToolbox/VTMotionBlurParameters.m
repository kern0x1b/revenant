#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTMotionBlurParameters)

@implementation VTMotionBlurParameters

#pragma mark - The protocol's own properties, implemented for this class

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, nextFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, previousFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, nextOpticalFlow)

CHARON_VALUE_PROPERTY(VTFrameProcessorOpticalFlow *, previousOpticalFlow)

CHARON_SCALAR_PROPERTY(NSInteger, motionBlurStrength)

CHARON_SCALAR_PROPERTY(VTMotionBlurParametersSubmissionMode, submissionMode)


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
    CharonValueSet(self, sourceFrame, @"sourceFrame");
    CharonValueSet(self, nextFrame, @"nextFrame");
    CharonValueSet(self, previousFrame, @"previousFrame");
    CharonValueSet(self, nextOpticalFlow, @"nextOpticalFlow");
    CharonValueSet(self, previousOpticalFlow, @"previousOpticalFlow");
    CharonValueSet(self, @(motionBlurStrength), @"motionBlurStrength");
    CharonValueSet(self, @(submissionMode), @"submissionMode");
    CharonValueSet(self, destinationFrame, @"destinationFrame");
    return self;
}

@end
