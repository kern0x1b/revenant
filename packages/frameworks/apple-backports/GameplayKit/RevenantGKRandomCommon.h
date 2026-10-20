#ifndef REVENANT_GK_RANDOM_COMMON_H
#define REVENANT_GK_RANDOM_COMMON_H

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>

typedef uint32_t (*RevenantGKDraw)(void *context);

@interface GKRandomSource (RevenantGKRandomCommon)
- (NSInteger)revenant_nextWord:(RevenantGKDraw)draw context:(void *)context;
- (NSUInteger)revenant_nextIntWithUpperBound:(NSUInteger)upperBound;
- (float)revenant_nextUniform;
- (BOOL)revenant_nextBool;
@end

typedef struct { unsigned char state[256]; int i; int j; } RevenantGKRC4;
extern void RevenantGKRC4Seed(RevenantGKRC4 *rc4, const unsigned char *key, size_t length);
extern int RevenantGKRC4Next(RevenantGKRC4 *rc4);

#endif
