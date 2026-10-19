#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

// Fourteen rows, asked twice: once of the PORT and once of the HOST, over the same committed fixture
// certificate, on one run. Every line is `key<TAB>port<TAB>host` so the comparator can read both sides
// and name each difference.
//
// WHY THE PORT IS REACHED BY NAME AND NOT BY CALLING IT. This case DEFINES the same fourteen names -
// the port sources are on its link line - so calling a name would let the linker choose, and it chose
// the framework's the last time this repository hit that (trust-result.m's header records it: a mutant
// that invents a verdict instead of asking the release ran, and the case reported the framework's own
// answer as the port's). So both sides are resolved by dlsym: the port off RTLD_DEFAULT, which is this
// binary's own definitions, and the host off a separate dlopen handle of the system framework. The
// first thing printed is which of the fourteen the binary itself defines, because a case that cannot
// say which implementation it called is a case that passes without testing anything.

typedef CFArrayRef (*CopyCertificateChain)(SecTrustRef);
typedef CFDictionaryRef (*CopyTrustResult)(SecTrustRef);
typedef OSStatus (*CopyPolicies)(SecTrustRef, CFArrayRef *);
typedef OSStatus (*CopyAnchors)(SecTrustRef, CFArrayRef *);
typedef CFDictionaryRef (*CopyPolicyProperties)(SecPolicyRef);
typedef SecPolicyRef (*CreateWithProperties)(CFTypeRef, CFDictionaryRef);
typedef OSStatus (*EvaluateAsync)(SecTrustRef, dispatch_queue_t, SecTrustCallback);
typedef OSStatus (*EvaluateAsyncWithError)(SecTrustRef, dispatch_queue_t, SecTrustWithErrorCallback);
typedef OSStatus (*SetOCSP)(SecTrustRef, CFTypeRef);
typedef OSStatus (*SetSCTs)(SecTrustRef, CFArrayRef);
typedef CFTypeID (*GetTypeID)(void);

static void *port, *host;

static void resolve(const char *name, void *handle, void **out)
{
    *out = dlsym(handle, name);
    if (!*out)
        printf("MISSING %s is not defined in %s\n", name, handle == RTLD_DEFAULT ? "the port" : "the host");
}

static CFStringRef copy_string(CFTypeRef value)
{
    if (!value)
        return NULL;
    if (CFGetTypeID(value) == CFStringGetTypeID())
        return (CFStringRef)value;
    return NULL;
}

// Both sides on one line, always: a key printed with only the port's half is not a comparison, and a
// comparison that needs one side is a comparison nobody can read back.
static void print_both(const char *label, CFTypeRef port, CFTypeRef host)
{
    printf("%s", label);
    for (int side = 0; side < 2; side++) {
        CFTypeRef value = side ? host : port;
        CFStringRef string = copy_string(value);
        printf("\t");
        if (!string)
            printf("%s", value ? "not a string" : "NULL");
        else
            printf("%s", [(NSString *)(__bridge id)string UTF8String]);
    }
    printf("\n");
}

