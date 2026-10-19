#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import "check.h"
#import "RevenantCKWebAuth.h"

extern void *revenantHost_SecKeyCreateSignature(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFErrorRef *);
extern bool revenantHost_SecKeyVerifySignature(SecKeyRef, SecKeyAlgorithm, CFDataRef, CFDataRef, CFErrorRef *);
extern CFDataRef revenantHost_SecKeyCopyKeyExchangeResult(SecKeyRef, SecKeyAlgorithm, SecKeyRef, CFDictionaryRef, CFErrorRef *);
extern bool revenantHost_SecKeyIsAlgorithmSupported(SecKeyRef, SecKeyOperationType, SecKeyAlgorithm);

extern void RevenantShimMarkPortKey(SecKeyRef, const uint8_t *, size_t);
extern void RevenantShimMarkPortPublicKey(SecKeyRef);
extern void RevenantShimMarkReleaseKey(SecKeyRef, CFStringRef);

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    revenant_check(passed, [name UTF8String], detail);
}

static NSData *digestOf(NSData *message)
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(message.bytes, (CC_LONG)message.length, digest);
    return [NSData dataWithBytes:digest length:sizeof digest];
}

static SecKeyRef randomKey(NSString *type, SecKeyRef *publicOut)
{
    NSDictionary *attributes = @{(__bridge id)kSecAttrKeyType: type,
                                 (__bridge id)kSecAttrKeySizeInBits: @256,
                                 (__bridge id)kSecAttrIsPermanent: @NO};
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
    if (error) {
        CFRelease(error);
    }
    if (!privateKey) {
        return NULL;
    }
    if (publicOut) {
        *publicOut = SecKeyCopyPublicKey(privateKey);
    }
    return privateKey;
}

static NSData *pointOf(SecKeyRef publicKey);

static NSData *scalarOf(SecKeyRef privateKey, SecKeyRef publicKey)
{
    CFErrorRef error = NULL;
    CFDataRef external = SecKeyCopyExternalRepresentation(privateKey, &error);
    if (error) {
        CFRelease(error);
    }
    if (!external) {
        return nil;
    }
    NSData *blob = CFBridgingRelease(external);
    NSData *point = pointOf(publicKey);
    if (point.length != 65) {
        return nil;
    }
    const uint8_t *bytes = blob.bytes;
    for (NSUInteger offset = 0; offset + 32 <= blob.length; offset++) {
        uint8_t derived[65];
        if (RevenantCKPublicKeyES256(bytes + offset, derived) == 65 && memcmp(derived, point.bytes, 65) == 0) {
            return [NSData dataWithBytes:bytes + offset length:32];
        }
    }
    return nil;
}

static NSData *pointOf(SecKeyRef publicKey)
{
    CFErrorRef error = NULL;
    CFDataRef external = SecKeyCopyExternalRepresentation(publicKey, &error);
    if (error) {
        CFRelease(error);
    }
    if (!external) {
        return nil;
    }
    return CFBridgingRelease(external);
}

static NSData *hostSignature(SecKeyRef privateKey, NSData *digest, SecKeyAlgorithm algorithm)
{
    CFErrorRef error = NULL;
    CFDataRef signature = SecKeyCreateSignature(privateKey, algorithm, (__bridge CFDataRef)digest, &error);
    if (error) {
        CFRelease(error);
    }
    if (!signature) {
        return nil;
    }
    return CFBridgingRelease(signature);
}

static BOOL hostVerifies(SecKeyRef publicKey, NSData *data, NSData *signature, SecKeyAlgorithm algorithm)
{
    CFErrorRef error = NULL;
    BOOL valid = SecKeyVerifySignature(publicKey, algorithm, (__bridge CFDataRef)data,
                                       (__bridge CFDataRef)signature, &error);
    if (error) {
        CFRelease(error);
    }
    return valid;
}

static NSData *opensslScalar(NSString *folder, NSString *name)
{
    NSData *text = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:
                                                     [name stringByAppendingPathExtension:@"scalar"]]];
    if (!text) {
        return nil;
    }
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger index = 0; index < text.length; index++) {
        char c = (char)((const char *)text.bytes)[index];
        if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
            [hex appendFormat:@"%c", c];
        }
    }
    if (hex.length != 64) {
        return nil;
    }
    NSData *digits = [hex dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *scalar = [NSMutableData dataWithCapacity:32];
    for (NSUInteger digit = 0; digit + 1 < digits.length; digit += 2) {
        unsigned value = 0;
        for (NSUInteger half = 0; half < 2; half++) {
            char c = (char)((const char *)digits.bytes)[digit + half];
            unsigned nibble = (c >= '0' && c <= '9') ? (unsigned)(c - '0')
                            : (c >= 'a' && c <= 'f') ? (unsigned)(c - 'a' + 10)
                            : (c >= 'A' && c <= 'F') ? (unsigned)(c - 'A' + 10) : 16u;
            if (nibble > 15) {
                nibble = 0;
            }
            value = (value << 4) | nibble;
        }
        uint8_t byte = (uint8_t)value;
        [scalar appendBytes:&byte length:1];
    }
    return scalar;
}

