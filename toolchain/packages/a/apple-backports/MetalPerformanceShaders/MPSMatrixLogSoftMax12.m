#import "RevenantMPS.h"


@implementation MPSMatrixLogSoftMax

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device]))
        [self revenant_mps_setLogarithmic:YES];
    return self;
}

@end
