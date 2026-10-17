#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <pthread.h>

// The iOS 7.0 trust and policy accessors: what 6.1.3 answers for each of them, and what the port
// answers for the same call.
//
// EVERY RELEASE CALL BELOW IS MEASURED, not assumed. Read with tools/cache-index/first-rung.lua
// --rungs against the armv7 caches of the two releases this port supports; the presence table is in
// facts/Security/AbsentRows613.md:
//
//   SecPolicyCreateBasicX509          SecPolicy.h:167  __IPHONE_2_0   6.1.3 yes   4.3 yes
//   SecPolicyCreateSSL                SecPolicy.h:180  __IPHONE_2_0   6.1.3 yes   4.3 yes
//   SecPolicyGetTypeID                SecPolicy.h:143  __IPHONE_2_0   6.1.3 yes   4.3 yes
//   SecTrustSetAnchorCertificates     SecTrust.h:284   __IPHONE_2_0   6.1.3 yes   4.3 yes
//   SecTrustSetAnchorCertificatesOnly SecTrust.h:298   __IPHONE_2_0   6.1.3 yes   4.3 yes
//   SecTrustSetPolicies               SecTrust.h:227   __IPHONE_6_0   6.1.3 yes   4.3 NO
//   SecTrustEvaluate                  SecTrust.h:359   __IPHONE_2_0   6.1.3 yes   4.3 yes
//
// SecTrustSetPolicies is the one that shapes this file: it is 6.0, so the setter a caller reached is
// the RELEASE'S on 6.1.3 and there is no release call that reads the policies back. Which is why the
// two trust copy-accessors below report what the PORT was handed and say plainly in their effect
// fields that they cannot report what the caller set through the release's own setter - the port
// never sees that call happen. The 4.3 band, which has no setter at all, therefore gets the same
// answer as a caller who never set anything, which is right.
//
// ONE OBJECT PER RELEASE. Everything here is __IPHONE_7_0; this family's 8.0, 11.0, 12.1.1, 13.0 and
// 15.0 rows live in files of their own, which tools/release-split.lua checks.

// ---------------------------------------------------------------------------------------------
// The two holds.
//
// The POLICY hold exists because SecPolicyCreateWithProperties below is a function this port
// DEFINES. A caller that goes through it hands the port the properties and the identifier, so the port
// can hand both back: SecPolicyCopyProperties then returns the caller's own dictionary plus the OID of
// the release creator the port called. That is a round trip, not a reconstruction.
//
// The TRUST hold holds what the port's OWN setters were given. It cannot hold what a caller passed to
// the release's setters, because the port does not define them and never sees those calls; the two
// copy-accessors below are written for exactly that limit.

// There is NO trust hold, and the absence is the measurement: SecTrustSetPolicies, SecTrustSetAnchor-
// Certificates and SecTrustSetAnchorCertificatesOnly are the RELEASE'S functions on both releases, so a
// caller's set call never reaches this port and there is nothing here it could be handed. The two
// copy-accessors below are written for exactly that limit.
typedef struct CharonSecurityPolicyHeld {
    const void *policy;
    CFStringRef oid;
    CFDictionaryRef properties;
} CharonSecurityPolicyHeld;

static pthread_mutex_t CharonSecurityHoldLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableArrayRef CharonSecurityPolicyHolds;

// Keyed by the policy's VALUE and holding it borrowed: a SecPolicyRef the port did not create belongs
// to whoever made it, and comparing the pointer is the whole use.
static CharonSecurityPolicyHeld *CharonSecurityPolicyHeldFor(const void *policy)
{
    if (!CharonSecurityPolicyHolds)
        return NULL;
    for (CFIndex i = 0; i < CFArrayGetCount(CharonSecurityPolicyHolds); i++) {
        CharonSecurityPolicyHeld *held = (CharonSecurityPolicyHeld *)CFArrayGetValueAtIndex(CharonSecurityPolicyHolds, i);
        if (held->policy == policy)
            return held;
    }
    return NULL;
}

