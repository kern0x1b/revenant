#ifndef CHARON_GK_RANDOM_COMMON_H
#define CHARON_GK_RANDOM_COMMON_H

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

typedef uint32_t (*CharonGKDraw)(void *context);

@interface GKRandomSource (CharonGKRandomCommon)
- (NSInteger)charon_nextWord:(CharonGKDraw)draw context:(void *)context;
- (NSUInteger)charon_nextIntWithUpperBound:(NSUInteger)upperBound;
- (float)charon_nextUniform;
- (BOOL)charon_nextBool;
@end

typedef struct { unsigned char state[256]; int i; int j; } CharonGKRC4;
extern void CharonGKRC4Seed(CharonGKRC4 *rc4, const unsigned char *key, size_t length);
extern int CharonGKRC4Next(CharonGKRC4 *rc4);

#endif
