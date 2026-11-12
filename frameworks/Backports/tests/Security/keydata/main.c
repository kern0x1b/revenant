#include <CommonCrypto/CommonDigest.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <stdio.h>
#include <string.h>

#include "fixtures.h"

static CFDataRef data_of(const unsigned char *bytes, unsigned length)
{
    return CFDataCreate(kCFAllocatorDefault, bytes, (CFIndex)length);
}

static CFDataRef changed(const unsigned char *bytes, unsigned length, unsigned index)
{
    CFMutableDataRef copy = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFDataAppendBytes(copy, bytes, (CFIndex)length);
    CFDataGetMutableBytePtr(copy)[index] ^= 1;
    return copy;
}

static CFDataRef prefixed(const unsigned char *bytes, unsigned length, unsigned char prefix)
{
    CFMutableDataRef copy = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFDataAppendBytes(copy, bytes, (CFIndex)length);
    CFDataGetMutableBytePtr(copy)[0] = prefix;
    return copy;
}

static CFDataRef extended(const unsigned char *bytes, unsigned length, unsigned extra)
{
    CFMutableDataRef copy = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFDataAppendBytes(copy, bytes, (CFIndex)length);
    CFDataSetLength(copy, (CFIndex)(length + extra));
    return copy;
}

static CFDictionaryRef attributes(CFTypeRef type, CFTypeRef keyClass)
{
    const void *keys[2] = {kSecAttrKeyType, kSecAttrKeyClass};
    const void *values[2] = {type, keyClass};
    return CFDictionaryCreate(kCFAllocatorDefault, keys, values, type && keyClass ? 2 : 1, &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}

static CFDictionaryRef attributes_of_type(CFTypeRef type)
{
    const void *keys[1] = {kSecAttrKeyType};
    const void *values[1] = {type};
    return CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static CFDictionaryRef attributes_of_class(CFTypeRef keyClass)
{
    const void *keys[1] = {kSecAttrKeyClass};
    const void *values[1] = {keyClass};
    return CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static SecKeyRef make(const char *label, CFDataRef data, CFDictionaryRef dictionary)
{
    CFErrorRef error = NULL;
    SecKeyRef key = SecKeyCreateWithData(data, dictionary, &error);
    if (key) {
        CFDictionaryRef found = SecKeyCopyAttributes(key);
        CFTypeRef keyClass = found ? CFDictionaryGetValue(found, kSecAttrKeyClass) : NULL;
        CFTypeRef type = found ? CFDictionaryGetValue(found, kSecAttrKeyType) : NULL;
        printf("%s ok class=%s type=%s\n", label,
               keyClass && CFEqual(keyClass, kSecAttrKeyClassPrivate) ? "private" : keyClass && CFEqual(keyClass, kSecAttrKeyClassPublic) ? "public" : "other",
               type && CFEqual(type, kSecAttrKeyTypeRSA) ? "rsa" : type && CFEqual(type, kSecAttrKeyTypeECSECPrimeRandom) ? "ec" : "other");
        if (found)
            CFRelease(found);
    } else {
        printf("%s null error=%ld\n", label, error ? (long)CFErrorGetCode(error) : 0L);
    }
    if (error)
        CFRelease(error);
    return key;
}

static void attempt(const char *label, CFDataRef data, CFDictionaryRef dictionary)
{
    SecKeyRef key = make(label, data, dictionary);
    if (key)
        CFRelease(key);
}

static void verify(const char *label, SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef message, CFDataRef signature)
{
    CFErrorRef error = NULL;
    Boolean valid = SecKeyVerifySignature(key, algorithm, message, signature, &error);
    printf("%s verify=%d\n", label, valid ? 1 : 0);
    if (error)
        CFRelease(error);
}

static void export_equals(const char *label, SecKeyRef key, CFDataRef expected)
{
    CFErrorRef error = NULL;
    CFDataRef exported = SecKeyCopyExternalRepresentation(key, &error);
    printf("%s export equals=%d\n", label, exported && CFEqual(exported, expected) ? 1 : 0);
    if (exported)
        CFRelease(exported);
    if (error)
        CFRelease(error);
}

static void rsa_cases(void)
{
    CFDataRef publicData = data_of(rsa_public, rsa_public_length);
    CFDataRef privateData = data_of(rsa_private, rsa_private_length);
    CFDataRef otherData = data_of(rsa_other_public, rsa_other_public_length);
    CFDataRef message_data = data_of(message, message_length);
    CFDataRef signature = data_of(rsa_signature, rsa_signature_length);
    CFDictionaryRef publicRSA = attributes(kSecAttrKeyTypeRSA, kSecAttrKeyClassPublic);
    CFDictionaryRef privateRSA = attributes(kSecAttrKeyTypeRSA, kSecAttrKeyClassPrivate);

    SecKeyRef publicKey = make("rsa public", publicData, publicRSA);
    SecKeyRef privateKey = make("rsa private", privateData, privateRSA);
    SecKeyRef otherKey = make("rsa other public", otherData, publicRSA);
    attempt("rsa public with private data", privateData, publicRSA);
    attempt("rsa private with public data", publicData, privateRSA);
    CFDataRef garbage = data_of((const unsigned char *)"garbage", 7);
    attempt("rsa garbage", garbage, publicRSA);
    CFDataRef empty = data_of((const unsigned char *)"", 0);
    attempt("rsa empty", empty, publicRSA);
    CFDataRef truncated = data_of(rsa_public, rsa_public_length - 3);
    attempt("rsa truncated", truncated, publicRSA);
    CFDataRef trailing = extended(rsa_public, rsa_public_length, 1);
    SecKeyRef trailingKey = make("rsa trailing byte", trailing, publicRSA);
    CFDataRef privateTrailing = extended(rsa_private, rsa_private_length, 2);
    SecKeyRef privateTrailingKey = make("rsa private trailing", privateTrailing, privateRSA);
    CFDictionaryRef noClass = attributes_of_type(kSecAttrKeyTypeRSA);
    CFDictionaryRef noType = attributes_of_class(kSecAttrKeyClassPublic);
    CFDictionaryRef symmetric = attributes(kSecAttrKeyTypeRSA, kSecAttrKeyClassSymmetric);
    attempt("rsa no class", publicData, noClass);
    attempt("rsa no type", publicData, noType);
    attempt("rsa symmetric class", publicData, symmetric);
    CFDataRef ecData = data_of(ec_public, ec_public_length);
    attempt("rsa type with ec data", ecData, publicRSA);

    if (publicKey) {
        verify("rsa public", publicKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, message_data, signature);
        CFDataRef tampered = changed(message, message_length, 3);
        verify("rsa public tampered message", publicKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, tampered, signature);
        CFRelease(tampered);
        CFDataRef badSignature = changed(rsa_signature, rsa_signature_length, 100);
        verify("rsa public tampered signature", publicKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, message_data, badSignature);
        CFRelease(badSignature);
        export_equals("rsa public", publicKey, publicData);
        unsigned char sum[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(message, message_length, sum);
        CFDataRef digest = data_of(sum, sizeof sum);
        verify("rsa public digest", publicKey, kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256, digest, signature);
        sum[5] ^= 1;
        CFDataRef changedDigest = data_of(sum, sizeof sum);
        verify("rsa public tampered digest", publicKey, kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256, changedDigest, signature);
        CFDataRef shortDigest = data_of(sum, sizeof sum - 1);
        verify("rsa public short digest", publicKey, kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256, shortDigest, signature);
        verify("rsa public digest as message", publicKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, digest, signature);
        verify("rsa public message as digest", publicKey, kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256, message_data, signature);
        CFRelease(shortDigest);
        CFRelease(changedDigest);
        CFRelease(digest);
    }
    if (otherKey)
        verify("rsa other public", otherKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, message_data, signature);
    if (trailingKey)
        verify("rsa trailing byte", trailingKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, message_data, signature);
    if (privateKey) {
        CFErrorRef error = NULL;
        CFDataRef made = SecKeyCreateSignature(privateKey, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, message_data, &error);
        printf("rsa private sign equals openssl=%d\n", made && CFEqual(made, signature) ? 1 : 0);
        if (made)
            CFRelease(made);
        if (error)
            CFRelease(error);
        unsigned char sum[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(message, message_length, sum);
        CFDataRef digest = data_of(sum, sizeof sum);
        error = NULL;
        made = SecKeyCreateSignature(privateKey, kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256, digest, &error);
        printf("rsa private digest sign equals openssl=%d\n", made && CFEqual(made, signature) ? 1 : 0);
        if (made)
            CFRelease(made);
        if (error)
            CFRelease(error);
        CFRelease(digest);
        SecKeyRef derived = SecKeyCopyPublicKey(privateKey);
        printf("rsa private public key=%d\n", derived != NULL);
        if (derived) {
            verify("rsa derived public", derived, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256, message_data, signature);
            CFRelease(derived);
        }
        if (publicKey) {
            CFDataRef plain = data_of((const unsigned char *)"round trip", 10);
            error = NULL;
            CFDataRef sealed = SecKeyCreateEncryptedData(publicKey, kSecKeyAlgorithmRSAEncryptionPKCS1, plain, &error);
            CFDataRef opened = sealed ? SecKeyCreateDecryptedData(privateKey, kSecKeyAlgorithmRSAEncryptionPKCS1, sealed, NULL) : NULL;
            printf("rsa encrypt length=%ld decrypt equals=%d\n", sealed ? (long)CFDataGetLength(sealed) : -1L, opened && CFEqual(opened, plain) ? 1 : 0);
            if (error)
                CFRelease(error);
            if (opened)
                CFRelease(opened);
            if (sealed)
                CFRelease(sealed);
            CFRelease(plain);
        }
    }
    if (privateTrailingKey)
        CFRelease(privateTrailingKey);
    if (trailingKey)
        CFRelease(trailingKey);
    if (privateKey)
        CFRelease(privateKey);
    if (otherKey)
        CFRelease(otherKey);
    if (publicKey)
        CFRelease(publicKey);
    CFRelease(ecData);
    CFRelease(symmetric);
    CFRelease(noType);
    CFRelease(noClass);
    CFRelease(privateTrailing);
    CFRelease(trailing);
    CFRelease(truncated);
    CFRelease(empty);
    CFRelease(garbage);
    CFRelease(privateRSA);
    CFRelease(publicRSA);
    CFRelease(signature);
    CFRelease(message_data);
    CFRelease(otherData);
    CFRelease(privateData);
    CFRelease(publicData);
}

static void ec_cases(void)
{
    CFDataRef publicData = data_of(ec_public, ec_public_length);
    CFDataRef privateData = data_of(ec_private, ec_private_length);
    CFDataRef otherPublic = data_of(ec_other_public, ec_other_public_length);
    CFDataRef otherPrivate = data_of(ec_other_private, ec_other_private_length);
    CFDataRef message_data = data_of(message, message_length);
    CFDataRef signature = data_of(ec_signature, ec_signature_length);
    CFDictionaryRef publicEC = attributes(kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClassPublic);
    CFDictionaryRef privateEC = attributes(kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClassPrivate);

    SecKeyRef publicKey = make("ec public", publicData, publicEC);
    SecKeyRef privateKey = make("ec private", privateData, privateEC);
    SecKeyRef otherPublicKey = make("ec other public", otherPublic, publicEC);
    SecKeyRef otherPrivateKey = make("ec other private", otherPrivate, privateEC);
    attempt("ec private with public class", privateData, publicEC);
    attempt("ec public with private class", publicData, privateEC);
    CFDataRef offCurve = changed(ec_public, ec_public_length, 64);
    attempt("ec public off curve", offCurve, publicEC);
    CFDataRef privateOffCurve = changed(ec_private, ec_private_length, 64);
    attempt("ec private off curve point", privateOffCurve, privateEC);
    CFDataRef scalarOnly = data_of(ec_private + 65, 32);
    attempt("ec scalar only", scalarOnly, privateEC);
    CFDataRef compressed = data_of(ec_public, 33);
    attempt("ec short", compressed, publicEC);
    CFDataRef longer = extended(ec_public, ec_public_length, 1);
    attempt("ec public 66 bytes", longer, publicEC);
    CFDataRef zero = extended(ec_private, 65, 32);
    attempt("ec private zero scalar", zero, privateEC);
    CFDataRef hybridMatching = prefixed(ec_public, ec_public_length, 0x06 | (ec_public[64] & 1));
    attempt("ec public hybrid prefix of the parity", hybridMatching, publicEC);
    CFDataRef hybridOpposite = prefixed(ec_public, ec_public_length, 0x06 | ((ec_public[64] & 1) ^ 1));
    attempt("ec public hybrid prefix of the other parity", hybridOpposite, publicEC);
    CFDataRef badPrefix = prefixed(ec_private, ec_private_length, 0x03);
    attempt("ec private bad prefix", badPrefix, privateEC);
    CFDataRef rsaData = data_of(rsa_public, rsa_public_length);
    CFDictionaryRef publicRSA = attributes(kSecAttrKeyTypeRSA, kSecAttrKeyClassPublic);
    attempt("ec type with rsa data", rsaData, publicEC);
    attempt("rsa type with ec data", publicData, publicRSA);

    if (publicKey) {
        verify("ec public", publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, message_data, signature);
        CFDataRef tampered = changed(message, message_length, 3);
        verify("ec public tampered message", publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, tampered, signature);
        CFRelease(tampered);
        export_equals("ec public", publicKey, publicData);
    }
    if (otherPublicKey)
        verify("ec other public", otherPublicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, message_data, signature);
    if (privateKey) {
        CFErrorRef error = NULL;
        CFDataRef made = SecKeyCreateSignature(privateKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, message_data, &error);
        printf("ec private sign=%d\n", made != NULL);
        if (made && publicKey)
            verify("ec own signature", publicKey, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, message_data, made);
        if (made)
            CFRelease(made);
        if (error)
            CFRelease(error);
        export_equals("ec private", privateKey, privateData);
        SecKeyRef derived = SecKeyCopyPublicKey(privateKey);
        printf("ec private public key=%d\n", derived != NULL);
        if (derived) {
            export_equals("ec derived public", derived, publicData);
            CFRelease(derived);
        }
        if (otherPublicKey && otherPrivateKey && publicKey) {
            CFDictionaryRef none = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            CFDataRef forward = SecKeyCopyKeyExchangeResult(privateKey, kSecKeyAlgorithmECDHKeyExchangeStandard, otherPublicKey, none, NULL);
            CFDataRef backward = SecKeyCopyKeyExchangeResult(otherPrivateKey, kSecKeyAlgorithmECDHKeyExchangeStandard, publicKey, none, NULL);
            printf("ecdh length=%ld symmetric=%d\n", forward ? (long)CFDataGetLength(forward) : -1L, forward && backward && CFEqual(forward, backward) ? 1 : 0);
            if (forward)
                CFRelease(forward);
            if (backward)
                CFRelease(backward);
            CFRelease(none);
        }
    }
    if (otherPrivateKey)
        CFRelease(otherPrivateKey);
    if (otherPublicKey)
        CFRelease(otherPublicKey);
    if (privateKey)
        CFRelease(privateKey);
    if (publicKey)
        CFRelease(publicKey);
    CFRelease(publicRSA);
    CFRelease(rsaData);
    CFRelease(badPrefix);
    CFRelease(hybridOpposite);
    CFRelease(hybridMatching);
    CFRelease(zero);
    CFRelease(longer);
    CFRelease(compressed);
    CFRelease(scalarOnly);
    CFRelease(privateOffCurve);
    CFRelease(offCurve);
    CFRelease(privateEC);
    CFRelease(publicEC);
    CFRelease(signature);
    CFRelease(message_data);
    CFRelease(otherPrivate);
    CFRelease(otherPublic);
    CFRelease(privateData);
    CFRelease(publicData);
}

int main(int argc, char **argv)
{
    int rsa = argc > 1 && strcmp(argv[1], "rsa") == 0;
    int ec = argc > 1 && strcmp(argv[1], "ec") == 0;
    if (!rsa && !ec) {
        printf("usage: keydata rsa|ec\n");
        return 2;
    }
    if (rsa)
        rsa_cases();
    else
        ec_cases();
    return 0;
}
