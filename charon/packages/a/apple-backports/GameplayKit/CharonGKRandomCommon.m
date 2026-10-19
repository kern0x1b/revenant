// CharonGKRandomCommon.m - the shared half, on the class the headers make the base of the family.
#import "CharonGKRandomCommon.h"

@implementation GKRandomSource (CharonGKRandomCommon)
- (NSInteger)charon_nextWord:(CharonGKDraw)draw context:(void *)context
{ uint32_t word = 0; int b;
    for (b = 0; b < 4; b++) word |= (uint32_t)(*draw)(context) << (8 * b);
    return (NSInteger)(int32_t)(word & 0x7fffffffU); }
- (NSUInteger)charon_nextIntWithUpperBound:(NSUInteger)upperBound
{ if (upperBound == 0) return 0; return (NSUInteger)([self nextInt] % (NSInteger)upperBound); }
- (float)charon_nextUniform { return (float)([self nextInt] & 0x7fffffff) / 2147483648.0f; }
- (BOOL)charon_nextBool { return [self nextIntWithUpperBound:2] == 1; }
@end

void CharonGKRC4Seed(CharonGKRC4 *rc4, const unsigned char *key, size_t length)
{ size_t i; int j = 0; unsigned char swap;
    for (i = 0; i < 256; i++) rc4->state[i] = (unsigned char)i;
    for (i = 0; i < 256; i++) { unsigned char k = key[i % length]; j = (j + rc4->state[i] + k) & 0xff;
        swap = rc4->state[i]; rc4->state[i] = rc4->state[j]; rc4->state[j] = swap; }
    rc4->i = 0; rc4->j = 0; }

int CharonGKRC4Next(CharonGKRC4 *rc4)
{ unsigned char swap;
    rc4->i = (rc4->i + 1) & 0xff; rc4->j = (rc4->j + rc4->state[rc4->i]) & 0xff;
    swap = rc4->state[rc4->i]; rc4->state[rc4->i] = rc4->state[rc4->j]; rc4->state[rc4->j] = swap;
    return rc4->state[(rc4->state[rc4->i] + rc4->state[rc4->j]) & 0xff]; }
