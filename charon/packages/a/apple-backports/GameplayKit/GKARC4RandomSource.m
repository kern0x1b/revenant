// GKARC4RandomSource.m - the seeded ARC4 source.
//
// NOT the release's keystream, and the ledger says so: from the seed NSData the host's first four
// words are -268849773 560625053 -478456873 -465298256 where RC4 gives 330168815 494234145 1465088995
// 807159012, and it still differs after dropValuesWithCount: 1536 and with a 16-byte zero-padded key.
// Carried: standard RC4 keyed by the seed bytes, with the header's -dropValuesWithCount: advancing
// the keystream that many words.
#import "CharonGKRandomCommon.h"
#import <GameplayKit/GameplayKit.h>

static CharonGKRC4 CharonGKRC4State;
static NSData *CharonGKRC4SeedValue;

static uint32_t CharonGKRC4Draw(void *context) { (void)context; return (uint32_t)CharonGKRC4Next(&CharonGKRC4State); }

@implementation GKARC4RandomSource
// -init is declared on this class by the 26.2 header, so it is answered here; answering it means
// overriding the base's designated initialiser, which is the one warning the compiler still gives and
// which is recorded as owed rather than silenced.
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
