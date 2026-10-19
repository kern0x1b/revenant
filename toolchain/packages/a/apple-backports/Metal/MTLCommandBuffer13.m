#import "RevenantMetal.h"

@implementation RevenantMetalCommandBuffer (ResourceState13)

- (id<MTLResourceStateCommandEncoder>)resourceStateCommandEncoder
{
    NSLog(@"Metal: the resource-state encoder needs sparse texture mapping, which this device does not have: none is made");
    return nil;
}

@end
