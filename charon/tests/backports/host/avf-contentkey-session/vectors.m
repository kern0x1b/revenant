// vectors.m - the port's sample decryption (AVContentKey's charon_decryptSampleData:error:), checked against an oracle that
// is not the port's: CommonCrypto's single-block ECB mode, with the CBC chaining and the CTR counter blocks done here by
// hand. The port uses CCCrypt for CBC and CCCryptorCreateWithMode for CTR, so the two paths are not the same code.
//
// Each case encrypts a plaintext with the oracle, then the port decrypts the ciphertext and must return the plaintext.
// The wrong-key and wrong-vector cases must be refused with an error and no bytes.
//
// Built by run.sh against the port's objects only (no host); prints one line per case and exits non-zero on a failure.
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonCrypto.h>
#import "../../../../packages/a/apple-backports/AVFoundation/CharonAVContentKey.h"

static int failures = 0;

// One AES-128 block in ECB mode: the only primitive the oracle uses.
static NSData *EcbBlock(NSData *key, const uint8_t *block, CCOperation operation)
{
    uint8_t out[kCCBlockSizeAES128];
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(operation, kCCAlgorithmAES128, kCCOptionECBMode, key.bytes, kCCKeySizeAES128, NULL,
                                     block, kCCBlockSizeAES128, out, sizeof out, &moved);
    if (status != kCCSuccess || moved != sizeof out) return nil;
    return [NSData dataWithBytes:out length:sizeof out];
}

// CBC encryption by hand: each block is the ECB encryption of the plaintext block XOR the previous ciphertext block.
static NSData *OracleCBCEncrypt(NSData *key, NSData *iv, NSData *plaintext)
{
    NSMutableData *out = [NSMutableData data];
    uint8_t previous[kCCBlockSizeAES128];
    memcpy(previous, iv.bytes, kCCBlockSizeAES128);
    const uint8_t *p = plaintext.bytes;
    for (NSUInteger offset = 0; offset < plaintext.length; offset += kCCBlockSizeAES128) {
        uint8_t block[kCCBlockSizeAES128];
        for (int i = 0; i < kCCBlockSizeAES128; i++) block[i] = p[offset + i] ^ previous[i];
        NSData *cipher = EcbBlock(key, block, kCCEncrypt);
        memcpy(previous, cipher.bytes, kCCBlockSizeAES128);
        [out appendData:cipher];
    }
    return out;
}

// PKCS#7 padding, by hand: the padding is the number of bytes that complete the last block, each of that value.
static NSData *Pkcs7Pad(NSData *plaintext)
{
    NSUInteger pad = kCCBlockSizeAES128 - (plaintext.length % kCCBlockSizeAES128);
    NSMutableData *padded = [plaintext mutableCopy];
    for (NSUInteger i = 0; i < pad; i++) {
        uint8_t byte = (uint8_t)pad;
        [padded appendBytes:&byte length:1];
    }
    return padded;
}

// CTR keystream by hand: block i is the 8-byte vector followed by the big-endian 64-bit counter i, encrypted with ECB.
static NSData *OracleCTR(NSData *key, NSData *vector8, NSData *input)
{
    NSMutableData *out = [NSMutableData dataWithLength:input.length];
    const uint8_t *in = input.bytes;
    uint8_t *o = out.mutableBytes;
    for (NSUInteger offset = 0; offset < input.length; offset += kCCBlockSizeAES128) {
        uint8_t counter[kCCBlockSizeAES128];
        memcpy(counter, vector8.bytes, 8);
        uint64_t index = offset / kCCBlockSizeAES128;
        for (int i = 0; i < 8; i++) counter[8 + i] = (uint8_t)(index >> (56 - 8 * i));
        NSData *keystream = EcbBlock(key, counter, kCCEncrypt);
        const uint8_t *k = keystream.bytes;
        for (NSUInteger i = 0; i < kCCBlockSizeAES128 && offset + i < input.length; i++) {
            o[offset + i] = in[offset + i] ^ k[i];
        }
    }
    return out;
}

