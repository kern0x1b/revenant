#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import "check.h"

static const unsigned char der[] = {
#include "security12-cert.inc"
};

static NSString *image_of(void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) && info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *evaluate(SecPolicyRef policy, BOOL anchor, NSTimeInterval date, bool *ok)
{
    SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)[NSData dataWithBytes:der length:sizeof der]);
    SecTrustRef trust = NULL;
    SecTrustCreateWithCertificates(certificate, policy, &trust);
    if (anchor)
        SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)@[(__bridge id)certificate]);
    SecTrustSetVerifyDate(trust, (__bridge CFDateRef)[NSDate dateWithTimeIntervalSince1970:date]);
    CFErrorRef error = (CFErrorRef)(void *)1;
    *ok = SecTrustEvaluateWithError(trust, &error);
    NSString *answer = @"";
    if (*ok) {
        CHECK(error == NULL, "success leaves the error NULL");
    } else {
        NSError *made = CFBridgingRelease(error);
        NSError *underlying = made.userInfo[NSUnderlyingErrorKey];
        answer = [NSString stringWithFormat:@"%@ %ld [%@] | %@ %ld [%@]", made.domain, (long)made.code, made.localizedDescription, underlying.domain, (long)underlying.code, underlying.localizedDescription];
    }
    CFRelease(trust);
    CFRelease(certificate);
    return answer;
}

static void expect(const char *name, SecPolicyRef policy, BOOL anchor, NSTimeInterval date, NSString *expected)
{
    bool ok = false;
    NSString *answer = evaluate(policy, anchor, date, &ok);
    CHECK_EQUAL(answer, expected, name);
    NSString *label = [NSString stringWithFormat:@"%s: the answer is the verdict", name];
    CHECK(ok == (expected.length == 0), label.UTF8String);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
#ifndef CHARON_HOST
        CHECK_EQUAL(image_of((void *)&SecTrustEvaluateWithError), @"libSecurityBackports.dylib", "SecTrustEvaluateWithError comes from the backports");
        CHECK_EQUAL(image_of((void *)&SecCertificateCopyKey), @"libSecurityBackports.dylib", "SecCertificateCopyKey comes from the backports");
        CHECK_EQUAL(image_of((void *)&SecCertificateCopySerialNumberData), @"libSecurityBackports.dylib", "SecCertificateCopySerialNumberData comes from the backports");
#endif
        const NSTimeInterval valid = 1798761600, expired = 2208988800;
        NSString *domain = @"NSOSStatusErrorDomain";
        expect("a trusted certificate with the basic policy", SecPolicyCreateBasicX509(), YES, valid, @"");
        expect("a trusted certificate with the SSL policy and its name", SecPolicyCreateSSL(true, CFSTR("charon.test")), YES, valid, @"");
        expect("an untrusted root", SecPolicyCreateBasicX509(), NO, valid,
               [domain stringByAppendingString:@" -67843 [“charon.test” certificate is not trusted] | NSOSStatusErrorDomain -67843 [Certificate 0 “charon.test” has errors: Root is not trusted;]"]);
        expect("an untrusted root with the SSL policy", SecPolicyCreateSSL(true, CFSTR("charon.test")), NO, valid,
               [domain stringByAppendingString:@" -67843 [“charon.test” certificate is not trusted] | NSOSStatusErrorDomain -67843 [Certificate 0 “charon.test” has errors: Root is not trusted;]"]);
        expect("a name that does not match", SecPolicyCreateSSL(true, CFSTR("other.test")), YES, valid,
               [domain stringByAppendingString:@" -67602 [“charon.test” certificate name does not match input] | NSOSStatusErrorDomain -67602 [Certificate 0 “charon.test” has errors: SSL hostname does not match name(s) in certificate;]"]);
        expect("an expired certificate", SecPolicyCreateBasicX509(), YES, expired,
               [domain stringByAppendingString:@" -67818 [“charon.test” certificate is expired] | NSOSStatusErrorDomain -67818 [Certificate 0 “charon.test” has errors: Certificate is not temporally valid;]"]);
        expect("a name that does not match and an expired certificate", SecPolicyCreateSSL(true, CFSTR("other.test")), YES, expired,
               [domain stringByAppendingString:@" -67602 [“charon.test” certificate name does not match input] | NSOSStatusErrorDomain -67602 [Certificate 0 “charon.test” has errors: SSL hostname does not match name(s) in certificate, Certificate is not temporally valid;]"]);
        expect("an untrusted root and a name that does not match", SecPolicyCreateSSL(true, CFSTR("other.test")), NO, valid,
               [domain stringByAppendingString:@" -67843 [“charon.test” certificate is not trusted] | NSOSStatusErrorDomain -67843 [Certificate 0 “charon.test” has errors: SSL hostname does not match name(s) in certificate, Root is not trusted;]"]);
        expect("an untrusted root, a name and the time", SecPolicyCreateSSL(true, CFSTR("other.test")), NO, expired,
               [domain stringByAppendingString:@" -67843 [“charon.test” certificate is not trusted] | NSOSStatusErrorDomain -67843 [Certificate 0 “charon.test” has errors: SSL hostname does not match name(s) in certificate, Certificate is not temporally valid, Root is not trusted;]"]);
        SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)[NSData dataWithBytes:der length:sizeof der]);
        SecTrustRef trust = NULL;
        SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust);
        CHECK(!SecTrustEvaluateWithError(trust, NULL), "an error pointer of NULL is accepted");
        CFDataRef serial = SecCertificateCopySerialNumberData(certificate, NULL);
        const uint8_t expectedSerial[] = {0x00, 0xd3, 0xce, 0x30, 0x69, 0xba, 0xbf, 0x60, 0x16};
        CHECK(serial && CFDataGetLength(serial) == sizeof expectedSerial && !memcmp(CFDataGetBytePtr(serial), expectedSerial, sizeof expectedSerial), "the serial number is the content of the integer, with its leading zero");
        CFErrorRef failure = NULL;
        CFDataRef again = SecCertificateCopySerialNumberData(certificate, &failure);
        CHECK(again && failure == NULL, "a serial number is answered without an error");
        SecKeyRef key = SecCertificateCopyKey(certificate);
        CHECK(key != NULL && SecKeyGetBlockSize(key) == 256, "the key of the certificate is a 2048 bit key");
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}
