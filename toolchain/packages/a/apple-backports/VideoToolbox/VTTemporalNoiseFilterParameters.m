#import "RevenantVideoToolbox.h"
#import "VideoToolboxValueStore.h"

REVENANT_VIDEO_TOOLBOX_VALUE_STORE(VTTemporalNoiseFilterParameters)

@implementation VTTemporalNoiseFilterParameters

#pragma mark - The protocol's own properties, implemented for this class

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, sourceFrame)

REVENANT_VALUE_PROPERTY(VTFrameProcessorFrame *, destinationFrame)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, destinationFrames)


#pragma mark - This class's own properties

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, nextFrames)

REVENANT_VALUE_PROPERTY(NSArray<VTFrameProcessorFrame *> *, previousFrames)

REVENANT_DOUBLE_PROPERTY(float, filterStrength)

REVENANT_SCALAR_PROPERTY(BOOL, hasDiscontinuity)


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrames:(NSArray<VTFrameProcessorFrame *> *)nextFrames
                        previousFrames:(NSArray<VTFrameProcessorFrame *> *)previousFrames
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
                        filterStrength:(float)filterStrength
                        hasDiscontinuity:(Boolean)hasDiscontinuity
{
    self = [super init];
    RevenantValueSet(self, sourceFrame, @"sourceFrame");
    RevenantValueSet(self, nextFrames, @"nextFrames");
    RevenantValueSet(self, previousFrames, @"previousFrames");
    RevenantValueSet(self, destinationFrame, @"destinationFrame");
    RevenantValueSet(self, @(filterStrength), @"filterStrength");
    RevenantValueSet(self, @(hasDiscontinuity), @"hasDiscontinuity");
    return self;
}

@end
