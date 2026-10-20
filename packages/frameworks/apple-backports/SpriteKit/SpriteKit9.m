#import "RevenantSpriteKit.h"

@implementation SKNode (RevenantSpriteKit9)

- (void)moveToParent:(SKNode *)parent
{
    [self removeFromParent];
    [parent addChild:self];
}

@end
