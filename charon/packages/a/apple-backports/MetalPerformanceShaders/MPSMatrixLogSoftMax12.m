#import "CharonMPS.h"


@implementation MPSMatrixLogSoftMax

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device]))
        [self charon_mps_setLogarithmic:YES];
    return self;
}

@end
