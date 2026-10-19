#import "RevenantMetal.h"

id<MTLDevice> MTLCreateSystemDefaultDevice(void)
{
    return [RevenantMetalDevice shared];
}