static void Check(NSString *label, NSData *got, NSData *want, NSError *error)
{
    BOOL same = got && [got isEqualToData:want];
    printf("%s %s%s\n", same ? "ok  " : "FAIL", [label UTF8String], error ? [[NSString stringWithFormat:@" (error %ld)", (long)error.code] UTF8String] : "");
    if (!same) failures++;
}

static void CheckRefused(NSString *label, AVContentKey *key, NSData *input)
{
    NSError *error = nil;
    NSData *got = [key charon_decryptSampleData:input error:&error];
    BOOL refused = got == nil && error != nil;
    printf("%s %s\n", refused ? "ok  " : "FAIL", [label UTF8String]);
    if (!refused) failures++;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // The NIST SP 800-38A F.2 key, used for every case; the vectors are the oracle's, built per case.
        const uint8_t keyBytes[16] = { 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
        const uint8_t ivBytes[16] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };
        NSData *key = [NSData dataWithBytes:keyBytes length:16];
        NSData *iv = [NSData dataWithBytes:ivBytes length:16];
        NSData *plaintext = [@"charon sample data 0123456789abcdef-tail" dataUsingEncoding:NSUTF8StringEncoding];

        // CBC (16-byte vector): padded plaintext of several lengths, from an exact block to a short tail.
        for (NSUInteger length = 0; length <= 40; length += 7) {
            NSData *p = [plaintext subdataWithRange:NSMakeRange(0, length)];
            NSData *cipher = OracleCBCEncrypt(key, iv, Pkcs7Pad(p));
            AVContentKey *ck = [AVContentKey charon_contentKeyWithSpecifier:nil keyData:key initializationVector:iv];
            NSError *error = nil;
            NSData *got = [ck charon_decryptSampleData:cipher error:&error];
            Check([NSString stringWithFormat:@"cbc length %lu", (unsigned long)length], got, p, error);
        }
        // Exactly one full padding block: a 16-byte plaintext gives 32 bytes of ciphertext.
        {
            NSData *p = [plaintext subdataWithRange:NSMakeRange(0, 16)];
            AVContentKey *ck = [AVContentKey charon_contentKeyWithSpecifier:nil keyData:key initializationVector:iv];
            NSError *error = nil;
            NSData *got = [ck charon_decryptSampleData:OracleCBCEncrypt(key, iv, Pkcs7Pad(p)) error:&error];
            Check(@"cbc whole padding block", got, p, error);
        }

        // CTR (8-byte vector): the sample is decrypted whole from counter zero; several lengths, across block boundaries.
        NSData *vector8 = [iv subdataWithRange:NSMakeRange(0, 8)];
        for (NSUInteger length = 1; length <= 40; length += 13) {
            NSData *p = [plaintext subdataWithRange:NSMakeRange(0, length)];
            NSData *cipher = OracleCTR(key, vector8, p);
            AVContentKey *ck = [AVContentKey charon_contentKeyWithSpecifier:nil keyData:key initializationVector:vector8];
            NSError *error = nil;
            NSData *got = [ck charon_decryptSampleData:cipher error:&error];
            Check([NSString stringWithFormat:@"ctr length %lu", (unsigned long)length], got, p, error);
        }

        // Refusals: a key that is not 16 bytes, and a vector that is neither 8 nor 16 bytes.
        AVContentKey *shortKey = [AVContentKey charon_contentKeyWithSpecifier:nil keyData:[NSData dataWithBytes:keyBytes length:15]
                                                          initializationVector:iv];
        CheckRefused(@"refuses a 15-byte key", shortKey, plaintext);
        AVContentKey *oddVector = [AVContentKey charon_contentKeyWithSpecifier:nil keyData:key
                                                          initializationVector:[iv subdataWithRange:NSMakeRange(0, 12)]];
        CheckRefused(@"refuses a 12-byte vector", oddVector, plaintext);
    }
    printf("%s\n", failures == 0 ? "avf-contentkey-session decryption: OK" : "avf-contentkey-session decryption: FAILED");
    return failures == 0 ? 0 : 1;
}
