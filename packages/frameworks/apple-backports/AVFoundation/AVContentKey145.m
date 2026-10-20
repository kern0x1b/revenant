#import "RevenantAVContentKey.h"
#import <AVFoundation/AVContentKeySession.h>
#import <CommonCrypto/CommonCryptor.h>
#import <Foundation/Foundation.h>

@implementation AVContentKey {
    AVContentKeySpecifier *_contentKeySpecifier;
    NSData *_keyData;
    NSData *_initializationVector;
}

+ (instancetype)revenant_contentKeyWithSpecifier:(AVContentKeySpecifier *)specifier keyData:(NSData *)keyData
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

- (AVExternalContentProtectionStatus)externalContentProtectionStatus
{
    return AVExternalContentProtectionStatusPending;
}

- (void)revoke
{
}

- (NSData *)revenant_decryptSampleData:(NSData *)sampleData error:(NSError **)error
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
