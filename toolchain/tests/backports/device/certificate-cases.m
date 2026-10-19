#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "certificate-cases.h"

#ifdef REVENANT_CERTIFICATE_PORT
#import "RevenantSecurityUI.h"

@interface RevenantCertificateSheetController : NSObject
+ (NSArray<NSString *> *)linesForTrust:(SecTrustRef)trust;
@end
#endif

static NSData *RevenantCertificateData(int index)
{
    static const unsigned char leaf[] = {
#include "certificate-leaf.inc"
    };
    static const unsigned char issuer[] = {
#include "certificate-ca.inc"
    };
    const unsigned char *der = index ? issuer : leaf;
    size_t size = index ? sizeof(issuer) : sizeof(leaf);
    return [NSData dataWithBytesNoCopy:(void *)der length:size freeWhenDone:NO];
}

static SecTrustRef RevenantTrustWith(int count)
{
    SecTrustRef trust = NULL;
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    SecCertificateRef certificates[2] = {NULL, NULL};
    for (int index = 0; index < count; index++)
        certificates[index] = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)RevenantCertificateData(index));
    CFArrayRef array = CFArrayCreate(NULL, (const void **)certificates, (CFIndex)count, &kCFTypeArrayCallBacks);
    if (array && SecTrustCreateWithCertificates(array, policy, &trust) != errSecSuccess) {
        if (trust) {
            CFRelease(trust);
            trust = NULL;
        }
    }
    if (array)
        CFRelease(array);
    if (policy)
        CFRelease(policy);
    for (int index = 0; index < count; index++)
        if (certificates[index])
            CFRelease(certificates[index]);
    return trust;
}

static SecTrustRef RevenantTrust(void)
{
    static SecTrustRef trust;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        trust = RevenantTrustWith(2);
    });
    return trust;
}

static NSString *RevenantVerdictOf(SecTrustRef trust)
{
    SecTrustResultType result = kSecTrustResultInvalid;
    if (SecTrustEvaluate(trust, &result) != errSecSuccess)
        return @"evaluate-failed";
    switch (result) {
        case kSecTrustResultProceed:
        case kSecTrustResultUnspecified:
            return @"trusted";
        case kSecTrustResultDeny:
            return @"not-trusted";
        case kSecTrustResultRecoverableTrustFailure:
            return @"not-trusted-yet";
        default:
            return @"not-trusted";
    }
}

void certificate_run(CertificateRecorder record)
{
    SecTrustRef trust = RevenantTrust();
    record(@"trust.exists", trust ? @"1" : @"0");
    record(@"trust.certificateCount", [NSString stringWithFormat:@"%ld", (long)SecTrustGetCertificateCount(trust)]);
    record(@"trust.verdict", RevenantVerdictOf(trust));
    SecTrustRef leafOnly = RevenantTrustWith(1);
    record(@"trust.leafOnlyCount", [NSString stringWithFormat:@"%ld", (long)SecTrustGetCertificateCount(leafOnly)]);
    record(@"trust.leafOnlySubject", (__bridge NSString *)SecCertificateCopySubjectSummary(SecTrustGetCertificateAtIndex(leafOnly, 0)));
    record(@"trust.leafOnlyVerdict", RevenantVerdictOf(leafOnly));

    SecCertificateRef leaf = SecTrustGetCertificateAtIndex(trust, 0);
    CFStringRef subject = leaf ? SecCertificateCopySubjectSummary(leaf) : NULL;
    record(@"trust.subjectSummary", subject ? (__bridge NSString *)subject : @"(none)");
    if (subject)
        CFRelease(subject);

#ifdef REVENANT_CERTIFICATE_PORT
    SFCertificatePresentation *sheet = [[SFCertificatePresentation alloc] initWithTrust:trust];
    record(@"sheet.trustHeld", sheet.trust != NULL ? @"1" : @"0");
    record(@"sheet.trustIsOurs", sheet.trust == trust ? @"1" : @"0");
    sheet.title = @"Revenant title";
    sheet.message = @"Revenant message";
    sheet.helpURL = [NSURL URLWithString:@"https://example.invalid/help"];
    record(@"sheet.title", sheet.title);
    record(@"sheet.message", sheet.message);
    record(@"sheet.helpURL", sheet.helpURL.absoluteString);
    record(@"sheet.titleIsCopy", sheet.title == sheet.title ? @"1" : @"0");
    SFCertificatePresentation *empty = [[SFCertificatePresentation alloc] init];
    record(@"sheet.trustOfUnavailableInit", empty.trust == NULL ? @"1" : @"0");

    NSArray *lines = [RevenantCertificateSheetController linesForTrust:trust];
    record(@"sheet.lineCount", [NSString stringWithFormat:@"%lu", (unsigned long)lines.count]);
    for (NSUInteger index = 0; index < lines.count; index++)
        record([NSString stringWithFormat:@"sheet.line.%lu", (unsigned long)index], lines[index]);
    record(@"sheet.linesForNullTrust", [NSString stringWithFormat:@"%lu",
                                       (unsigned long)[RevenantCertificateSheetController linesForTrust:NULL].count]);
#endif
}
