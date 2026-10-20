#import "RevenantMetal.h"

@implementation RevenantMetalBuffer (Address16)

- (uint64_t)gpuAddress
{
    return (uint64_t)(uintptr_t)[self contents];
}

@end
