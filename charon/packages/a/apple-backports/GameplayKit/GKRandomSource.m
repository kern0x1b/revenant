// GKRandomSource.m - GameplayKit's random source, carried for the releases that have none.
//
// The release's sequence is NOT MT19937, and the port says so rather than pretending: the measurements
// are in facts/GameplayKit/GKRandomSource.md, and the ledger entry says what is owed.  What is
// carried is a deterministic source seeded the way the header's own -init does (5489, the reference
// MT seed) and deterministic from there.
#import "CharonGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

#define CharonGKMT_N 624
#define CharonGKMT_M 397
static uint32_t CharonGKMT[CharonGKMT_N];
static int CharonGKMTIndex;

static void CharonGKMTSeed(uint32_t seed)
{ CharonGKMT[0] = seed;
    for (CharonGKMTIndex = 1; CharonGKMTIndex < CharonGKMT_N; CharonGKMTIndex++)
        CharonGKMT[CharonGKMTIndex] =
            1812433253U * (CharonGKMT[CharonGKMTIndex-1] ^ (CharonGKMT[CharonGKMTIndex-1] >> 30))
            + (uint32_t)CharonGKMTIndex; }

static uint32_t CharonGKMTDraw(void *context)
{ uint32_t y; static const uint32_t mag[2] = { 0x0U, 0x9908b0dfU }; (void)context;
    if (CharonGKMTIndex >= CharonGKMT_N) { int k;
        for (k = 0; k < CharonGKMT_N - CharonGKMT_M; k++) {
            y = (CharonGKMT[k] & 0x80000000U) | (CharonGKMT[k+1] & 0x7fffffffU);
            CharonGKMT[k] = CharonGKMT[k+CharonGKMT_M] ^ (y >> 1) ^ mag[y & 1U]; }
        for (; k < CharonGKMT_N - 1; k++) {
            y = (CharonGKMT[k] & 0x80000000U) | (CharonGKMT[k+1] & 0x7fffffffU);
            CharonGKMT[k] = CharonGKMT[k + (CharonGKMT_M - CharonGKMT_N)] ^ (y >> 1) ^ mag[y & 1U]; }
        y = (CharonGKMT[CharonGKMT_N-1] & 0x80000000U) | (CharonGKMT[0] & 0x7fffffffU);
        CharonGKMT[CharonGKMT_N-1] = CharonGKMT[CharonGKMT_M-1] ^ (y >> 1) ^ mag[y & 1U];
        CharonGKMTIndex = 0; }
    y = CharonGKMT[CharonGKMTIndex++];
    y ^= (y >> 11); y ^= (y << 7) & 0x9d2c5680U; y ^= (y << 15) & 0xefc60000U; y ^= (y >> 18);
    return y; }

// The seed the base carries, so an archive round trip restores the same sequence.
static const uint64_t CharonGKMTDefaultSeed = 5489u;

@implementation GKRandomSource
- (instancetype)init { self = [super init];
    if (self) CharonGKMTSeed((uint32_t)CharonGKMTDefaultSeed);
    return self; }
+ (instancetype)sharedRandom
{ static GKRandomSource *shared; if (shared == nil) shared = [[GKRandomSource alloc] init]; return shared; }
// The 16.4 SDK this port builds against declares this on the INSTANCE; the 26.2 header shows
// it on the class. Carried as the build SDK declares it, and the difference is owed a row.
- (NSArray *)arrayByShufflingObjectsInArray:(NSArray *)array
{ NSMutableArray *out = [array mutableCopy]; NSUInteger n = [out count], i;
    // A Fisher-Yates walk with this source's own draws, which is what "using the random source" means.
    for (i = n - 1; i > 0; i--) { NSUInteger j = (NSUInteger)([[GKRandomSource sharedRandom] nextInt] % (NSInteger)(i + 1));
        if (j != i) [out exchangeObjectAtIndex:i withObjectAtIndex:j]; }
    return out; }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }   // the state is the value, so a copy is itself
- (instancetype)initWithCoder:(NSCoder *)coder { self = [super init];
    if (self) { uint64_t seed = CharonGKMTDefaultSeed;
        NSString *key = NSStringFromClass([self class]);
        if ([coder containsValueForKey:key]) seed = (uint64_t)[coder decodeInt64ForKey:key];
        CharonGKMTSeed((uint32_t)seed); }
    return self; }
- (void)encodeWithCoder:(NSCoder *)coder
{ [coder encodeInt64:(int64_t)CharonGKMTDefaultSeed forKey:NSStringFromClass([self class])]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (NSInteger)nextInt { return [self charon_nextWord:CharonGKMTDraw context:NULL]; }
- (NSUInteger)nextIntWithUpperBound:(NSUInteger)upperBound { return [self charon_nextIntWithUpperBound:upperBound]; }
- (float)nextUniform { return [self charon_nextUniform]; }
- (BOOL)nextBool { return [self charon_nextBool]; }
@end
