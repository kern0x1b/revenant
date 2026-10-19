// GKMersenneTwisterRandomSource.m - the seeded Mersenne Twister, carried as the standard MT19937.
//
// The release's own sequence is NOT MT19937 and the ledger says so: four seeds measured, and the
// scalings (raw, & 0x7fffffff, >> 1, a signed cast) and the seedings (init_genrand, init_by_array,
// init_by_array with four words) all differ.  What is carried is the standard algorithm, seeded the
// way the header's own -init does, and deterministic from there.  facts/GameplayKit/GKRandomSource.md.
#import "CharonGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

#define CharonGKMT_N 624
#define CharonGKMT_M 397
static uint32_t CharonGKMTState[CharonGKMT_N];
static int CharonGKMTIndex;
static uint64_t CharonGKMTSeedValue;

static void CharonGKMTSeed(uint32_t seed)
{ CharonGKMTState[0] = seed;
    for (CharonGKMTIndex = 1; CharonGKMTIndex < CharonGKMT_N; CharonGKMTIndex++)
        CharonGKMTState[CharonGKMTIndex] =
            1812433253U * (CharonGKMTState[CharonGKMTIndex-1] ^ (CharonGKMTState[CharonGKMTIndex-1] >> 30))
            + (uint32_t)CharonGKMTIndex; }

static uint32_t CharonGKMTDraw(void *context)
{ uint32_t y; static const uint32_t mag[2] = { 0x0U, 0x9908b0dfU }; (void)context;
    if (CharonGKMTIndex >= CharonGKMT_N) { int k;
        for (k = 0; k < CharonGKMT_N - CharonGKMT_M; k++) {
            y = (CharonGKMTState[k] & 0x80000000U) | (CharonGKMTState[k+1] & 0x7fffffffU);
            CharonGKMTState[k] = CharonGKMTState[k+CharonGKMT_M] ^ (y >> 1) ^ mag[y & 1U]; }
        for (; k < CharonGKMT_N - 1; k++) {
            y = (CharonGKMTState[k] & 0x80000000U) | (CharonGKMTState[k+1] & 0x7fffffffU);
            CharonGKMTState[k] = CharonGKMTState[k + (CharonGKMT_M - CharonGKMT_N)] ^ (y >> 1) ^ mag[y & 1U]; }
        y = (CharonGKMTState[CharonGKMT_N-1] & 0x80000000U) | (CharonGKMTState[0] & 0x7fffffffU);
        CharonGKMTState[CharonGKMT_N-1] = CharonGKMTState[CharonGKMT_M-1] ^ (y >> 1) ^ mag[y & 1U];
        CharonGKMTIndex = 0; }
    y = CharonGKMTState[CharonGKMTIndex++];
    y ^= (y >> 11); y ^= (y << 7) & 0x9d2c5680U; y ^= (y << 15) & 0xefc60000U; y ^= (y >> 18);
    return y; }

@implementation GKMersenneTwisterRandomSource
- (instancetype)init { return [self initWithSeed:5489u]; }
- (instancetype)initWithSeed:(uint64_t)seed { self = [super init];
    if (self) { CharonGKMTSeedValue = seed; CharonGKMTSeed((uint32_t)seed); }
    return self; }
- (uint64_t)seed { return CharonGKMTSeedValue; }
- (void)setSeed:(uint64_t)seed { CharonGKMTSeedValue = seed; CharonGKMTSeed((uint32_t)seed); }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSeed:CharonGKMTSeedValue]; }
- (NSInteger)nextInt { return [self charon_nextWord:CharonGKMTDraw context:NULL]; }
@end
