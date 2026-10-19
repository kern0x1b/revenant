// The CFStringRef constants the port carries that the host's Security also exports (the "both" rows of the Security
// ledger, facts/Security and coordination/wave-2026-10-03/v-int-c-report.md). Each one is compared with the host's own
// value, read through a dlopen handle of the host's Security.framework (dlsym with that handle does not see the
// executable's own definition, so the port's value and the host's are both read). A constant is a name; its value is
// a string the host's own function answers with, so it is compared as a string, not by pointer.
#include <Security/Security.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#define CONSTANTS(X) \
    X(kSecKeyAlgorithmECDHKeyExchangeCofactor) \
    X(kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA1) \
    X(kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA224) \
    X(kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA256) \
    X(kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA384) \
    X(kSecKeyAlgorithmECDHKeyExchangeCofactorX963SHA512) \
    X(kSecKeyAlgorithmECDHKeyExchangeStandard) \
    X(kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA1) \
    X(kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA224) \
    X(kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA256) \
    X(kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA384) \
    X(kSecKeyAlgorithmECDHKeyExchangeStandardX963SHA512) \
    X(kSecKeyAlgorithmECDSASignatureDigestX962) \
    X(kSecKeyAlgorithmECDSASignatureDigestX962SHA1) \
    X(kSecKeyAlgorithmECDSASignatureDigestX962SHA224) \
    X(kSecKeyAlgorithmECDSASignatureDigestX962SHA256) \
    X(kSecKeyAlgorithmECDSASignatureDigestX962SHA384) \
    X(kSecKeyAlgorithmECDSASignatureDigestX962SHA512) \
    X(kSecKeyAlgorithmECDSASignatureMessageX962SHA1) \
    X(kSecKeyAlgorithmECDSASignatureMessageX962SHA224) \
    X(kSecKeyAlgorithmECDSASignatureMessageX962SHA256) \
    X(kSecKeyAlgorithmECDSASignatureMessageX962SHA384) \
    X(kSecKeyAlgorithmECDSASignatureMessageX962SHA512) \
    X(kSecKeyAlgorithmECDSASignatureRFC4754) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA224AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA256AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA384AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA512AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorX963SHA1AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorX963SHA224AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorX963SHA384AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionCofactorX963SHA512AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA224AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA384AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA512AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardX963SHA1AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardX963SHA224AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardX963SHA256AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardX963SHA384AESGCM) \
    X(kSecKeyAlgorithmECIESEncryptionStandardX963SHA512AESGCM) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA1) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA1AESGCM) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA224) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA224AESGCM) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA256) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA256AESGCM) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA384) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA384AESGCM) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA512) \
    X(kSecKeyAlgorithmRSAEncryptionOAEPSHA512AESGCM) \
    X(kSecKeyAlgorithmRSAEncryptionPKCS1) \
    X(kSecKeyAlgorithmRSAEncryptionRaw) \
    X(kSecKeyAlgorithmRSASignatureDigestPKCS1v15Raw) \
    X(kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA1) \
    X(kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA224) \
    X(kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256) \
    X(kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384) \
    X(kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512) \
    X(kSecKeyAlgorithmRSASignatureDigestPSSSHA1) \
    X(kSecKeyAlgorithmRSASignatureDigestPSSSHA224) \
    X(kSecKeyAlgorithmRSASignatureDigestPSSSHA256) \
    X(kSecKeyAlgorithmRSASignatureDigestPSSSHA384) \
    X(kSecKeyAlgorithmRSASignatureDigestPSSSHA512) \
    X(kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1) \
    X(kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA224) \
    X(kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256) \
    X(kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384) \
    X(kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512) \
    X(kSecKeyAlgorithmRSASignatureMessagePSSSHA1) \
    X(kSecKeyAlgorithmRSASignatureMessagePSSSHA224) \
    X(kSecKeyAlgorithmRSASignatureMessagePSSSHA256) \
    X(kSecKeyAlgorithmRSASignatureMessagePSSSHA384) \
    X(kSecKeyAlgorithmRSASignatureMessagePSSSHA512) \
    X(kSecKeyAlgorithmRSASignatureRaw) \
    X(kSecKeyKeyExchangeParameterRequestedSize) \
    X(kSecKeyKeyExchangeParameterSharedInfo) \
    X(kSecKeyAlgorithmECDSASignatureDigestRFC4754) \
    X(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA1) \
    X(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA224) \
    X(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA256) \
    X(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA384) \
    X(kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA512) \
    X(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA1) \
    X(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA224) \
    X(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA256) \
    X(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA384) \
    X(kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA512) \
    X(kSecImportToMemoryOnly)

#define DECLARE(name) extern const CFStringRef name;
CONSTANTS(DECLARE)

// the value of a CFString as bytes, for a line of output
static const char *text(CFStringRef value, char *buffer, size_t size)
{
    if (!value)
        return "NULL";
    if (!CFStringGetCString(value, buffer, (CFIndex)size, kCFStringEncodingUTF8))
        return "?";
    return buffer;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    void *host = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    int failures = 0, cases = 0;
    if (!host) {
        printf("FAIL no host Security.framework: %s\n", dlerror());
        return 1;
    }
#define COMPARE(name)                                                                                         \
    {                                                                                                         \
        const CFStringRef *theirs = (const CFStringRef *)dlsym(host, #name);                                 \
        char a[256], b[256];                                                                                  \
        cases++;                                                                                              \
        if (!theirs) {                                                                                        \
            printf("FAIL %s: the host does not export it\n", #name);                                          \
            failures++;                                                                                       \
        } else {                                                                                              \
            CFStringRef ours = name;                                                                          \
            CFStringRef host_value = *theirs;                                                                 \
            int same = ours && host_value && CFEqual(ours, host_value);                                       \
            printf("%s %s ours=\"%s\" host=\"%s\"\n", same ? "ok" : "DIFFERS", #name,                         \
                   text(ours, a, sizeof a), text(host_value, b, sizeof b));                                   \
            if (!same)                                                                                        \
                failures++;                                                                                   \
        }                                                                                                     \
    }
    CONSTANTS(COMPARE)
#undef COMPARE
    // The control: two different constants must NOT compare equal, or the comparison cannot fail.
    {
        const CFStringRef *other = (const CFStringRef *)dlsym(host, "kSecKeyAlgorithmECDHKeyExchangeStandard");
        if (other && CFEqual(kSecKeyAlgorithmECDHKeyExchangeCofactor, *other)) {
            printf("CONTROL NOT NOTICED: two different constants compare equal\n");
            failures++;
        } else {
            printf("control noticed\n");
        }
    }
    printf("constants=%d failures=%d\n", cases, failures);
    return failures ? 1 : 0;
}
