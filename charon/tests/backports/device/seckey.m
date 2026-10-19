#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <dlfcn.h>
#import "check.h"

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static const uint8_t *der_value(const uint8_t *cursor, const uint8_t *end, uint8_t tag, size_t *length)
{
    if (cursor >= end || *cursor++ != tag || cursor >= end)
        return NULL;
    size_t value = *cursor++;
    if (value & 0x80) {
        size_t count = value & 0x7F;
        if (count == 0 || count > 4 || (size_t)(end - cursor) < count)
            return NULL;
        value = 0;
        while (count-- > 0)
            value = (value << 8) | *cursor++;
    }
    if ((size_t)(end - cursor) < value)
        return NULL;
    *length = value;
    return cursor;
}

static NSArray *der_integers(NSData *data)
{
    const uint8_t *bytes = data.bytes, *end = bytes + data.length;
    size_t length = 0;
    const uint8_t *cursor = der_value(bytes, end, 0x30, &length);
    if (!cursor || cursor + length != end)
        return nil;
    end = cursor + length;
    NSMutableArray *found = [NSMutableArray array];
    while (cursor < end) {
        size_t size = 0;
        const uint8_t *value = der_value(cursor, end, 0x02, &size);
        if (!value)
            return nil;
        [found addObject:[NSData dataWithBytes:value length:size]];
        cursor = value + size;
    }
    return found;
}

static NSString *described(CFErrorRef error)
{
    if (!error)
        return @"(no error)";
    NSError *ns = (__bridge NSError *)error;
    return [NSString stringWithFormat:@"%@ %ld %@", ns.domain, (long)ns.code, ns.userInfo[@"NSDescription"]];
}

