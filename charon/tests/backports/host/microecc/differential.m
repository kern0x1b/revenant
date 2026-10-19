#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import "check.h"
#import "CharonCKWebAuth.h"

// The port's P-256 signing and verification against the host's own Security, in both directions.
//
// The failure this exists to catch is a signature that is not a signature of the message it claims:
// micro-ecc is handed the hash and its length, and a length that is not 32 produces a signature of the
// first eight bytes of the hash, which BOTH the host's SecKeyVerifySignature and the port's own verify
// refuse - every time, with no error and no hint. The measured cause was `sizeof digest` where digest
// was a pointer.

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    charon_check(passed, [name UTF8String], detail);
}

static SecKeyRef hostPrivate = NULL, hostPublic = NULL;

// The host's P-256 key, built with a real CFDictionary: a bridge cast of a stack array is the shape
// that crashes CF, and a CFDictionary from literal keys and a boxed NSNumber is what a CFRelease of
// one of the *values* can free. Every key and value here is created and owned, and the error is a real
// CFErrorRef the caller owns.
static SecKeyRef hostMakeKey(CFErrorRef *outError)
{
    int bits = 256;
    CFNumberRef size = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bits);
    const void *keys[] = {kSecAttrKeyType, kSecAttrKeySizeInBits, kSecAttrIsPermanent};
    const void *values[] = {kSecAttrKeyTypeECSECPrimeRandom, size, kCFBooleanFalse};
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 3,
                                                    &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(size);
    if (!attributes) {
        return NULL;
    }
    SecKeyRef key = SecKeyCreateRandomKey(attributes, outError);
    CFRelease(attributes);
    return key;
}

