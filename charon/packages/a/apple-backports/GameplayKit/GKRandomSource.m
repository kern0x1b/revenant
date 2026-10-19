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

static const uint64_t CharonGKMTDefaultSeed = 5489u;

@implementation GKRandomSource
- (instancetype)init { self = [super init];
    if (self) CharonGKMTSeed((uint32_t)CharonGKMTDefaultSeed);
    return self; }
+ (instancetype)sharedRandom
{ static GKRandomSource *shared; if (shared == nil) shared = [[GKRandomSource alloc] init]; return shared; }
- (NSArray *)arrayByShufflingObjectsInArray:(NSArray *)array
{ NSMutableArray *out = [array mutableCopy]; NSUInteger n = [out count], i;
    for (i = n - 1; i > 0; i--) { NSUInteger j = (NSUInteger)([[GKRandomSource sharedRandom] nextInt] % (NSInteger)(i + 1));
        if (j != i) [out exchangeObjectAtIndex:i withObjectAtIndex:j]; }
    return out; }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
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