// Two kinds of list, and the difference is load-bearing. A list of CF OBJECTS takes the retaining
// callbacks, because the elements are retained for as long as the list holds them. A list of this
// file's OWN records - malloc'd structs with a CFRetain'd oid and a borrowed policy pointer - must
// NOT: kCFTypeArrayCallBacks would CFRetain a pointer that is not a CF object, and the first append
// crashes. Measured: that is exactly what the host case hit, a SIGSEGV at the first
// CharonSecurityRecordPolicy, before this line was fixed.
static CFMutableArrayRef CharonSecurityEmptyList(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
}

static CFMutableArrayRef CharonSecurityEmptyRecords(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);   // NULL callbacks: retain nothing
}

static void CharonSecurityRecordPolicy(SecPolicyRef policy, CFStringRef oid, CFDictionaryRef properties)
{
    if (!policy || !oid)
        return;
    pthread_mutex_lock(&CharonSecurityHoldLock);
    if (!CharonSecurityPolicyHolds)
        CharonSecurityPolicyHolds = CharonSecurityEmptyRecords();
    CharonSecurityPolicyHeld *held = CharonSecurityPolicyHeldFor(policy);
    if (!held && CharonSecurityPolicyHolds) {
        held = (CharonSecurityPolicyHeld *)calloc(1, sizeof(CharonSecurityPolicyHeld));
        if (held) {
            held->policy = policy;
            held->oid = (CFStringRef)CFRetain(oid);
            held->properties = properties ? (CFDictionaryRef)CFRetain(properties) : NULL;
            CFArrayAppendValue(CharonSecurityPolicyHolds, (const void *)held);
        }
    }
    pthread_mutex_unlock(&CharonSecurityHoldLock);
}

// ---------------------------------------------------------------------------------------------
// SecTrustCopyPolicies, SecTrust.h:231-239, __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_7_0).
//
// WHAT 6.1.3 ANSWERS. The release HAS the setter and has NO reader, and the part that decides this row
// is that the setter a caller reaches is the RELEASE'S SecTrustSetPolicies (iOS 6.0, exported by 6.1.3),
// so the port never sees that call happen. Nothing on 6.1.3 can report which policies a trust was
// given: no call returns them and no field of the trust exposes them.
//
// SO THE PORT ANSWERS errSecSuccess and an EMPTY array, always. THE EFFECT IS STATED because an empty
// array is a claim a caller could misread, and here it is the whole of the answer: it does NOT mean
// "this trust has no policies", it means 6.1.3 cannot be asked which policies a trust was given. A
// caller that set three policies through the release's own setter gets none of them back, while the
// evaluation is unaffected - the release resolves against the very array the caller passed. The host,
// asked the same question over the same trust, answers the caller's one policy, and that difference
// is this row's whole content: 6.1.3 has the setter and no reader, and the port does not pretend to
// have one.
OSStatus SecTrustCopyPolicies(SecTrustRef trust, CFArrayRef *policies)
{
    if (!trust || !policies)
        return errSecParam;
    CFMutableArrayRef copy = CharonSecurityEmptyList();
    if (!copy)
        return errSecAllocate;
    *policies = copy;   // +1, the caller's to release, as CF_RETURNS_RETAINED promises
    return errSecSuccess;
}

