#import "CharonMetal.h"

id<MTLDevice> MTLCreateSystemDefaultDevice(void)
{
    return [CharonMetalDevice shared];
}
