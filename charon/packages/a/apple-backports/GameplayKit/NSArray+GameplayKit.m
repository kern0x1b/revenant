#import "CharonGK.h"

@implementation NSArray (GameplayKit)

- (NSArray *)shuffledArrayWithRandomSource:(GKRandomSource *)randomSource
{
    return [randomSource arrayByShufflingObjectsInArray:self];
}

- (NSArray *)shuffledArray
{
    return [self shuffledArrayWithRandomSource:[GKRandomSource sharedRandom]];
}

@end
