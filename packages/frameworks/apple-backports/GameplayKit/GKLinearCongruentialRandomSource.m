#import "RevenantGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

#define RevenantGKLCG_A 1103515245u
#define RevenantGKLCG_C 12345u
static uint32_t RevenantGKLCGState;
static uint64_t RevenantGKLCGSeedValue;

static uint32_t RevenantGKLCGDraw(void *context)
{ (void)context; RevenantGKLCGState = RevenantGKLCG_A * RevenantGKLCGState + RevenantGKLCG_C; return RevenantGKLCGState; }

@implementation GKLinearCongruentialRandomSource
- (instancetype)init { return [self initWithSeed:1u]; }
- (instancetype)initWithSeed:(uint64_t)seed { self = [super init];
    if (self) { RevenantGKLCGSeedValue = seed; RevenantGKLCGState = (uint32_t)seed; }
    return self; }
- (uint64_t)seed { return RevenantGKLCGSeedValue; }
- (void)setSeed:(uint64_t)seed { RevenantGKLCGSeedValue = seed; RevenantGKLCGState = (uint32_t)seed; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSeed:RevenantGKLCGSeedValue]; }
- (NSInteger)nextInt { return [self revenant_nextWord:RevenantGKLCGDraw context:NULL]; }
@end
