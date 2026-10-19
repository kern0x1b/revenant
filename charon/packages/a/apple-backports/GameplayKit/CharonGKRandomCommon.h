// CharonGKRandomCommon.h - the half the four random sources share: the 31-bit word every source
// returns, the three answers the headers say are derived from -nextInt, and RC4's state.
//
// Every name is prefixed, and that is measured rather than assumed: a probe with bare file-scope
// A, M, N, UPPER and LOWER fails to compile inside Foundation's own NSObjCRuntime.h.
#ifndef CHARON_GK_RANDOM_COMMON_H
#define CHARON_GK_RANDOM_COMMON_H

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

// One 32-bit draw from a source's stream; the context is the source itself.
typedef uint32_t (*CharonGKDraw)(void *context);

// The three answers the 26.2 header derives "by default" from -nextIntWithUpperBound:, so they are
// written once here and inherited by the seeded subclasses, which supply only -nextInt.
// The class method the 26.2 header declares (sharedRandom) is implemented with the class, not here:
// declaring it again in this category would ask this file for a definition it does not carry.
@interface GKRandomSource (CharonGKRandomCommon)
- (NSInteger)charon_nextWord:(CharonGKDraw)draw context:(void *)context;
- (NSUInteger)charon_nextIntWithUpperBound:(NSUInteger)upperBound;
- (float)charon_nextUniform;
- (BOOL)charon_nextBool;
@end

// RC4's state, so GKARC4RandomSource can be seeded and advanced, and dropped by a count.
typedef struct { unsigned char state[256]; int i; int j; } CharonGKRC4;
extern void CharonGKRC4Seed(CharonGKRC4 *rc4, const unsigned char *key, size_t length);
extern int CharonGKRC4Next(CharonGKRC4 *rc4);

#endif
