#include "../revenant_impl.h"
#import "RevenantMetal.h"

id<MTLDevice> BACKPORT_IMPL(MTLCreateSystemDefaultDevice)(void)
{
    return [RevenantMetalDevice shared];
}
