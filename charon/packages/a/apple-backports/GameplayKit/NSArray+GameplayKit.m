// NSArray+GameplayKit.m -- the two methods NSArray carries for GameplayKit, which the framework
// answers by shuffling an array with a random source and with the system's own.
//
// Both hand the array to the source and let the source do the shuffling: -[NSArray
// shuffledArrayWithRandomSource:] sends -arrayByShufflingObjectsInArray: to the object it was given,
// which is what the host does (measured: a source that implements only that selector is asked for it
// with the whole array and its answer is what the method returns), and -shuffledArray is that same
// method over the system's own source. So there is no shuffle in this file and no second copy of one:
// the shuffle is -[GKRandomSource arrayByShufflingObjectsInArray:], which GKRandomSource.m already
// carries and whose row is in registry/GameplayKit/random.json.
//
// The archived version of this file ran a Fisher-Yates of its own over nextIntWithUpperBound: and
// shared it with the distribution family through a charon_ category. That is a second copy of a
// shuffle the framework already has, and the host measures it as one: the source is asked for the
// array, not for a sequence of bounds.
//
// Both are declared by the SDK in GKRandomSource.h's own NSArray (GameplayKit) category, so they are
// the two rows registry/GameplayKit/shuffle.json carries: a category on a class the release already
// carries is API the port carries, and entry_of() answers a member with the class's own row only when
// the PORT defines that class (charon/AGENTS.md, "A seam the port owns still needs a registry row";
// NSArray is the release's, so these two need rows of their own).

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