// ---------------------------------------------------------------------------------------------
// SecTrustCopyCustomAnchorCertificates, SecTrust.h:303-315, __OSX_AVAILABLE_STARTING(__MAC_10_5,
// __IPHONE_7_0).
//
// WHAT 6.1.3 ANSWERS. Both setters are iOS 2.0 and both are the RELEASE'S, so the limit is the one
// above: the port never sees the call, and no release call reads the anchors back. SecTrustCopyProperties
// does not help - it returns one dictionary per certificate in the chain, which is not the anchor set.
//
// SO THE PORT ANSWERS NULL, always, and that is the header's own answer for "no custom anchors have been
// specified" (SecTrust.h:308-311). NULL rather than an empty ARRAY on purpose: an empty array would
// claim to be a list of anchors that is empty, while NULL claims only that this call reports none, and
// the header draws exactly that distinction. A caller that set anchors through the release's own
// setter does not get them back - the host, asked the same question over the same trust, returns the
// one anchor it was given, and that difference is the row's whole content. The release still resolves
// against those anchors; only this reader cannot report them.
OSStatus SecTrustCopyCustomAnchorCertificates(SecTrustRef trust, CFArrayRef *anchors)
{
    if (!trust || !anchors)
        return errSecParam;
    *anchors = NULL;   // nothing was set through the port, which is what NULL means; see above
    return errSecSuccess;
}

// ---------------------------------------------------------------------------------------------
// SecTrustCopyResult, SecTrust.h:588-601, __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0).
//
//   359  OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)
//        API_DEPRECATED_WITH_REPLACEMENT("SecTrustEvaluateWithError", macos(10.3, 10.15), ios(2.0, 13.0), ...);
//   163  extern const CFStringRef kSecTrustEvaluationDate __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
//   169  extern const CFStringRef kSecTrustResultValue    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
//
// WHAT 6.1.3 ANSWERS: the verdict and nothing else. SecTrustEvaluate is iOS 2.0 and writes a
// SecTrustResultType, and no call on 6.1.3 reads a result DICTIONARY back - there is no stored result
// for a reader to be stale or fresh about, the same fact facts/Security/SecTrustGetTrustResult.md
// records for the accessor of that name.
//
// So this dictionary is BUILT, and it carries the two keys the release can answer and no others:
//
//   kSecTrustResultValue     the release's own SecTrustEvaluate verdict, read out of that call
//   kSecTrustEvaluationDate  the moment of that evaluation, which for this port is the moment of this
//                            call
//
// The keys SecTrust.h documents besides those two are ABSENT, and their absence is measured rather
// than assumed. The host's own dictionary over the committed fixture certificate, printed key by key,
// carries TrustResultDetails, TrustResultValue, TrustEvaluationDate and TrustEvaluationID; of those
// only TrustResultValue and TrustEvaluationDate are keys SecTrust.h declares (:163-178), and neither
// of the other two has a row in this family because no SDK header declares them. SecTrust.h:124-136
// documents every declared key as conditional ("will be present IF ...", "only valid for a revocation
// policy"), and 6.1.3 has no call reporting extended validation, an organization name or a revocation
// answer, so a caller wanting one of those gets nil for its key rather than a value this port invented.
//
// THE ONE NAMED DIFFERENCE from the host: the host's TrustResultDetails is a dictionary of
// per-certificate status codes (AnchorTrusted, StatusCodes) and 6.1.3 exposes no per-certificate status
// accessor at all, so there is nothing here that could fill it. That is stated rather than papered
// over with an empty dictionary under a key a caller would read as a real answer.
//
// The evaluation happens on THIS call, so a caller that trusted, changed a policy and asked again gets
// a fresh verdict - the same difference SecTrustGetTrustResult.md records for the result accessor of
// that name.
CFDictionaryRef SecTrustCopyResult(SecTrustRef trust)
{
    if (!trust)
        return NULL;
    SecTrustResultType verdict = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &verdict);   // the release's own, iOS 2.0
    if (status != errSecSuccess)
        return NULL;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &verdict);
    CFDateRef date = CFDateCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent());
    if (!value || !date) {
        if (value) CFRelease(value);
        if (date) CFRelease(date);
        return NULL;
    }
    const void *keys[] = {kSecTrustResultValue, kSecTrustEvaluationDate};
    const void *values[] = {value, date};
    CFDictionaryRef result = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    CFRelease(value);
    CFRelease(date);
    return result;
}

