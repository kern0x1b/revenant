#import <QuartzCore/CAMetalLayer.h>

@implementation CAMetalLayer (RevenantPreferredDevice)

- (id<MTLDevice>)preferredDevice
{
    return nil;
}

@end
