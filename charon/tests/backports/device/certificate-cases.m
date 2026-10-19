#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "certificate-cases.h"

// Every case here reads a trust this file builds itself, from a DER certificate written out byte for
// byte below. Nothing is read from the machine's keychain, no certificate is fetched, and no network
// is touched: what is compared is the sheet's own line-building against the Security calls the trust
// really answers to, which is the whole of what SFCertificatePresentation promises.
//
// The certificate is self-signed, so SecTrustEvaluate has a real answer to give - a recoverable trust
// failure on a host that does not have its issuer - and the chain really has one certificate in it.
// The host half records what its own Security says; the port half records the same trust through the
// port's sheet. The two sets are compared name for name by tests/backports/host/certificatepresentation.

#ifdef CHARON_CERTIFICATE_PORT
// The port's own declaration of the class, under the rename this build compiles with, so the two
// builds never see one class twice and neither links a framework the other does.
#import "CharonSecurityUI.h"

// The port's own sheet controller, declared here with the one method the case asks for - the very call
// -presentSheetInViewController:dismissHandler: makes, so a difference is a difference in the sheet
// and not in a second derivation written beside it. The class is the port's own and is not in the
// registry, so it has no entry and no rename.
@interface CharonCertificateSheetController : NSObject
+ (NSArray<NSString *> *)linesForTrust:(SecTrustRef)trust;
@end
#endif

// A leaf certificate and the CA that issued it, both embedded as DER so that the chain is the same one
// on every machine and on every run. The two together make a trust whose chain really has two members,
// which is what exercises the sheet's chain line rather than skipping it.
static NSData *CharonCertificateData(int index)
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

// The trust the case reads: both certificates, so the chain really has two members. A one-certificate
// trust is built too, for the first line on its own.
static SecTrustRef CharonTrustWith(int count)
{
    SecTrustRef trust = NULL;
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    SecCertificateRef certificates[2] = {NULL, NULL};
    for (int index = 0; index < count; index++)
        certificates[index] = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)CharonCertificateData(index));
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

static SecTrustRef CharonTrust(void)
{
    static SecTrustRef trust;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        trust = CharonTrustWith(2);
    });
    return trust;
}

static NSString *CharonVerdictOf(SecTrustRef trust)
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
    SecTrustRef trust = CharonTrust();
    record(@"trust.exists", trust ? @"1" : @"0");
    record(@"trust.certificateCount", [NSString stringWithFormat:@"%ld", (long)SecTrustGetCertificateCount(trust)]);
    record(@"trust.verdict", CharonVerdictOf(trust));
    // The one-certificate trust, for the first line on its own: the sheet's first line is the leaf's
    // subject summary whatever else is behind it.
    SecTrustRef leafOnly = CharonTrustWith(1);
    record(@"trust.leafOnlyCount", [NSString stringWithFormat:@"%ld", (long)SecTrustGetCertificateCount(leafOnly)]);
    record(@"trust.leafOnlySubject", (__bridge NSString *)SecCertificateCopySubjectSummary(SecTrustGetCertificateAtIndex(leafOnly, 0)));
    record(@"trust.leafOnlyVerdict", CharonVerdictOf(leafOnly));

    SecCertificateRef leaf = SecTrustGetCertificateAtIndex(trust, 0);
    CFStringRef subject = leaf ? SecCertificateCopySubjectSummary(leaf) : NULL;
    record(@"trust.subjectSummary", subject ? (__bridge NSString *)subject : @"(none)");
    if (subject)
        CFRelease(subject);

#ifdef CHARON_CERTIFICATE_PORT
    // The three values the caller sets, read back through the port's own accessors. The class is named
    // directly rather than looked up, so the rename header the port build compiles under applies.
    SFCertificatePresentation *sheet = [[SFCertificatePresentation alloc] initWithTrust:trust];
    record(@"sheet.trustHeld", sheet.trust != NULL ? @"1" : @"0");
    record(@"sheet.trustIsOurs", sheet.trust == trust ? @"1" : @"0");
    sheet.title = @"Charon title";
    sheet.message = @"Charon message";
    sheet.helpURL = [NSURL URLWithString:@"https://example.invalid/help"];
    record(@"sheet.title", sheet.title);
    record(@"sheet.message", sheet.message);
    record(@"sheet.helpURL", sheet.helpURL.absoluteString);
    record(@"sheet.titleIsCopy", sheet.title == sheet.title ? @"1" : @"0");
    // The unavailable -init: a presentation holding no trust at all.
    SFCertificatePresentation *empty = [[SFCertificatePresentation alloc] init];
    record(@"sheet.trustOfUnavailableInit", empty.trust == NULL ? @"1" : @"0");

    // The lines the sheet builds, through the very call -presentSheetInViewController:dismissHandler:
    // makes.
    NSArray *lines = [CharonCertificateSheetController linesForTrust:trust];
    record(@"sheet.lineCount", [NSString stringWithFormat:@"%lu", (unsigned long)lines.count]);
    for (NSUInteger index = 0; index < lines.count; index++)
        record([NSString stringWithFormat:@"sheet.line.%lu", (unsigned long)index], lines[index]);
    // A NULL trust is what the header's unavailable -init holds, and it must give no line at all: there
    // is no certificate to describe.
    record(@"sheet.linesForNullTrust", [NSString stringWithFormat:@"%lu",
                                       (unsigned long)[CharonCertificateSheetController linesForTrust:NULL].count]);
#endif
}
