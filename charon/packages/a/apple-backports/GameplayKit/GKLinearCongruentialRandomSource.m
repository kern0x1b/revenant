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
