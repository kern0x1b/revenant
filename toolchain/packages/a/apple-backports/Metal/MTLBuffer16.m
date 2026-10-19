#import "CharonMetal.h"

@implementation CharonMetalBuffer (Address16)

- (uint64_t)gpuAddress
{
    return (uint64_t)(uintptr_t)[self contents];
}

@end
