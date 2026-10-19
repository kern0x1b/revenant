// AVContentKey145.m - AVContentKey as of 14.5: the key a content key session hands a recipient, for the content it names.
// An application never makes one; the session makes it from a clear key response (AVContentKeySession103.m) and gives
// it to each recipient that asks, through -contentKeySession:didProvideContentKey:. The key's own decryption is the port's
// (below), over CommonCrypto, since 6.1.3 has no CoreMedia cryptor for it.
//
// Carried here: the declared members contentKeySpecifier (14.5), externalContentProtectionStatus and revoke (17.4), with
// what is measured and what is not in facts/AVFoundation/ContentKeySession.md.
#import "CharonAVContentKey.h"
#import <AVFoundation/AVContentKeySession.h>
#import <CommonCrypto/CommonCryptor.h>
#import <Foundation/Foundation.h>

@implementation AVContentKey {
    AVContentKeySpecifier *_contentKeySpecifier;
    NSData *_keyData;
    NSData *_initializationVector;
}

+ (instancetype)charon_contentKeyWithSpecifier:(AVContentKeySpecifier *)specifier keyData:(NSData *)keyData
                          initializationVector:(NSData *)initializationVector
{
    AVContentKey *key = [[self alloc] init];
    key->_contentKeySpecifier = specifier;
    key->_keyData = [keyData copy];
    key->_initializationVector = [initializationVector copy];
    return key;
}

- (AVContentKeySpecifier *)contentKeySpecifier
{
    return _contentKeySpecifier;
}

// Pending for a key the session has just handed out (measured on the host: 0, which is Pending). The protection of the
// external display is not checked here, so the answer does not change.
- (AVExternalContentProtectionStatus)externalContentProtectionStatus
{
    return AVExternalContentProtectionStatusPending;
}

// The host's effect of revoking a key that a recipient holds is not measured: the call answers without error, and the port
// makes no change to the key it has handed out (facts/AVFoundation/ContentKeySession.md).
- (void)revoke
{
}

- (NSData *)charon_decryptSampleData:(NSData *)sampleData error:(NSError **)error
{
    if (_keyData.length != kCCKeySizeAES128) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:kCCParamError userInfo:nil];
        return nil;
    }
    NSUInteger vectorLength = _initializationVector.length;
    if (vectorLength != kCCBlockSizeAES128 && vectorLength != 8) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:kCCParamError userInfo:nil];
        return nil;
    }

    if (vectorLength == kCCBlockSizeAES128) {
        // CBC, with the padding of the last block removed: the HLS AES-128 form of a segment.
        size_t capacity = sampleData.length + kCCBlockSizeAES128;
        NSMutableData *out = [NSMutableData dataWithLength:capacity];
        size_t moved = 0;
        CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                         _keyData.bytes, kCCKeySizeAES128, _initializationVector.bytes,
                                         sampleData.bytes, sampleData.length, out.mutableBytes, capacity, &moved);
        if (status != kCCSuccess) {
            if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            return nil;
        }
        out.length = moved;
        return out;
    }

    // CTR, with the 8-byte vector as the first half of the counter block and the second half counting from zero.
    uint8_t counter[kCCBlockSizeAES128];
    memset(counter, 0, sizeof counter);
    memcpy(counter, _initializationVector.bytes, 8);
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeCTR, kCCAlgorithmAES128, ccNoPadding,
                                                     counter, _keyData.bytes, kCCKeySizeAES128, NULL, 0, 0, 0, &cryptor);
    if (status != kCCSuccess) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return nil;
    }
    NSMutableData *out = [NSMutableData dataWithLength:sampleData.length];
    size_t moved = 0;
    status = CCCryptorUpdate(cryptor, sampleData.bytes, sampleData.length, out.mutableBytes, out.length, &moved);
    CCCryptorRelease(cryptor);
    if (status != kCCSuccess) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return nil;
    }
    out.length = moved;
    return out;
}

@end
