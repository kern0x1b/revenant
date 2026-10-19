// GKLinearCongruentialRandomSource.m - the seeded linear congruential source.
//
// NOT the release's transition, and the ledger says so: recovering (a, c) from the host's own
// consecutive outputs gives a=3096923468 c=3630308989, which predicts a fourth draw the host
// contradicts, so the release's state transition is not x = a*x + c over the full 32 bits.  Neither
// classic matches either (1664525/1013904223 and glibc's 1103515245/12345, both measured).  Carried:
// the glibc multiplier and increment over the low 32 bits, seeded the way the header's -init does (1).
#import "CharonGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

#define CharonGKLCG_A 1103515245u
#define CharonGKLCG_C 12345u
static uint32_t CharonGKLCGState;
static uint64_t CharonGKLCGSeedValue;

static uint32_t CharonGKLCGDraw(void *context)
{ (void)context; CharonGKLCGState = CharonGKLCG_A * CharonGKLCGState + CharonGKLCG_C; return CharonGKLCGState; }

@implementation GKLinearCongruentialRandomSource
- (instancetype)init { return [self initWithSeed:1u]; }
- (instancetype)initWithSeed:(uint64_t)seed { self = [super init];
    if (self) { CharonGKLCGSeedValue = seed; CharonGKLCGState = (uint32_t)seed; }
    return self; }
- (uint64_t)seed { return CharonGKLCGSeedValue; }
- (void)setSeed:(uint64_t)seed { CharonGKLCGSeedValue = seed; CharonGKLCGState = (uint32_t)seed; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSeed:CharonGKLCGSeedValue]; }
- (NSInteger)nextInt { return [self charon_nextWord:CharonGKLCGDraw context:NULL]; }
@end
