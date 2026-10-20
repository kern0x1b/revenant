#import "RevenantGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

#define RevenantGKMT_N 624
#define RevenantGKMT_M 397
static uint32_t RevenantGKMT[RevenantGKMT_N];
static int RevenantGKMTIndex;

static void RevenantGKMTSeed(uint32_t seed)
{ RevenantGKMT[0] = seed;
    for (RevenantGKMTIndex = 1; RevenantGKMTIndex < RevenantGKMT_N; RevenantGKMTIndex++)
        RevenantGKMT[RevenantGKMTIndex] =
            1812433253U * (RevenantGKMT[RevenantGKMTIndex-1] ^ (RevenantGKMT[RevenantGKMTIndex-1] >> 30))
            + (uint32_t)RevenantGKMTIndex; }

static uint32_t RevenantGKMTDraw(void *context)
{ uint32_t y; static const uint32_t mag[2] = { 0x0U, 0x9908b0dfU }; (void)context;
    if (RevenantGKMTIndex >= RevenantGKMT_N) { int k;
        for (k = 0; k < RevenantGKMT_N - RevenantGKMT_M; k++) {
            y = (RevenantGKMT[k] & 0x80000000U) | (RevenantGKMT[k+1] & 0x7fffffffU);
            RevenantGKMT[k] = RevenantGKMT[k+RevenantGKMT_M] ^ (y >> 1) ^ mag[y & 1U]; }
        for (; k < RevenantGKMT_N - 1; k++) {
            y = (RevenantGKMT[k] & 0x80000000U) | (RevenantGKMT[k+1] & 0x7fffffffU);
            RevenantGKMT[k] = RevenantGKMT[k + (RevenantGKMT_M - RevenantGKMT_N)] ^ (y >> 1) ^ mag[y & 1U]; }
        y = (RevenantGKMT[RevenantGKMT_N-1] & 0x80000000U) | (RevenantGKMT[0] & 0x7fffffffU);
        RevenantGKMT[RevenantGKMT_N-1] = RevenantGKMT[RevenantGKMT_M-1] ^ (y >> 1) ^ mag[y & 1U];
        RevenantGKMTIndex = 0; }
    y = RevenantGKMT[RevenantGKMTIndex++];
    y ^= (y >> 11); y ^= (y << 7) & 0x9d2c5680U; y ^= (y << 15) & 0xefc60000U; y ^= (y >> 18);
    return y; }

static const uint64_t RevenantGKMTDefaultSeed = 5489u;

@implementation GKRandomSource
- (instancetype)init { self = [super init];
    if (self) RevenantGKMTSeed((uint32_t)RevenantGKMTDefaultSeed);
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
    if (self) { uint64_t seed = RevenantGKMTDefaultSeed;
        NSString *key = NSStringFromClass([self class]);
        if ([coder containsValueForKey:key]) seed = (uint64_t)[coder decodeInt64ForKey:key];
        RevenantGKMTSeed((uint32_t)seed); }
    return self; }
- (void)encodeWithCoder:(NSCoder *)coder
{ [coder encodeInt64:(int64_t)RevenantGKMTDefaultSeed forKey:NSStringFromClass([self class])]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (NSInteger)nextInt { return [self revenant_nextWord:RevenantGKMTDraw context:NULL]; }
- (NSUInteger)nextIntWithUpperBound:(NSUInteger)upperBound { return [self revenant_nextIntWithUpperBound:upperBound]; }
- (float)nextUniform { return [self revenant_nextUniform]; }
- (BOOL)nextBool { return [self revenant_nextBool]; }
@end
