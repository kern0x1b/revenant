#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

@implementation VTFrameProcessorOpticalFlow{ CVPixelBufferRef _forwardFlow; CVPixelBufferRef _backwardFlow;}

- (CVPixelBufferRef)forwardFlow
{
    if (self->_forwardFlow)
        CFRetain(self->_forwardFlow);
    return self->_forwardFlow;
}

- (CVPixelBufferRef)backwardFlow
{
    if (self->_backwardFlow)
        CFRetain(self->_backwardFlow);
    return self->_backwardFlow;
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithForwardFlow:(CVPixelBufferRef)forwardFlow
                        backwardFlow:(CVPixelBufferRef)backwardFlow
{
    self = [super init];
    self->_forwardFlow = (CVPixelBufferRef)forwardFlow;
    if (self->_forwardFlow)
        CFRetain(self->_forwardFlow);
    self->_backwardFlow = (CVPixelBufferRef)backwardFlow;
    if (self->_backwardFlow)
        CFRetain(self->_backwardFlow);
    return self;
}

@end