// ---------------------------------------------------------------------------------------------
// SecPolicyCopyProperties, SecPolicy.h:146-159, __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0).
//
// WHAT 6.1.3 ANSWERS. It HAS the policy object and NOT the accessor: both creators are __IPHONE_2_0
// and exported by both releases (SecPolicyCreateBasicX509 :167, SecPolicyCreateSSL :180), and
// SecPolicyGetTypeID (:143) is __IPHONE_2_0 as well - but neither release has a call that reads a
// policy's properties back, and a SecPolicyRef carries no readable state. CFEqual does not answer it
// either, and that is measured rather than assumed: on the host two separately created basic X.509
// policies compare equal (1), a basic and an SSL policy do not (0), two SSL server policies with the
// same host do (1) and two with different hosts do not (0) - so equality identifies a policy only for
// a caller prepared to build every candidate, which is a guess with extra steps.
//
// SO THE PORT ANSWERS, for a policy that came through the port's own SecPolicyCreateWithProperties,
// the OID of the creator the port called plus the keys the caller passed: a real round trip, since the
// dictionary read back is the dictionary passed with the OID added. The two OID strings are the HOST'S
// own answers for those two creators, measured on this Mac by SecPolicyCopyProperties over each - a
// basic X.509 policy answers one key, SecPolicyOid = 1.2.840.113635.100.1.2, and an SSL policy answers
// SecPolicyOid = 1.2.840.113635.100.1.3 - and kSecPolicyAppleX509Basic and kSecPolicyAppleSSL carry
// exactly those two strings already (SecurityNames70.m).
//
// FOR A POLICY THE PORT NEVER SAW - a caller that called SecPolicyCreateBasicX509 or SecPolicyCreateSSL
// directly, which is the ordinary way to make a policy on this release - this answers NULL. NULL is
// the header's own nullable result (:157-158) and the only honest answer: 6.1.3 holds no properties
// to report and the port has no record to report from. A dictionary carrying a guessed OID would be
// the thing this row must not be.
CFDictionaryRef SecPolicyCopyProperties(SecPolicyRef policyRef)
{
    if (!policyRef)
        return NULL;
    pthread_mutex_lock(&CharonSecurityHoldLock);
    CharonSecurityPolicyHeld *held = CharonSecurityPolicyHeldFor(policyRef);
    CFStringRef oid = held ? (CFStringRef)CFRetain(held->oid) : NULL;
    CFDictionaryRef properties = held && held->properties ? (CFDictionaryRef)CFRetain(held->properties) : NULL;
    pthread_mutex_unlock(&CharonSecurityHoldLock);
    if (!oid) {
        if (properties) CFRelease(properties);
        return NULL;   // a policy this port never made: 6.1.3 has no accessor and there is no record
    }
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                                              &kCFTypeDictionaryKeyCallBacks,
                                                              &kCFTypeDictionaryValueCallBacks);
    if (result) {
        // the OID first, so it is the value under kSecPolicyOid whichever order the caller's keys take
        CFDictionarySetValue(result, kSecPolicyOid, oid);
        if (properties) {
            // the caller's own keys and values, copied across as they are. kSecPolicyOid is dropped:
            // SecPolicy.h:396-398 documents it as read-only, so a caller-supplied one must not be
            // allowed to disagree with the OID of the creator the port actually called.
            CFIndex count = CFDictionaryGetCount(properties);
            const void *keys = NULL;
            const void *values = NULL;
            CFDictionaryGetKeysAndValues(properties, &keys, &values);
            for (CFIndex i = 0; i < count; i++) {
                CFTypeRef key = ((const CFTypeRef *)keys)[i];
                if (!key || CFEqual(key, kSecPolicyOid))
                    continue;
                CFDictionarySetValue(result, key, ((const CFTypeRef *)values)[i]);
            }
        }
    }
    if (properties) CFRelease(properties);
    CFRelease(oid);
    return result;
}

