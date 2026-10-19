#import "CharonMetal.h"

@implementation CharonMetalCommandBuffer (DebugGroups11)

- (void)pushDebugGroup:(NSString *)string
{
    [self charonPushDebugGroup:string];
}

- (void)popDebugGroup
{
    [self charonPopDebugGroup];
}

@end