int main(void)
{
    @autoreleasepool {
        struct { const char *name; const void *address; } carried[] = {
            {"SecKeyCreateRandomKey", (const void *)&SecKeyCreateRandomKey},
            {"SecKeyCopyPublicKey", (const void *)&SecKeyCopyPublicKey},
            {"SecKeyCreateEncryptedData", (const void *)&SecKeyCreateEncryptedData},
            {"SecKeyCreateDecryptedData", (const void *)&SecKeyCreateDecryptedData},
            {"SecKeyCopyExternalRepresentation", (const void *)&SecKeyCopyExternalRepresentation}
        };
        for (unsigned index = 0; index < sizeof carried / sizeof carried[0]; index++)
            CHECK_EQUAL(image_of(carried[index].address), @"libSecurityBackports.dylib",
                        ([NSString stringWithFormat:@"%s comes from the backports library", carried[index].name].UTF8String));

        CFErrorRef error = NULL;
        CFDictionaryRef nothing = NULL;
        charon_check(SecKeyCreateRandomKey(nothing, &error) == NULL && error != NULL,
                     "no parameters is an error, not a crash", described(error));
        if (error) { CFRelease(error); error = NULL; }

        SecKeyRef refused = SecKeyCreateRandomKey((__bridge CFDictionaryRef)@{
            (id)kSecAttrKeyType: @"not a key type", (id)kSecAttrKeySizeInBits: @2048}, &error);
        charon_check(refused == NULL && error != NULL, "a key type the release cannot make is an error",
                     described(error));
        if (refused) CFRelease(refused);
        if (error) { CFRelease(error); error = NULL; }

        SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)@{
            (id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
            (id)kSecAttrKeySizeInBits: @1024,
            (id)kSecPrivateKeyAttrs: @{(id)kSecAttrIsPermanent: @NO},
            (id)kSecPublicKeyAttrs: @{(id)kSecAttrIsPermanent: @NO}}, &error);
        charon_check(privateKey != NULL, "a 1024-bit RSA key is generated", described(error));
        if (error) { CFRelease(error); error = NULL; }
        if (!privateKey) {
            printf("%d of %d checks failed\n", charon_failures, charon_checks);
            return charon_failures;
        }

        SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
        CHECK(publicKey != NULL, "the public key comes out of the private one");
        if (publicKey)
            CHECK(SecKeyGetBlockSize(publicKey) == SecKeyGetBlockSize(privateKey),
                  "the public key has the block size of the pair");

        NSData *publicRepresentation = nil;
        if (publicKey) {
            CFDataRef external = SecKeyCopyExternalRepresentation(publicKey, &error);
            publicRepresentation = CFBridgingRelease(external);
            charon_check(publicRepresentation != nil, "the public key has an external representation", described(error));
            if (error) { CFRelease(error); error = NULL; }
            NSArray *parts = publicRepresentation ? der_integers(publicRepresentation) : nil;
            CHECK(parts.count == 2, "the public representation is a PKCS#1 RSAPublicKey of two integers");
            if (parts.count == 2) {
                NSData *modulus = parts[0], *exponent = parts[1];
                CHECK(modulus.length == 128 || modulus.length == 129, "the modulus is the 1024 bits that were asked for");
                const uint8_t *e = exponent.bytes;
                CHECK(exponent.length == 3 && e[0] == 0x01 && e[1] == 0x00 && e[2] == 0x01, "the exponent is 65537");
            }
        }

        CFDataRef privateExternal = SecKeyCopyExternalRepresentation(privateKey, &error);
        NSData *privateRepresentation = CFBridgingRelease(privateExternal);
        if (privateRepresentation) {
            charon_check(![privateRepresentation isEqual:publicRepresentation],
                         "the private key is never exported as its public half",
                         @"the private representation is the public one");
            CHECK(der_integers(privateRepresentation).count == 9,
                  "a private representation that is answered is a PKCS#1 RSAPrivateKey");
        } else {
            charon_check(error != NULL, "a private key the release cannot export is an error, not nothing",
                         described(error));
        }
        if (error) { CFRelease(error); error = NULL; }

        NSData *message = [@"charon" dataUsingEncoding:NSUTF8StringEncoding];
        if (publicKey) {
            for (NSString *name in @[@"PKCS1", @"OAEPSHA1"]) {
                SecKeyAlgorithm algorithm = [name isEqual:@"PKCS1"] ? kSecKeyAlgorithmRSAEncryptionPKCS1
                                                                    : kSecKeyAlgorithmRSAEncryptionOAEPSHA1;
                CFDataRef cipher = SecKeyCreateEncryptedData(publicKey, algorithm, (__bridge CFDataRef)message, &error);
                charon_check(cipher != NULL, [name stringByAppendingString:@" encrypts"].UTF8String, described(error));
                if (error) { CFRelease(error); error = NULL; }
                if (!cipher)
                    continue;
                CHECK(CFDataGetLength(cipher) == (CFIndex)SecKeyGetBlockSize(publicKey),
                      [name stringByAppendingString:@" fills one block"].UTF8String);
                CFDataRef plain = SecKeyCreateDecryptedData(privateKey, algorithm, cipher, &error);
                charon_check(plain != NULL && [(__bridge NSData *)plain isEqual:message],
                             [name stringByAppendingString:@" comes back the same"].UTF8String, described(error));
                if (error) { CFRelease(error); error = NULL; }
                if (plain) CFRelease(plain);
                CFRelease(cipher);
            }

            CFDataRef unsupported = SecKeyCreateEncryptedData(publicKey, kSecKeyAlgorithmRSAEncryptionOAEPSHA256,
                                                              (__bridge CFDataRef)message, &error);
            charon_check(unsupported == NULL && error != NULL,
                         "an algorithm the release cannot do is refused, not answered with another one", described(error));
            if (unsupported) CFRelease(unsupported);
            if (error) {
                NSError *ns = (__bridge NSError *)error;
                CHECK([ns.domain isEqual:NSOSStatusErrorDomain] && ns.code == errSecParam,
                      "the refusal is an OSStatus error the caller can read");
                CFRelease(error);
                error = NULL;
            }
            CFRelease(publicKey);
        }
        CFRelease(privateKey);

        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
