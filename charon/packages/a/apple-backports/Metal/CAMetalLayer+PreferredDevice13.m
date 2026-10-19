#import <QuartzCore/CAMetalLayer.h>

@implementation CAMetalLayer (CharonPreferredDevice)

- (id<MTLDevice>)preferredDevice
{
    return nil;
}

@end