static SecKeyRef inMemoryKey(NSData *point, NSData *scalar, bool wantPrivate)
{
    if (point.length != 65 || ((const uint8_t *)point.bytes)[0] != 0x04) {
        return NULL;
    }
    if (wantPrivate && scalar.length != 32) {
        return NULL;
    }
    NSMutableData *material = [NSMutableData dataWithData:point];
    if (wantPrivate) {
        [material appendData:scalar];
    }
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    if (!attributes) {
        return NULL;
    }
    CFDictionarySetValue(attributes, kSecAttrKeyType, kSecAttrKeyTypeECSECPrimeRandom);
    CFDictionarySetValue(attributes, kSecAttrKeyClass,
                         wantPrivate ? kSecAttrKeyClassPrivate : kSecAttrKeyClassPublic);
    CFDataRef bytes = CFDataCreate(kCFAllocatorDefault, material.bytes, (CFIndex)material.length);
    if (bytes) {
        CFErrorRef error = NULL;
        SecKeyRef key = SecKeyCreateWithData(bytes, attributes, &error);
        if (error) {
            CFRelease(error);
        }
        CFRelease(bytes);
        CFRelease(attributes);
        return key;
    }
    CFRelease(attributes);
    return NULL;
}

int main(int argc, char **argv)
{
    NSString *folder = argc > 1 ? @(argv[1]) : @".";
    setvbuf(stdout, NULL, _IOLBF, 0);

    SecKeyAlgorithm revenantHostECDH = (SecKeyAlgorithm)CFSTR("ECDH.standardX963");
    SecKeyAlgorithm hashedECDH = (SecKeyAlgorithm)CFSTR("ECDH.standardX963SHA256");
    SecKeyAlgorithm digestAlgorithm = kSecKeyAlgorithmECDSASignatureDigestX962SHA256;

    SecKeyRef hostPrivatePublic = NULL;
    SecKeyRef hostPrivate = randomKey((__bridge id)kSecAttrKeyTypeECSECPrimeRandom, &hostPrivatePublic);
    if (hostPrivate == NULL || hostPrivatePublic == NULL) {
        printf("FAIL the host made no P-256 key pair: nothing to compare against\n");
        return 1;
    }
    RevenantShimMarkReleaseKey(hostPrivate, kSecAttrKeyTypeECSECPrimeRandom);
    RevenantShimMarkReleaseKey(hostPrivatePublic, kSecAttrKeyTypeECSECPrimeRandom);
    NSData *hostScalar = scalarOf(hostPrivate, hostPrivatePublic);
    NSData *hostPoint = pointOf(hostPrivatePublic);
    revenant_check(hostScalar.length == 32, @"the host's private key exports a 32 byte scalar",
                     [NSString stringWithFormat:@"%lu bytes", (unsigned long)hostScalar.length]);
    check_named(hostPoint.length == 65 && ((const uint8_t *)hostPoint.bytes)[0] == 0x04,
                 @"and its public key an uncompressed 65 byte point",
                     [NSString stringWithFormat:@"%lu bytes", (unsigned long)hostPoint.length]);
    if (hostScalar.length != 32 || hostPoint.length != 65) {
        return revenant_failures == 0 ? 0 : 1;
    }

    SecKeyAlgorithm ecdsa = kSecKeyAlgorithmECDSASignatureDigestX962SHA256;
    SecKeyAlgorithm ecdh = kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA256;

    for (NSUInteger length = 0; length <= 130; length += 65) {
        NSMutableData *message = [NSMutableData dataWithLength:length];
        if (length > 0) {
            arc4random_buf(message.mutableBytes, length);
        }
        NSData *digest = digestOf(message);
        uint8_t der[72];
        int written = RevenantCKDigestSignES256(hostScalar.bytes, digest.bytes, der, sizeof der);
        check_named(written > 0,
                     [NSString stringWithFormat:@"the port signs a %lu byte message", (unsigned long)length],
                     [NSString stringWithFormat:@"the port wrote %d bytes", written]);
        if (written <= 0) {
            continue;
        }
        NSData *signature = [NSData dataWithBytes:der length:(NSUInteger)written];
        check_named(hostVerifies(hostPrivatePublic, digest, signature, ecdsa),
                     [NSString stringWithFormat:@"and the host's own SecKeyVerifySignature accepts it, for a %lu byte message", (unsigned long)length],
                     @"the host refused a signature the port made");
        check_named(!hostVerifies(hostPrivatePublic, digest, signature, kSecKeyAlgorithmECDSASignatureDigestX962SHA384),
                     [NSString stringWithFormat:@"and the host refuses it under another algorithm, for a %lu byte message", (unsigned long)length],
                     @"the host accepted the signature under SHA-384 as well");
    }

    for (NSUInteger length = 0; length <= 130; length += 65) {
        NSMutableData *message = [NSMutableData dataWithLength:length];
        if (length > 0) {
            arc4random_buf(message.mutableBytes, length);
        }
        NSData *digest = digestOf(message);
        NSData *signature = hostSignature(hostPrivate, digest, ecdsa);
        check_named(signature.length > 0,
                     [NSString stringWithFormat:@"the host signs a %lu byte message", (unsigned long)length],
                     [NSString stringWithFormat:@"%lu bytes", (unsigned long)signature.length]);
        if (signature.length == 0) {
            continue;
        }
        check_named(RevenantCKDigestVerifyES256(hostPoint.bytes, hostPoint.length, digest.bytes,
                                               signature.bytes, signature.length),
                     [NSString stringWithFormat:@"and the port accepts that signature, for a %lu byte message", (unsigned long)length],
                     @"the port refused a signature the host made");
        uint8_t other[CC_SHA256_DIGEST_LENGTH];
        memset(other, length == 0 ? 0x5a : 0xa5, sizeof other);
        check_named(!RevenantCKDigestVerifyES256(hostPoint.bytes, hostPoint.length, other,
                                                signature.bytes, signature.length),
                     [NSString stringWithFormat:@"and refuses it for another message, for a %lu byte message", (unsigned long)length],
                     @"the port accepted a signature of a different message");
    }

    static const uint8_t order[32] = {0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
                                      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                                      0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
                                      0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51};
    uint8_t half[32];
    memset(half, 0, sizeof half);
    for (int index = 0; index < 31; index++) {
        half[index] = (uint8_t)((order[index] >> 1) | ((order[index + 1] & 1u) << 7));
    }
    half[31] = (uint8_t)(order[31] >> 1);
    NSUInteger lowS = 0, portLowS = 0, samples = 24;
    for (NSUInteger sample = 0; sample < samples; sample++) {
        NSMutableData *message = [NSMutableData dataWithLength:32];
        arc4random_buf(message.mutableBytes, 32);
        NSData *digest = digestOf(message);
        NSData *host = hostSignature(hostPrivate, digest, ecdsa);
        if (host.length > 8) {
            const uint8_t *bytes = host.bytes;
            size_t firstSize = bytes[3];
            const uint8_t *second = bytes + 4 + firstSize;
            if (second[0] == 0x02 && second[1] <= 33) {
                uint8_t value[32];
                memset(value, 0, sizeof value);
                size_t skip = second[1] > 32 ? 1u : 0u;
                memcpy(value + (32 - (second[1] - skip)), second + 2 + skip, second[1] - skip);
                if (memcmp(value, half, 32) <= 0) {
                    lowS++;
                }
            }
        }
        uint8_t der[72];
        if (RevenantCKDigestSignES256(hostScalar.bytes, digest.bytes, der, sizeof der) > 8) {
            size_t firstSize = der[3];
            const uint8_t *second = der + 4 + firstSize;
            if (second[0] == 0x02 && second[1] <= 33) {
                uint8_t value[32];
                memset(value, 0, sizeof value);
                size_t skip = second[1] > 32 ? 1u : 0u;
                memcpy(value + (32 - (second[1] - skip)), second + 2 + skip, second[1] - skip);
                if (memcmp(value, half, 32) <= 0) {
                    portLowS++;
                }
            }
        }
    }
    check_named(lowS == samples, @"every signature the host makes is the low-s half",
                     [NSString stringWithFormat:@"%lu of %lu", (unsigned long)lowS, (unsigned long)samples]);
    check_named(portLowS == samples, @"and so is every signature the port makes",
                     [NSString stringWithFormat:@"%lu of %lu", (unsigned long)portLowS, (unsigned long)samples]);

    SecKeyRef portPrivatePublic = NULL, peerPrivatePublic = NULL;
    SecKeyRef portPrivate = randomKey((__bridge id)kSecAttrKeyTypeECSECPrimeRandom, &portPrivatePublic);
    SecKeyRef peerPrivate = randomKey((__bridge id)kSecAttrKeyTypeECSECPrimeRandom, &peerPrivatePublic);
    NSData *portScalar = scalarOf(portPrivate, portPrivatePublic);
    NSData *portPoint = pointOf(portPrivatePublic);
    NSData *peerScalar = scalarOf(peerPrivate, peerPrivatePublic);
    NSData *peerPoint = pointOf(peerPrivatePublic);
    check_named(portScalar.length == 32 && portPoint.length == 65 && peerScalar.length == 32 && peerPoint.length == 65,
                 @"two more P-256 pairs for the exchange", @"a key did not export what a P-256 key exports");
    if (portScalar.length == 32 && portPoint.length == 65 && peerScalar.length == 32 && peerPoint.length == 65) {
        uint8_t mine[32];
        NSData *oneScalar = opensslScalar(folder, @"one");
        NSData *onePoint = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"one.point"]];
        NSData *twoPoint = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"two.point"]];
        NSData *openssl = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"openssl.secret"]];
        check_named(oneScalar.length == 32 && twoPoint.length == 65 && openssl.length == 32,
                    @"OpenSSL's two keys and the secret it derives from them are in hand",
                    [NSString stringWithFormat:@"scalar %lu point %lu secret %lu", (unsigned long)oneScalar.length, (unsigned long)twoPoint.length, (unsigned long)openssl.length]);
        if (oneScalar.length == 32 && twoPoint.length == 65 && openssl.length == 32) {
            uint8_t theirs[32];
            uint8_t derivedPoint[65], derivedOther[65];
            check_named(RevenantCKPublicKeyES256(oneScalar.bytes, derivedPoint) == 65, @"OpenSSL's first private scalar derives a public point",
                        @"micro-ecc refused the scalar OpenSSL printed");
            check_named(onePoint.length == 65 && memcmp(derivedPoint, onePoint.bytes, 65) == 0,
                        @"and it is the point OpenSSL published for that same key, so the two files are one key",
                        [NSString stringWithFormat:@"derived %02x..%02x, published %lu bytes", derivedPoint[0], derivedPoint[64], (unsigned long)onePoint.length]);
            check_named(memcmp(derivedPoint, twoPoint.bytes, 65) != 0, @"and not the point of the other key",
                        @"the two keys have the same public point");
            revenant_check(RevenantCKSharedSecretES256(oneScalar.bytes, twoPoint.bytes, twoPoint.length, mine) == 1,
                         @"the port derives a shared secret from OpenSSL's keys", @"micro-ecc refused");
            memcpy(theirs, openssl.bytes, 32);
            check_named(memcmp(mine, theirs, 32) == 0, @"and it is the same secret OpenSSL derives, byte for byte",
                        [NSString stringWithFormat:@"port %02x.., openssl %02x..", mine[0], theirs[0]]);
            printf("openssl secret: %s\n", [[[openssl description] substringToIndex:16] UTF8String]);
        }
        revenant_check(RevenantCKSharedSecretES256(portScalar.bytes, peerPoint.bytes, peerPoint.length, mine) == 1,
                     "the port makes a shared secret with the peer's point", @"micro-ecc refused");
        CFErrorRef error = NULL;
        revenant_check(SecKeyCopyKeyExchangeResult != NULL, "the host has its own SecKeyCopyKeyExchangeResult, which is not the oracle here",
                     @"the host has no such function");
        if (error) {
            CFRelease(error);
        }
        uint8_t reverse[32];
        revenant_check(RevenantCKSharedSecretES256(peerScalar.bytes, portPoint.bytes, portPoint.length, reverse) == 1,
                     "the exchange is the same from the other side", @"micro-ecc refused");
        revenant_check(memcmp(mine, reverse, 32) == 0, @"and both sides reach one secret",
                     @"the two directions differ");
        SecKeyRef otherPrivatePublic = NULL;
        SecKeyRef otherPrivate = randomKey((__bridge id)kSecAttrKeyTypeECSECPrimeRandom, &otherPrivatePublic);
        NSData *otherPoint = pointOf(otherPrivatePublic);
        uint8_t withOther[32];
        if (otherPoint.length == 65 && RevenantCKSharedSecretES256(portScalar.bytes, otherPoint.bytes, otherPoint.length, withOther)) {
            revenant_check(memcmp(mine, withOther, 32) != 0, @"a point of another pair gives another secret",
                         @"two different pairs gave the same secret");
        }
        if (otherPrivate) {
            CFRelease(otherPrivate);
        }
        if (otherPrivatePublic) {
            CFRelease(otherPrivatePublic);
        }
    }

    printf("port: the release's own RSA key, through the same four functions\n"); fflush(stdout);
    {
        NSDictionary *attributes = @{(__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                                     (__bridge id)kSecAttrKeySizeInBits: @2048,
                                     (__bridge id)kSecAttrIsPermanent: @NO};
        CFErrorRef rsaError = NULL;
        SecKeyRef rsaPrivate = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &rsaError);
        if (rsaError) { CFRelease(rsaError); }
        SecKeyRef rsaPublic = rsaPrivate ? SecKeyCopyPublicKey(rsaPrivate) : NULL;
        check_named(rsaPrivate != NULL && rsaPublic != NULL, @"the host made an RSA key pair",
                    @"the host's SecKeyCreateRandomKey made no RSA key");
        if (rsaPrivate && rsaPublic) {
            RevenantShimMarkReleaseKey(rsaPrivate, kSecAttrKeyTypeRSA);
            RevenantShimMarkReleaseKey(rsaPublic, kSecAttrKeyTypeRSA);
            SecKeyAlgorithm rsaAlgorithm = kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
            check_named(revenantHost_SecKeyIsAlgorithmSupported(rsaPrivate, kSecKeyOperationTypeSign, rsaAlgorithm),
                        @"the port says an RSA key signs with PKCS1 v1.5 over a digest",
                        @"the port says it cannot sign an RSA key it is handed");
            check_named(!revenantHost_SecKeyIsAlgorithmSupported(rsaPrivate, kSecKeyOperationTypeKeyExchange, revenantHostECDH),
                        @"and that it cannot exchange an RSA key either, which the release has no primitive for",
                        @"the port claims an RSA exchange");
            check_named(revenantHost_SecKeyCopyKeyExchangeResult(rsaPrivate, revenantHostECDH, rsaPublic,
                                                                NULL, NULL) == NULL,
                        @"and the exchange for that RSA key answers no secret",
                        @"it answered a secret for an RSA key");
            NSData *rsaDigest = digestOf([NSData dataWithBytes:"the RSA cell of the matrix" length:19]);
            CFErrorRef rsaSignError = NULL;
            CFDataRef rsaSignature = revenantHost_SecKeyCreateSignature(rsaPrivate, rsaAlgorithm,
                                                                    (__bridge CFDataRef)rsaDigest, &rsaSignError);
            if (rsaSignError) { CFRelease(rsaSignError); }
            check_named(rsaSignature != NULL, @"and it signs an RSA key with the release's own SecKeyRawSign",
                        @"the port refused to sign an RSA key");
            if (rsaSignature) {
                NSData *made = CFBridgingRelease(rsaSignature);
                check_named(hostVerifies(rsaPublic, rsaDigest, made,
                                         kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256),
                            @"and the host's own SecKeyVerifySignature accepts that signature",
                            @"the host refused the RSA signature the port made");
                check_named(revenantHost_SecKeyVerifySignature(rsaPublic, rsaAlgorithm,
                                                            (__bridge CFDataRef)rsaDigest,
                                                            (__bridge CFDataRef)made, NULL),
                            @"and the port's own reader verifies it too",
                            @"the port refused its own RSA signature");
                uint8_t otherDigest[CC_SHA256_DIGEST_LENGTH];
                memset(otherDigest, 0x2b, sizeof otherDigest);
                check_named(!revenantHost_SecKeyVerifySignature(rsaPublic, rsaAlgorithm,
                                                             (__bridge CFDataRef)[NSData dataWithBytes:otherDigest
                                                                                              length:sizeof otherDigest],
                                                             (__bridge CFDataRef)made, NULL),
                            @"and the port answers false for that signature of another digest",
                            @"the port accepted an RSA signature of a different message");
            }
            NSDictionary *otherAttributes = @{(__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeAES,
                                             (__bridge id)kSecAttrKeySizeInBits: @128,
                                             (__bridge id)kSecAttrIsPermanent: @NO};
            CFErrorRef otherError = NULL;
            SecKeyRef otherKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)otherAttributes, &otherError);
            if (otherError) { CFRelease(otherError); }
            check_named(otherKey != NULL, @"the host made a key of a class the release cannot sign with",
                        @"the host's SecKeyCreateRandomKey made no such key");
            if (otherKey) {
                RevenantShimMarkReleaseKey(otherKey, kSecAttrKeyTypeAES);
                check_named(!revenantHost_SecKeyIsAlgorithmSupported(otherKey, kSecKeyOperationTypeSign, digestAlgorithm),
                            @"and the port says such a key signs nothing",
                            @"the port claims a signature for a key class it does not carry");
                CFErrorRef otherSignError = NULL;
                check_named(revenantHost_SecKeyCreateSignature(otherKey, digestAlgorithm,
                                                            (__bridge CFDataRef)digestOf([NSData data]), &otherSignError) == NULL,
                            @"and refuses to sign with it",
                            @"the port signed with a key of a class it does not carry");
                if (otherSignError) { CFRelease(otherSignError); }
                check_named(revenantHost_SecKeyCopyKeyExchangeResult(otherKey, revenantHostECDH, otherKey,
                                                                    NULL, NULL) == NULL,
                            @"and exchanges nothing with it",
                            @"the port answered a secret for a key class it does not carry");
                CFRelease(otherKey);
            }
            CFRelease(rsaPublic);
            CFRelease(rsaPrivate);
        }
    }

    printf("port: the port's own four functions, over the host's real P-256 key\n"); fflush(stdout);
    for (NSUInteger length = 0; length <= 130; length += 65) {
        NSMutableData *message = [NSMutableData dataWithLength:length];
        if (length > 0) {
            arc4random_buf(message.mutableBytes, length);
        }
        NSData *digest = digestOf(message);
        CFErrorRef portError = NULL;
        CFDataRef made = revenantHost_SecKeyCreateSignature(hostPrivate, digestAlgorithm, (__bridge CFDataRef)digest, &portError);
        if (portError) {
            CFRelease(portError);
        }
        check_named(made != NULL, [NSString stringWithFormat:@"the port's own SecKeyCreateSignature signs a %lu byte message", (unsigned long)length],
                    @"the port refused to sign");
        if (made) {
            NSData *signature = CFBridgingRelease(made);
            check_named(hostVerifies(hostPrivatePublic, digest, signature, digestAlgorithm),
                        [NSString stringWithFormat:@"and the host's own SecKeyVerifySignature accepts the port's signature, for a %lu byte message", (unsigned long)length],
                        @"the host refused a signature the port made");
            CFErrorRef verifyError = NULL;
            bool verified = revenantHost_SecKeyVerifySignature(hostPrivatePublic, digestAlgorithm, (__bridge CFDataRef)digest,
                                                            (__bridge CFDataRef)signature, &verifyError);
            if (verifyError) {
                CFRelease(verifyError);
            }
            check_named(verified, [NSString stringWithFormat:@"and the port's own SecKeyVerifySignature accepts it too, for a %lu byte message", (unsigned long)length],
                        @"the port refused its own signature");
            uint8_t other[CC_SHA256_DIGEST_LENGTH];
            memset(other, 0x3c, sizeof other);
            NSData *otherDigest = [NSData dataWithBytes:other length:sizeof other];
            CFErrorRef wrongError = NULL;
            bool wrong = revenantHost_SecKeyVerifySignature(hostPrivatePublic, digestAlgorithm,
                                                         (__bridge CFDataRef)otherDigest,
                                                         (__bridge CFDataRef)signature, &wrongError);
            if (wrongError) {
                CFRelease(wrongError);
            }
            check_named(!wrong, [NSString stringWithFormat:@"and answers false for a signature of another message, for a %lu byte message", (unsigned long)length],
                        @"the port accepted a signature of a different message");
        }
    }

    printf("port: the port's own key, and the curve underneath it\n"); fflush(stdout);
    NSData *oneKeyScalar = opensslScalar(folder, @"one");
    NSData *oneKeyPoint = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"one.point"]];
    NSData *twoKeyPoint = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"two.point"]];
    SecKeyRef curvePrivate = inMemoryKey(oneKeyPoint, oneKeyScalar, true);
    SecKeyRef curvePublic = curvePrivate ? SecKeyCopyPublicKey(curvePrivate) : NULL;
    SecKeyRef peerOfTwoPublic = inMemoryKey(twoKeyPoint, nil, false);
    check_named(curvePrivate != NULL && curvePublic != NULL && peerOfTwoPublic != NULL,
                @"a private key made in memory from OpenSSL's own point and scalar, and the other key's public point",
                @"the host made no key from the material");
    if (curvePrivate && curvePublic) {
        NSData *madePoint = pointOf(curvePublic);
        check_named(madePoint.length == 65 && [madePoint isEqualToData:oneKeyPoint],
                    @"and the key it made publishes OpenSSL's own point for that key",
                    [NSString stringWithFormat:@"%lu bytes", (unsigned long)madePoint.length]);
    }
    if (peerOfTwoPublic) {
        NSData *madePeer = pointOf(peerOfTwoPublic);
        check_named(madePeer.length == 65 && [madePeer isEqualToData:twoKeyPoint],
                    @"and the peer's key publishes the other point",
                    [NSString stringWithFormat:@"%lu bytes", (unsigned long)madePeer.length]);
    }
    if (curvePrivate && curvePublic && peerOfTwoPublic) {
        RevenantShimMarkPortKey(curvePrivate, oneKeyScalar.bytes, oneKeyScalar.length);
        RevenantShimMarkPortPublicKey(curvePublic);
        check_named(revenantHost_SecKeyIsAlgorithmSupported(curvePrivate, kSecKeyOperationTypeKeyExchange, revenantHostECDH),
                    @"a key of the port's own kind says it exchanges, where the release's key said it cannot",
                    @"the port refuses the exchange for a key it made");
        for (NSUInteger length = 0; length <= 130; length += 65) {
            NSMutableData *message = [NSMutableData dataWithLength:length];
            if (length > 0) {
                arc4random_buf(message.mutableBytes, length);
            }
            NSData *digest = digestOf(message);
            CFErrorRef portError = NULL;
            CFDataRef made = revenantHost_SecKeyCreateSignature(curvePrivate, digestAlgorithm,
                                                              (__bridge CFDataRef)digest, &portError);
            if (portError) {
                CFRelease(portError);
            }
            check_named(made != NULL, [NSString stringWithFormat:@"the port signs over the curve with a key of its own, for a %lu byte message", (unsigned long)length],
                        @"the port refused to sign with its own key");
            if (made) {
                NSData *signature = CFBridgingRelease(made);
                check_named(hostVerifies(curvePublic, digest, signature, digestAlgorithm),
                            [NSString stringWithFormat:@"and micro-ecc's signature verifies under the host's own SecKeyVerifySignature, for a %lu byte message", (unsigned long)length],
                            @"the host refused a signature the curve made");
                NSData *hostMade = hostSignature(curvePrivate, digest, digestAlgorithm);
                check_named(hostMade != nil, @"and the host made a signature of the same digest",
                            @"the host's SecKeyCreateSignature made nothing");
                if (hostMade) {
                    CFErrorRef verifyError = NULL;
                    bool verified = revenantHost_SecKeyVerifySignature(curvePublic, digestAlgorithm,
                                                                    (__bridge CFDataRef)digest,
                                                                    (__bridge CFDataRef)hostMade, &verifyError);
                    if (verifyError) {
                        CFRelease(verifyError);
                    }
                    check_named(verified, [NSString stringWithFormat:@"and a signature the host made verifies through the port's own reader, for a %lu byte message", (unsigned long)length],
                                @"the port's reader refused the host's signature");

                uint8_t anotherDigest[CC_SHA256_DIGEST_LENGTH];
                memset(anotherDigest, 0x5b, sizeof anotherDigest);
                CFErrorRef otherError = NULL;
                bool wrong = revenantHost_SecKeyVerifySignature(curvePublic, digestAlgorithm,
                                                             (__bridge CFDataRef)[NSData dataWithBytes:anotherDigest
                                                                                              length:sizeof anotherDigest],
                                                             (__bridge CFDataRef)hostMade, &otherError);
                if (otherError) {
                    CFRelease(otherError);
                }
                check_named(!wrong, [NSString stringWithFormat:@"and the port's own reader refuses a signature of another digest, for a %lu byte message", (unsigned long)length],
                            @"the port's reader accepted a signature of a different message");                }
            }
        }
        SecKeyAlgorithm standardECDH = (SecKeyAlgorithm)CFSTR("ECDH.standardX963");
        CFErrorRef curveError = NULL;
        CFDataRef portSecret = revenantHost_SecKeyCopyKeyExchangeResult(curvePrivate, standardECDH,
                                                                      peerOfTwoPublic, NULL, &curveError);
        if (curveError) {
            CFRelease(curveError);
        }
        check_named(portSecret != NULL, @"the port exchanges over the curve with a key of its own",
                    @"the port answered no secret for its own key");
        if (portSecret) {
            NSData *secret = CFBridgingRelease(portSecret);
            check_named(secret.length == 32, @"and the secret is the 32 bytes a P-256 agreement makes",
                        [NSString stringWithFormat:@"%lu bytes", (unsigned long)secret.length]);
            NSData *opensslSecret = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"openssl.secret"]];
            check_named(opensslSecret.length == 32, @"and OpenSSL's own derivation of these two keys is there to compare with",
                        [NSString stringWithFormat:@"%lu bytes", (unsigned long)opensslSecret.length]);
            if (secret.length == 32 && opensslSecret.length == 32) {
                check_named(memcmp(secret.bytes, opensslSecret.bytes, 32) == 0,
                            @"and the port's secret is OpenSSL's, byte for byte",
                            [NSString stringWithFormat:@"port %02x.., openssl %02x..",
                             ((const uint8_t *)secret.bytes)[0], ((const uint8_t *)opensslSecret.bytes)[0]]);
            }
        }
        CFErrorRef hashedError = NULL;
        CFDataRef hashedSecret = revenantHost_SecKeyCopyKeyExchangeResult(curvePrivate, hashedECDH,
                                                                       peerOfTwoPublic, NULL, &hashedError);
        if (hashedError) {
            CFRelease(hashedError);
        }
        NSData *opensslSecret = [NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"openssl.secret"]];
        check_named(hashedSecret != NULL && opensslSecret.length == 32, @"the digest-named exchange answers too",
                    @"the port answered no secret for ECDH.standardX963SHA256");
        if (hashedSecret && opensslSecret.length == 32) {
            NSData *hashed = CFBridgingRelease(hashedSecret);
            NSData *expected = digestOf(opensslSecret);
            check_named(hashed.length == 32 && memcmp(hashed.bytes, expected.bytes, 32) == 0,
                        @"and it is SHA-256 of OpenSSL's own secret, byte for byte",
                        [NSString stringWithFormat:@"port %02x.., sha256 %02x..",
                         ((const uint8_t *)hashed.bytes)[0], ((const uint8_t *)expected.bytes)[0]]);
        } else if (hashedSecret) {
            CFRelease(hashedSecret);
        }
        CFErrorRef refusedError = NULL;
        CFDataRef refused = revenantHost_SecKeyCopyKeyExchangeResult(hostPrivate, revenantHostECDH,
                                                                   curvePublic, NULL, &refusedError);
        check_named(refused == NULL, @"a key of the release's own kind is still refused for the same exchange",
                    @"it answered one");
        if (refused) {
            CFRelease(refused);
        }
        if (refusedError) {
            CFRelease(refusedError);
        }
        CFRelease(curvePublic);
        CFRelease(peerOfTwoPublic);
        CFRelease(curvePrivate);
    }

    check_named(revenantHost_SecKeyIsAlgorithmSupported(hostPrivate, kSecKeyOperationTypeSign, digestAlgorithm),
                @"the port says a key signs", @"the port says it cannot sign a key it is asked about");
    check_named(revenantHost_SecKeyIsAlgorithmSupported(hostPrivate, kSecKeyOperationTypeVerify, digestAlgorithm),
                @"and that it verifies", @"the port says it cannot verify");
    check_named(!revenantHost_SecKeyIsAlgorithmSupported(hostPrivate, kSecKeyOperationTypeKeyExchange,
                                                       revenantHostECDH),
                @"and that it cannot exchange, which is the measured answer for this release", @"the port claims an exchange");
    check_named(!revenantHost_SecKeyIsAlgorithmSupported(hostPrivate, kSecKeyOperationTypeEncrypt, digestAlgorithm),
                @"nor encrypt, which P-256 has no vocabulary for in Security", @"the port claims an encryption");
    CFErrorRef exchangeError = NULL;
    CFDataRef secret = revenantHost_SecKeyCopyKeyExchangeResult(hostPrivate,
                                                               revenantHostECDH,
                                                               hostPrivatePublic, NULL, &exchangeError);
    check_named(secret == NULL, @"the port's own SecKeyCopyKeyExchangeResult answers no secret", @"it answered one");
    if (secret) {
        CFRelease(secret);
    }
    check_named(exchangeError != NULL, @"with the error that says why", @"no error at all");
    if (exchangeError) {
        NSError *error = (__bridge NSError *)exchangeError;
        check_named([error.domain isEqualToString:NSOSStatusErrorDomain] && error.code == errSecParam,
                    @"which is NSOSStatusErrorDomain errSecParam", [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code]);
        check_named([error.localizedDescription rangeOfString:@"elliptic"].location != NSNotFound,
                    @"and a description that names the elliptic agreement the release lacks",
                    [NSString stringWithFormat:@"%@", error.localizedDescription]);
        CFRelease(exchangeError);
    }
    CFErrorRef nilKeyError = NULL;
    CFDataRef noKey = revenantHost_SecKeyCopyKeyExchangeResult(NULL, revenantHostECDH,
                                                             hostPrivatePublic, NULL, &nilKeyError);
    check_named(noKey == NULL, @"and a nil key is the same refusal", @"it answered one");
    if (noKey) {
        CFRelease(noKey);
    }
    if (nilKeyError) {
        CFRelease(nilKeyError);
    }

    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures == 0 ? 0 : 1;
}
