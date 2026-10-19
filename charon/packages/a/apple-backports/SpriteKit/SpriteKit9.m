// SpriteKit9.m - SKNode's member of iOS 9, carried for the releases that have no SpriteKit at all.
//
// moveToParent: is the one member of the tree that arrived in iOS 9. It is defined by the two calls every node already
// has, so it is the port's own with no behaviour of its own to measure beyond the tree's (facts/SpriteKit/SKNode.md).
#import "CharonSpriteKit.h"

@implementation SKNode (CharonSpriteKit9)

- (void)moveToParent:(SKNode *)parent
{
    [self removeFromParent];
    [parent addChild:self];
}

@end
