// SpriteKitCrop7.m - SKCropNode of iOS 7, carried for the releases that have no SpriteKit at all.
//
// A crop node shows its children where its mask node has content. The mask is stored and read back, as the host stores
// it (measured: a new crop node has no mask, and the mask it is given is the one it reads back, in facts/SpriteKit/
// SKCropNode.md). The crop itself is not drawn yet: it is the renderer's, which is owed.
#import "CharonSpriteKit.h"

@implementation SKCropNode

@synthesize maskNode = _maskNode;

@end
