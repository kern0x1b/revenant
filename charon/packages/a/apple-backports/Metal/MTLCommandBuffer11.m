#import "CharonMetal.h"

// The 11.0 debug groups of a command buffer: a group names a span of commands for a capture, and a
// buffer's groups are kept in the order they were pushed, exactly as the encoders keep theirs.
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
