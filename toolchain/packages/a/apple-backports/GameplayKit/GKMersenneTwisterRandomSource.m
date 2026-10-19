#import "RevenantGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

#define RevenantGKMT_N 624
#define RevenantGKMT_M 397
static uint32_t RevenantGKMTState[RevenantGKMT_N];
static int RevenantGKMTIndex;
static uint64_t RevenantGKMTSeedValue;

static void RevenantGKMTSeed(uint32_t seed)
{ RevenantGKMTState[0] = seed;
    for (RevenantGKMTIndex = 1; RevenantGKMTIndex < RevenantGKMT_N; RevenantGKMTIndex++)
        RevenantGKMTState[RevenantGKMTIndex] =
            1812433253U * (RevenantGKMTState[RevenantGKMTIndex-1] ^ (RevenantGKMTState[RevenantGKMTIndex-1] >> 30))
            + (uint32_t)RevenantGKMTIndex; }

static uint32_t RevenantGKMTDraw(void *context)
{ uint32_t y; static const uint32_t mag[2] = { 0x0U, 0x9908b0dfU }; (void)context;
    if (RevenantGKMTIndex >= RevenantGKMT_N) { int k;
        for (k = 0; k < RevenantGKMT_N - RevenantGKMT_M; k++) {
            y = (RevenantGKMTState[k] & 0x80000000U) | (RevenantGKMTState[k+1] & 0x7fffffffU);
            RevenantGKMTState[k] = RevenantGKMTState[k+RevenantGKMT_M] ^ (y >> 1) ^ mag[y & 1U]; }
        for (; k < RevenantGKMT_N - 1; k++) {
            y = (RevenantGKMTState[k] & 0x80000000U) | (RevenantGKMTState[k+1] & 0x7fffffffU);
            RevenantGKMTState[k] = RevenantGKMTState[k + (RevenantGKMT_M - RevenantGKMT_N)] ^ (y >> 1) ^ mag[y & 1U]; }
        y = (RevenantGKMTState[RevenantGKMT_N-1] & 0x80000000U) | (RevenantGKMTState[0] & 0x7fffffffU);
        RevenantGKMTState[RevenantGKMT_N-1] = RevenantGKMTState[RevenantGKMT_M-1] ^ (y >> 1) ^ mag[y & 1U];
        RevenantGKMTIndex = 0; }
    y = RevenantGKMTState[RevenantGKMTIndex++];
    y ^= (y >> 11); y ^= (y << 7) & 0x9d2c5680U; y ^= (y << 15) & 0xefc60000U; y ^= (y >> 18);
    return y; }

@implementation GKMersenneTwisterRandomSource
- (instancetype)init { return [self initWithSeed:5489u]; }
- (instancetype)initWithSeed:(uint64_t)seed { self = [super init];
    if (self) { RevenantGKMTSeedValue = seed; RevenantGKMTSeed((uint32_t)seed); }
    return self; }
- (uint64_t)seed { return RevenantGKMTSeedValue; }
- (void)setSeed:(uint64_t)seed { RevenantGKMTSeedValue = seed; RevenantGKMTSeed((uint32_t)seed); }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSeed:RevenantGKMTSeedValue]; }
- (NSInteger)nextInt { return [self revenant_nextWord:RevenantGKMTDraw context:NULL]; }
@end
