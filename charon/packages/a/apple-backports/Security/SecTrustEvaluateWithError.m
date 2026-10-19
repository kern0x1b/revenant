#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSString *charon_trust_summary(SecTrustRef trust)
{
    if (SecTrustGetCertificateCount(trust) < 1)
        return @"";
    SecCertificateRef leaf = SecTrustGetCertificateAtIndex(trust, 0);
    CFStringRef summary = leaf ? SecCertificateCopySubjectSummary(leaf) : NULL;
    return summary ? CFBridgingRelease(summary) : @"";
}

static BOOL charon_trust_has(NSArray *problems, NSString *text)
{
    for (NSDictionary *problem in problems)
        if ([problem[@"type"] isEqual:@"error"] && [problem[@"value"] isEqual:text])
            return YES;
    return NO;
}

static NSError *charon_trust_error(SecTrustRef trust, OSStatus status)
{
    NSString *summary = charon_trust_summary(trust);
    if (status != errSecSuccess)
        return [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    CFArrayRef properties = SecTrustCopyProperties(trust);
    NSArray *problems = CFBridgingRelease(properties);
    BOOL untrusted = charon_trust_has(problems, @"Root certificate is not trusted.");
    BOOL mismatch = charon_trust_has(problems, @"Hostname mismatch.");
    BOOL expired = charon_trust_has(problems, @"One or more certificates have expired or are not valid yet.");
    OSStatus code = errSecNotTrusted;
    NSString *reason = @"is not trusted";
    if (!untrusted && mismatch) {
        code = errSecHostNameMismatch;
        reason = @"name does not match input";
    } else if (!untrusted && expired) {
        code = errSecCertificateExpired;
        reason = @"is expired";
    }
    NSMutableArray *details = [NSMutableArray array];
    if (mismatch)
        [details addObject:@"SSL hostname does not match name(s) in certificate"];
    if (expired)
        [details addObject:@"Certificate is not temporally valid"];
    if (!untrusted && !mismatch && !expired)
        untrusted = YES;
    if (untrusted)
        [details addObject:@"Root is not trusted"];
    NSInteger index = untrusted ? (NSInteger)SecTrustGetCertificateCount(trust) - 1 : 0;
    NSString *detail = [NSString stringWithFormat:@"Certificate %ld “%@” has errors: %@;", (long)MAX(index, 0), summary, [details componentsJoinedByString:@", "]];
    NSError *underlying = [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: detail}];
    return [NSError errorWithDomain:NSOSStatusErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"“%@” certificate %@", summary, reason], NSUnderlyingErrorKey: underlying}];
}

bool SecTrustEvaluateWithError(SecTrustRef trust, CFErrorRef *error)
{
    SecTrustResultType result = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &result);
    if (status == errSecSuccess && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
        if (error)
            *error = NULL;
        return true;
    }
    if (error)
        *error = (CFErrorRef)CFBridgingRetain(charon_trust_error(trust, status));
    return false;
}

SecKeyRef SecCertificateCopyKey(SecCertificateRef certificate)
{
    return SecCertificateCopyPublicKey(certificate);
}
