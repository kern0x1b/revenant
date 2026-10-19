#import "CharonGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

static CharonGKRC4 CharonGKRC4State;
static NSData *CharonGKRC4SeedValue;

static uint32_t CharonGKRC4Draw(void *context) { (void)context; return (uint32_t)CharonGKRC4Next(&CharonGKRC4State); }

@implementation GKARC4RandomSource
- (instancetype)init
{ return [self initWithSeed:[@"charon-arc4-seed" dataUsingEncoding:NSUTF8StringEncoding]]; }
- (instancetype)initWithSeed:(NSData *)seed { self = [super init];
    if (self) [self setSeed:seed];
    return self; }
- (NSData *)seed { return CharonGKRC4SeedValue; }
- (void)setSeed:(NSData *)seed
{ CharonGKRC4SeedValue = [seed copy];
    if ([seed length] > 0) CharonGKRC4Seed(&CharonGKRC4State, (const unsigned char *)[seed bytes], [seed length]);
    else CharonGKRC4Seed(&CharonGKRC4State, (const unsigned char *)"", 1); }
- (void)dropValuesWithCount:(NSUInteger)count
{ NSUInteger n; for (n = 0; n < count; n++) (void)CharonGKRC4Next(&CharonGKRC4State); }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSeed:CharonGKRC4SeedValue ?: [@"charon-arc4-seed" dataUsingEncoding:NSUTF8StringEncoding]]; }
- (NSInteger)nextInt { return [self charon_nextWord:CharonGKRC4Draw context:NULL]; }
@end