static NSData *keyPair(uint8_t *scalar, uint8_t *point)
{
    CFErrorRef error = NULL;
    SecKeyRef privateKey = hostMakeKey(&error);
    if (error) {
        CFRelease(error);
    }
    if (!privateKey) {
        printf("the host made no P-256 key: %s\n", error ? [[(__bridge NSError *)error localizedDescription] UTF8String] : "(no error)");
        return nil;
    }
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    CFErrorRef pointError = NULL;
    CFDataRef external = publicKey ? SecKeyCopyExternalRepresentation(publicKey, &pointError) : NULL;
    if (pointError) {
        CFRelease(pointError);
    }
    NSData *pointData = external ? CFBridgingRelease(external) : nil;
    if (pointData.length != 65) {
        printf("the host's public key exports %lu bytes, not 65\n", (unsigned long)pointData.length);
        if (publicKey) {
            CFRelease(publicKey);
        }
        CFRelease(privateKey);
        return nil;
    }
    // The private key's external representation is not a shape this port guesses at: measured on the
    // host, a P-256 private key exports 97 bytes whose scalar is not the last 32. So the scalar is
    // *found* - every 32 byte window is tried as a private key and the one that derives the published
    // public point is it - the same rule the port's own extraction uses.
    NSData *scalarData = nil;
    CFErrorRef privateError = NULL;
    CFDataRef privateExternal = SecKeyCopyExternalRepresentation(privateKey, &privateError);
    if (privateError) {
        CFRelease(privateError);
    }
    if (privateExternal) {
        NSData *data = CFBridgingRelease(privateExternal);
        printf("the host's P-256 private key exports %lu bytes\n", (unsigned long)data.length);
        for (NSUInteger offset = 0; offset + 32 <= data.length; offset++) {
            uint8_t candidate[65];
            NSData *window = [data subdataWithRange:NSMakeRange(offset, 32)];
            if (CharonCKPublicKeyES256(window.bytes, candidate) == 65 &&
                memcmp(candidate, pointData.bytes, 65) == 0) {
                scalarData = window;
                printf("  its scalar is at offset %lu\n", (unsigned long)offset);
                break;
            }
        }
    }
    if (scalar && scalarData) {
        memcpy(scalar, scalarData.bytes, 32);
    }
    if (point) {
        memcpy(point, pointData.bytes, 65);
    }
    hostPrivate = privateKey;
    hostPublic = publicKey;
    return scalarData ? pointData : nil;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    BOOL mutated = argc > 1 && strcmp(argv[1], "--mutated") == 0;

    printf("probe: asking the host for a P-256 key\n"); fflush(stdout);
    uint8_t scalar[32], point[65];
    NSData *hostPoint = keyPair(scalar, point);
    printf("probe: the key is here\n"); fflush(stdout);
    if (!hostPoint) {
        printf("checks=%d failures=%d\n", charon_checks, charon_failures + 1);
        return 1;
    }
    check_named(hostPoint.length == 65, @"the host's P-256 key exports a 65 byte point", nil);
    if (hostPoint.length != 65) {
        return charon_failures == 0 ? 0 : 1;
    }
    // and the point micro-ecc would derive from the same scalar, which is what the port signs with
    uint8_t derived[65];
    check_named(CharonCKPublicKeyES256(scalar, derived) == 65, @"the scalar's public point is derived", nil);
    check_named(memcmp(derived, point, 65) == 0, @"and it is the point the host published for that key", nil);

    SecKeyAlgorithm algorithm = kSecKeyAlgorithmECDSASignatureDigestX962SHA256;
    NSUInteger portSigned = 0, hostAccepted = 0, hostRejected = 0, portVerified = 0, portRefused = 0;
    NSUInteger rounds = 24;
    for (NSUInteger round = 0; round < rounds; round++) {
        NSMutableData *message = [NSMutableData dataWithLength:round * 7];
        arc4random_buf(message.mutableBytes, message.length);
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(message.bytes, (CC_LONG)message.length, digest);

        uint8_t der[72];
        int written = CharonCKDigestSignES256(scalar, digest, der, sizeof der);
        if (mutated) {
            // the mutation: one byte of r, so the signature is of something else and every check below
            // must fail rather than quietly pass
            der[5] ^= 0x01;
        }
        if (written <= 0) {
            continue;
        }
        portSigned++;
        NSData *signature = [NSData dataWithBytes:der length:(NSUInteger)written];

        // the host judges it, with its own public key over the digest this test made
        CFErrorRef error = NULL;
        NSData *hostDigest = [NSData dataWithBytes:digest length:sizeof digest];
        BOOL hostOK = SecKeyVerifySignature(hostPublic, algorithm, (__bridge CFDataRef)hostDigest,
                                           (__bridge CFDataRef)signature, &error);
        if (error) {
            CFRelease(error);
        }
        if (hostOK) {
            hostAccepted++;
        } else {
            hostRejected++;
        }

        int verified = CharonCKDigestVerifyES256(point, 65, digest, der, (size_t)written);
        if (verified) {
            portVerified++;
        } else {
            portRefused++;
        }
    }
    NSUInteger hostMade = 0, portAccepted = 0, portRefusedTheir = 0;
    for (NSUInteger round = 0; round < rounds; round++) {
        NSMutableData *message = [NSMutableData dataWithLength:round * 5 + 1];
        arc4random_buf(message.mutableBytes, message.length);
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(message.bytes, (CC_LONG)message.length, digest);
        CFErrorRef error = NULL;
        NSData *hostDigest = [NSData dataWithBytes:digest length:sizeof digest];
        CFDataRef hostSignature = SecKeyCreateSignature(hostPrivate, algorithm, (__bridge CFDataRef)hostDigest, &error);
        if (error) {
            CFRelease(error);
        }
        if (!hostSignature) {
            continue;
        }
        hostMade++;
        NSData *theirs = CFBridgingRelease(hostSignature);
        NSData *judged = theirs;
        if (mutated) {
            NSMutableData *broken = [theirs mutableCopy];
            ((unsigned char *)broken.mutableBytes)[6] ^= 0x01;
            judged = broken;
        }
        if (CharonCKDigestVerifyES256(point, 65, digest, judged.bytes, judged.length)) {
            portAccepted++;
        } else {
            portRefusedTheir++;
        }
    }
    check_named(hostMade == rounds, @"the host signs every round", [NSString stringWithFormat:@"%lu of %lu", (unsigned long)hostMade, (unsigned long)rounds]);
    check_named(portAccepted == rounds, @"and the port accepts every signature the host made",
                [NSString stringWithFormat:@"%lu accepted, %lu refused", (unsigned long)portAccepted, (unsigned long)portRefusedTheir]);
    check_named(portSigned == rounds, @"the port signs every round", [NSString stringWithFormat:@"%lu of %lu", (unsigned long)portSigned, (unsigned long)rounds]);
    check_named(portVerified == rounds, @"and the port's own verify accepts every one of them",
                [NSString stringWithFormat:@"%lu accepted, %lu refused", (unsigned long)portVerified, (unsigned long)portRefused]);
    check_named(hostAccepted == rounds, @"and so does the host's SecKeyVerifySignature, in the port's favour",
                [NSString stringWithFormat:@"%lu accepted, %lu rejected", (unsigned long)hostAccepted, (unsigned long)hostRejected]);
    printf("port signed %lu, its own verify accepted %lu, the host accepted %lu, the host rejected %lu\n",
           (unsigned long)portSigned, (unsigned long)portVerified, (unsigned long)hostAccepted, (unsigned long)hostRejected);
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
