#import "RevenantMetal.h"

@implementation RevenantMetalCommandBuffer (DebugGroups11)

- (void)pushDebugGroup:(NSString *)string
{
    [self revenantPushDebugGroup:string];
}

- (void)popDebugGroup
{
    [self revenantPopDebugGroup];
}

@end
