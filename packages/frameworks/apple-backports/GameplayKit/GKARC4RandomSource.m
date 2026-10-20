#import "RevenantGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

static RevenantGKRC4 RevenantGKRC4State;
static NSData *RevenantGKRC4SeedValue;

static uint32_t RevenantGKRC4Draw(void *context) { (void)context; return (uint32_t)RevenantGKRC4Next(&RevenantGKRC4State); }

@implementation GKARC4RandomSource
- (instancetype)init
{ return [self initWithSeed:[@"revenant-arc4-seed" dataUsingEncoding:NSUTF8StringEncoding]]; }
- (instancetype)initWithSeed:(NSData *)seed { self = [super init];
    if (self) [self setSeed:seed];
    return self; }
- (NSData *)seed { return RevenantGKRC4SeedValue; }
- (void)setSeed:(NSData *)seed
{ RevenantGKRC4SeedValue = [seed copy];
    if ([seed length] > 0) RevenantGKRC4Seed(&RevenantGKRC4State, (const unsigned char *)[seed bytes], [seed length]);
    else RevenantGKRC4Seed(&RevenantGKRC4State, (const unsigned char *)"", 1); }
- (void)dropValuesWithCount:(NSUInteger)count
{ NSUInteger n; for (n = 0; n < count; n++) (void)RevenantGKRC4Next(&RevenantGKRC4State); }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSeed:RevenantGKRC4SeedValue ?: [@"revenant-arc4-seed" dataUsingEncoding:NSUTF8StringEncoding]]; }
- (NSInteger)nextInt { return [self revenant_nextWord:RevenantGKRC4Draw context:NULL]; }
@end
