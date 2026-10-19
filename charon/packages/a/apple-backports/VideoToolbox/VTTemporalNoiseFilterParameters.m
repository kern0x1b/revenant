#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

CHARON_VIDEO_TOOLBOX_VALUE_STORE(VTTemporalNoiseFilterParameters)

@implementation VTTemporalNoiseFilterParameters

#pragma mark - The protocol's own properties, implemented for this class

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

CHARON_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, nextFrames)

CHARON_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, previousFrames)

CHARON_DOUBLE_PROPERTY(float, filterStrength)

CHARON_SCALAR_PROPERTY(BOOL, hasDiscontinuity)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrames:(NSArray<VTFrameProcessorFrame *> *)nextFrames
                        previousFrames:(NSArray<VTFrameProcessorFrame *> *)previousFrames
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
                        filterStrength:(float)filterStrength
                        hasDiscontinuity:(Boolean)hasDiscontinuity
{
    self = [super init];
    CharonValueSet(self, sourceFrame, @"sourceFrame");
    CharonValueSet(self, nextFrames, @"nextFrames");
    CharonValueSet(self, previousFrames, @"previousFrames");
    CharonValueSet(self, destinationFrame, @"destinationFrame");
    CharonValueSet(self, @(filterStrength), @"filterStrength");
    CharonValueSet(self, @(hasDiscontinuity), @"hasDiscontinuity");
    return self;
}

@end