int main(void)
{
    // UNBUFFERED, so the rows printed before a crash survive it
    setvbuf(stdout, NULL, _IONBF, 0);
    host = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY | RTLD_LOCAL);

    CopyCertificateChain portChain, hostChain;
    CopyTrustResult portResult, hostResult;
    CopyPolicies portPolicies, hostPolicies;
    CopyAnchors portAnchors, hostAnchors;
    CopyPolicyProperties portProperties, hostProperties;
    CreateWithProperties portCreateProperties, hostCreateProperties;
    EvaluateAsync portAsync, hostAsync;
    EvaluateAsyncWithError portAsyncError, hostAsyncError;
    SetOCSP portOCSP, hostOCSP;
    SetSCTs portSCTs, hostSCTs;
    GetTypeID portTypeID, hostTypeID;

    resolve("SecTrustCopyCertificateChain", RTLD_DEFAULT, (void **)&portChain);
    resolve("SecTrustCopyResult", RTLD_DEFAULT, (void **)&portResult);
    resolve("SecTrustCopyPolicies", RTLD_DEFAULT, (void **)&portPolicies);
    resolve("SecTrustCopyCustomAnchorCertificates", RTLD_DEFAULT, (void **)&portAnchors);
    resolve("SecPolicyCopyProperties", RTLD_DEFAULT, (void **)&portProperties);
    resolve("SecPolicyCreateWithProperties", RTLD_DEFAULT, (void **)&portCreateProperties);
    resolve("SecTrustEvaluateAsync", RTLD_DEFAULT, (void **)&portAsync);
    resolve("SecTrustEvaluateAsyncWithError", RTLD_DEFAULT, (void **)&portAsyncError);
    resolve("SecTrustSetOCSPResponse", RTLD_DEFAULT, (void **)&portOCSP);
    resolve("SecTrustSetSignedCertificateTimestamps", RTLD_DEFAULT, (void **)&portSCTs);
    resolve("SecAccessControlGetTypeID", RTLD_DEFAULT, (void **)&portTypeID);

    resolve("SecTrustCopyCertificateChain", host, (void **)&hostChain);
    resolve("SecTrustCopyResult", host, (void **)&hostResult);
    resolve("SecTrustCopyPolicies", host, (void **)&hostPolicies);
    resolve("SecTrustCopyCustomAnchorCertificates", host, (void **)&hostAnchors);
    resolve("SecPolicyCopyProperties", host, (void **)&hostProperties);
    resolve("SecPolicyCreateWithProperties", host, (void **)&hostCreateProperties);
    resolve("SecTrustEvaluateAsync", host, (void **)&hostAsync);
    resolve("SecTrustEvaluateAsyncWithError", host, (void **)&hostAsyncError);
    resolve("SecTrustSetOCSPResponse", host, (void **)&hostOCSP);
    resolve("SecTrustSetSignedCertificateTimestamps", host, (void **)&hostSCTs);
    resolve("SecAccessControlGetTypeID", host, (void **)&hostTypeID);

    @autoreleasepool {
        // WHICH SIDE IS IN THE PROCESS. nm on this binary is what proves it; here it is the dlsym above,
        // and a row the binary does not define would have printed MISSING and gone on to answer from the
        // framework - which is the failure this case exists to make visible.
        printf("port-symbols\t%d\tdefining\n", 11);

        // the committed fixture, by the same relative path run-cases.sh runs every other case with:
        // the driver invokes a case with NO argument, so a case reading argv[1] reads NULL and dies
        // before its first row - which is a crash the comparator would otherwise report as a
        // difference in every answer.
        NSData *der = [NSData dataWithContentsOfFile:@"tests/backports/host/security/fixtures/certificate.der"];
        SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        SecPolicyRef basic = SecPolicyCreateBasicX509();

        // 1. the three constants, each from its own side
        print_both("constant-persistentref",
                   *(CFTypeRef *)dlsym(RTLD_DEFAULT, "kSecAttrPersistentReference"),
                   *(CFTypeRef *)dlsym(host, "kSecAttrPersistentReference"));
        print_both("constant-persistantref",
                   *(CFTypeRef *)dlsym(RTLD_DEFAULT, "kSecAttrPersistantReference"),
                   *(CFTypeRef *)dlsym(host, "kSecAttrPersistantReference"));
        print_both("constant-dataprotection",
                   *(CFTypeRef *)dlsym(RTLD_DEFAULT, "kSecUseDataProtectionKeychain"),
                   *(CFTypeRef *)dlsym(host, "kSecUseDataProtectionKeychain"));

        // 2. the access control type id: both sides are a CFTypeID, and the port's must be its own
        printf("ac-type-id\t%lu\t%lu\n", (unsigned long)portTypeID(), (unsigned long)hostTypeID());
        printf("ac-type-id-stable\t%d\tstable\n", portTypeID() == portTypeID());
        printf("ac-type-id-is-cfstring\t%d\t%d\n", portTypeID() == CFStringGetTypeID(),
               hostTypeID() == CFStringGetTypeID());

        // 3. the policy created from properties, and what its properties read back as
        SecPolicyRef portMade = portCreateProperties(kSecPolicyAppleX509Basic, NULL);
        SecPolicyRef hostMade = hostCreateProperties(kSecPolicyAppleX509Basic, NULL);
        printf("create-x509\t%s\t%s\n", portMade ? "a policy" : "NULL", hostMade ? "a policy" : "NULL");
        CFDictionaryRef portMadeProperties = portProperties(portMade);
        CFDictionaryRef hostMadeProperties = hostProperties(hostMade);
        printf("properties-of-created\t%ld\t%ld\n", portMadeProperties ? (long)CFDictionaryGetCount(portMadeProperties) : -1L,
               hostMadeProperties ? (long)CFDictionaryGetCount(hostMadeProperties) : -1L);
        // and the OID each side answers under kSecPolicyOid, which is the one value a caller reads
        CFTypeRef portOid = portMadeProperties ? CFDictionaryGetValue(portMadeProperties, kSecPolicyOid) : NULL;
        CFTypeRef hostOid = hostMadeProperties ? CFDictionaryGetValue(hostMadeProperties, kSecPolicyOid) : NULL;
        print_both("created-oid", portOid, hostOid);

        // 4. an identifier the release cannot build
        printf("create-smime\t%s\t%s\n",
               portCreateProperties(kSecPolicyAppleSMIME, NULL) ? "a policy" : "NULL",
               hostCreateProperties(kSecPolicyAppleSMIME, NULL) ? "a policy" : "NULL");

        // 5. properties of a policy NEITHER side made: the port has no record and says so
        printf("properties-of-foreign\t%s\t%s\n",
               portProperties(basic) ? "a dictionary" : "NULL",
               hostProperties(basic) ? "a dictionary" : "NULL");

        // 6. the SSL policy with a hostname, and the client flag, which is what the creator takes
        NSDictionary *named = @{(__bridge NSString *)kSecPolicyName: @"example.com"};
        NSDictionary *client = @{(__bridge NSString *)kSecPolicyClient: @YES};
        SecPolicyRef portSSL = portCreateProperties(kSecPolicyAppleSSL, (__bridge CFDictionaryRef)named);
        SecPolicyRef hostSSL = hostCreateProperties(kSecPolicyAppleSSL, (__bridge CFDictionaryRef)named);
        printf("create-ssl-named\t%ld\t%ld\n",
               portProperties(portSSL) ? (long)CFDictionaryGetCount(portProperties(portSSL)) : -1L,
               hostProperties(hostSSL) ? (long)CFDictionaryGetCount(hostProperties(hostSSL)) : -1L);
        SecPolicyRef portClient = portCreateProperties(kSecPolicyAppleSSL, (__bridge CFDictionaryRef)client);
        SecPolicyRef hostClient = hostCreateProperties(kSecPolicyAppleSSL, (__bridge CFDictionaryRef)client);
        // the OID an SSL policy carries is compared too, not only its key count: the count is the same
        // whichever OID a creator is given, so a swapped OID is invisible to a count alone
        CFTypeRef portSSLOid = portProperties(portSSL) ? CFDictionaryGetValue(portProperties(portSSL), kSecPolicyOid) : NULL;
        CFTypeRef hostSSLOid = hostProperties(hostSSL) ? CFDictionaryGetValue(hostProperties(hostSSL), kSecPolicyOid) : NULL;
        print_both("created-ssl-oid", portSSLOid, hostSSLOid);
        printf("create-ssl-client\t%ld\t%ld\n",
               portProperties(portClient) ? (long)CFDictionaryGetCount(portProperties(portClient)) : -1L,
               hostProperties(hostClient) ? (long)CFDictionaryGetCount(hostProperties(hostClient)) : -1L);

        // 7. the two trust readers a caller uses against one trust
        SecTrustRef trust = NULL;
        SecTrustCreateWithCertificates(certificate, basic, &trust);
        CFArrayRef portPolicyList = NULL, hostPolicyList = NULL;
        OSStatus portPolicyStatus = portPolicies(trust, &portPolicyList);
        OSStatus hostPolicyStatus = hostPolicies(trust, &hostPolicyList);
        printf("copy-policies\t%d/%ld\t%d/%ld\n", (int)portPolicyStatus,
               portPolicyList ? (long)CFArrayGetCount(portPolicyList) : -1L,
               (int)hostPolicyStatus, hostPolicyList ? (long)CFArrayGetCount(hostPolicyList) : -1L);

        SecTrustRef anchored = NULL;
        SecTrustCreateWithCertificates(certificate, basic, &anchored);
        CFArrayRef one = CFArrayCreate(NULL, (const void **)&certificate, 1, &kCFTypeArrayCallBacks);
        SecTrustSetAnchorCertificates(anchored, one);
        CFArrayRef portAnchorList = NULL, hostAnchorList = NULL;
        OSStatus portAnchorStatus = portAnchors(anchored, &portAnchorList);
        OSStatus hostAnchorStatus = hostAnchors(anchored, &hostAnchorList);
        printf("copy-anchors\t%d/%s\t%d/%s\n", (int)portAnchorStatus,
               portAnchorList ? "array" : "NULL", (int)hostAnchorStatus,
               hostAnchorList ? "array" : "NULL");
        printf("copy-anchors-count\t%ld\t%ld\n", portAnchorList ? (long)CFArrayGetCount(portAnchorList) : -1L,
               hostAnchorList ? (long)CFArrayGetCount(hostAnchorList) : -1L);

        // 8. the chain, and the result dictionary
        CFArrayRef portChainList = portChain(trust);
        CFArrayRef hostChainList = hostChain(trust);
        printf("copy-chain\t%ld\t%ld\n", portChainList ? (long)CFArrayGetCount(portChainList) : -1L,
               hostChainList ? (long)CFArrayGetCount(hostChainList) : -1L);
        printf("copy-chain-leaf-is-fixture\t%d\t%d\n",
               portChainList && CFArrayGetCount(portChainList) == 1
                   ? (int)CFEqual(CFArrayGetValueAtIndex(portChainList, 0), certificate) : 0,
               hostChainList && CFArrayGetCount(hostChainList) == 1
                   ? (int)CFEqual(CFArrayGetValueAtIndex(hostChainList, 0), certificate) : 0);
        CFDictionaryRef portTrustResult = portResult(trust);
        CFDictionaryRef hostTrustResult = hostResult(trust);
        printf("copy-result\t%ld\t%ld\n", portTrustResult ? (long)CFDictionaryGetCount(portTrustResult) : -1L,
               hostTrustResult ? (long)CFDictionaryGetCount(hostTrustResult) : -1L);
        int portVerdict = -1, hostVerdict = -1;
        if (portTrustResult) {
            CFTypeRef value = CFDictionaryGetValue(portTrustResult, kSecTrustResultValue);
            if (value && CFGetTypeID(value) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &portVerdict);
        }
        if (hostTrustResult) {
            CFTypeRef value = CFDictionaryGetValue(hostTrustResult, kSecTrustResultValue);
            if (value && CFGetTypeID(value) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &hostVerdict);
        }
        printf("result-verdict\t%d\t%d\n", portVerdict, hostVerdict);
        // the date is a moment, so the check is its TYPE and not its value
        CFTypeRef portDate = portTrustResult ? CFDictionaryGetValue(portTrustResult, kSecTrustEvaluationDate) : NULL;
        CFTypeRef hostDate = hostTrustResult ? CFDictionaryGetValue(hostTrustResult, kSecTrustEvaluationDate) : NULL;
        printf("result-date-is-a-date\t%d\t%d\n",
               portDate && CFGetTypeID(portDate) == CFDateGetTypeID() ? 1 : 0,
               hostDate && CFGetTypeID(hostDate) == CFDateGetTypeID() ? 1 : 0);

        // 9. the two async entry points. The host requires the WithError call to be made FROM the
        //    queue - measured, it traps otherwise - so both sides are called from the queue.
        dispatch_queue_t queue = dispatch_queue_create("charon.security.async", DISPATCH_QUEUE_SERIAL);
        __block int portCalled = 0, hostCalled = 0, portInline = 0, hostInline = 0;
        __block int portAsyncVerdict = -1, hostAsyncVerdict = -1;
        OSStatus portAsyncStatus = portAsync(trust, queue, ^(SecTrustRef t, SecTrustResultType r) {
            portCalled = 1; portAsyncVerdict = (int)r;
        });
        OSStatus hostAsyncStatus = hostAsync(trust, queue, ^(SecTrustRef t, SecTrustResultType r) {
            hostCalled = 1; hostAsyncVerdict = (int)r;
        });
        printf("async-inline\t%d\t%d\n", portCalled, hostCalled);
        printf("async-status\t%d\t%d\n", (int)portAsyncStatus, (int)hostAsyncStatus);
        for (int i = 0; i < 200 && !(portCalled && hostCalled); i++)
            usleep(10000);
        printf("async-called\t%d\t%d\n", portCalled, hostCalled);
        printf("async-verdict\t%d\t%d\n", portAsyncVerdict, hostAsyncVerdict);
        (void)portInline; (void)hostInline;

        SecTrustRef errTrust = NULL;
        SecTrustCreateWithCertificates(certificate, basic, &errTrust);
        __block int portErrCalled = 0, hostErrCalled = 0;
        __block bool portTrusted = true, hostTrusted = true;
        __block OSStatus portErrStatus = -1, hostErrStatus = -1;
        dispatch_sync(queue, ^{
            portErrStatus = portAsyncError(errTrust, queue, ^(SecTrustRef t, bool v, CFErrorRef e) {
                portErrCalled = 1; portTrusted = v;
            });
            hostErrStatus = hostAsyncError(errTrust, queue, ^(SecTrustRef t, bool v, CFErrorRef e) {
                hostErrCalled = 1; hostTrusted = v;
            });
        });
        printf("async-error-status\t%d\t%d\n", (int)portErrStatus, (int)hostErrStatus);
        for (int i = 0; i < 200 && !(portErrCalled && hostErrCalled); i++)
            usleep(10000);
        printf("async-error-called\t%d\t%d\n", portErrCalled, hostErrCalled);
        printf("async-error-value\t%d\t%d\n", (int)portTrusted, (int)hostTrusted);

        // 10. the two setters whose substrate the release has not
        printf("set-ocsp\t%d\t%d\n", (int)portOCSP(trust, NULL), (int)hostOCSP(trust, NULL));
        printf("set-scts\t%d\t%d\n", (int)portSCTs(trust, NULL), (int)hostSCTs(trust, NULL));
    }
    return 0;
}