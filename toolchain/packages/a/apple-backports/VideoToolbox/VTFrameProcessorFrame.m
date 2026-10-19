#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

@implementation VTFrameProcessorFrame{ CVPixelBufferRef _buffer;}

- (CVPixelBufferRef)buffer
{
    if (self->_buffer)
        CFRetain(self->_buffer);
    return self->_buffer;
}

- (CMTime)presentationTimeStamp
{
    CMTime value = {0};
    NSValue *boxed = CharonValueStore(self)[@"presentationTimeStamp"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}


#pragma mark - The SDK's designated initialisers

- (instancetype)initWithBuffer:(CVPixelBufferRef)buffer
                        presentationTimeStamp:(CMTime)presentationTimeStamp
{
    self = [super init];
    self->_buffer = (CVPixelBufferRef)buffer;
    if (self->_buffer)
        CFRetain(self->_buffer);
    { CMTime boxed = presentationTimeStamp;
      CharonValueSet(self, [NSValue valueWithBytes:&boxed objCType:@encode(CMTime)], @"presentationTimeStamp"); }
    return self;
}

@end
