#import "CharonSpriteKit.h"

@implementation SKNode (CharonSpriteKit9)

- (void)moveToParent:(SKNode *)parent
{
    [self removeFromParent];
    [parent addChild:self];
}

@end