// ---------------------------------------------------------------------------------------------
// SecPolicyCreateWithProperties, SecPolicy.h:234-247, __OSX_AVAILABLE_STARTING(__MAC_10_9,
// __IPHONE_7_0).
//
// WHAT 6.1.3 ANSWERS: the two policies it can make and NULL for everything else. Its policy creators
// are SecPolicyCreateBasicX509 (:167, __IPHONE_2_0) and SecPolicyCreateSSL (:180, __IPHONE_2_0) - both
// exported by 6.1.3 and 4.3 - and there is no third. So this maps the identifier onto the release's own
// creator rather than building a policy of its own:
//
//   kSecPolicyAppleX509Basic -> SecPolicyCreateBasicX509(), OID kSecPolicyAppleX509Basic
//   kSecPolicyAppleSSL       -> SecPolicyCreateSSL(server, hostname), OID kSecPolicyAppleSSL
//   anything else            -> NULL, which is the header's own answer for "could not be created"
//
// `server` is the absence of kSecPolicyClient: SecPolicy.h:110-113 documents kSecPolicyClient as a flag
// that marks the evaluation as one for a client certificate, so a policy
// carrying it is a client policy and SecPolicyCreateSSL's `server` argument is false. That mapping is
// the host's too and was measured: the host's own SSL client policy answers a two-key properties
// dictionary carrying kSecPolicyClient, and its server policy without a host answers a one-key
// dictionary that does not.
//
// `hostname` is kSecPolicyName, which SecPolicy.h:111-115 documents it as either a single string or a list of strings, naming
// what must be matched in the certificate, and the first entry of the
// array is the one SecPolicyCreateSSL's single CFStringRef argument can carry.
//
// THE EFFECTS, both stated because a caller can be misled by either. The identifier: only the two
// above are created, so kSecPolicyAppleSMIME, kSecPolicyAppleEAP, kSecPolicyAppleIPsec,
// kSecPolicyAppleRevocation, kSecPolicyAppleCodeSigning and the rest answer NULL here where the host
// answers a policy - the host was asked and answered, and the host's own answer for each of them is in
// facts/Security/AbsentRows613.md; 6.1.3 has no creator to build them with, so the honest answer is
// the header's documented failure. The properties: kSecPolicyName and kSecPolicyClient are honoured,
// because they are what the release's creator takes, and kSecPolicyRevocationFlags and
// kSecPolicyTeamIdentifier are HELD and handed back by SecPolicyCopyProperties but change no
// evaluation, because 6.1.3's creator takes neither.
SecPolicyRef SecPolicyCreateWithProperties(CFTypeRef policyIdentifier, CFDictionaryRef properties)
{
    if (!policyIdentifier)
        return NULL;
    CFStringRef identifier = (CFStringRef)policyIdentifier;
    SecPolicyRef policy = NULL;
    CFStringRef oid = NULL;
    if (CFEqual(identifier, kSecPolicyAppleX509Basic)) {
        policy = SecPolicyCreateBasicX509();          // the release's own, iOS 2.0
        oid = kSecPolicyAppleX509Basic;
    } else if (CFEqual(identifier, kSecPolicyAppleSSL)) {
        Boolean server = true;
        CFTypeRef hostname = NULL;
        if (properties) {
            CFTypeRef client = CFDictionaryGetValue(properties, kSecPolicyClient);
            if (client && CFGetTypeID(client) == CFBooleanGetTypeID() && CFBooleanGetValue((CFBooleanRef)client))
                server = false;
            CFTypeRef name = CFDictionaryGetValue(properties, kSecPolicyName);
            if (name && CFGetTypeID(name) == CFArrayGetTypeID() && CFArrayGetCount((CFArrayRef)name) > 0)
                name = CFArrayGetValueAtIndex((CFArrayRef)name, 0);
            if (name && CFGetTypeID(name) == CFStringGetTypeID())
                hostname = name;
        }
        policy = SecPolicyCreateSSL(server, (CFStringRef)hostname);   // the release's own, iOS 2.0
        oid = kSecPolicyAppleSSL;
    }
    if (policy)
        CharonSecurityRecordPolicy(policy, oid, properties);
    return policy;
}