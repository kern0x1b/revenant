#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <Security/SecProtocolOptions.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <stdio.h>
#import <string.h>

// THE STAND-IN, and it is a STAND-IN. A real SecIdentityRef cannot be made on this Mac: every factory in
// SecIdentity.h is __IPHONE_NA on iOS - SecIdentityCreateWithCertificate at :65 and the preference,
// preferred and system-identity calls at :126, :150 and :174 - and SecIdentityCreate, the one taking a
// key or a certificate directly, is not declared at all. So the wrapper is handed an EPHEMERAL
// IN-MEMORY CFDataRef where a SecIdentityRef would go, and every measurement below is of the WRAPPER'S
// OWNERSHIP, which is the part that can be wrong. It is not a measurement of a real identity, and that
// is a GUEST MEASUREMENT and is owed.
//
// NO KEYCHAIN IS TOUCHED: no SecItemAdd, no SecItemDelete, no keychain query, no identity import, on
// this Mac or anywhere. Everything here is allocated in memory and freed by ARC.

// The two port classes are DECLARED here and IMPLEMENTED in the .m files this case links. A declaration
// in a test's own translation unit is what lets the case name the type; a second @implementation would be
// the duplicate definition, and there is none. The probes are a CATEGORY, so the real interface stays
// untouched.
@interface CharonSecIdentity : NSObject <OS_sec_identity>
- (void)charonSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)charonCertificates;
@end

@interface CharonSecProtocolLocalIdentity : NSObject <OS_sec_protocol_options>
- (sec_identity_t)charonLocalIdentity;
@end

@interface CharonSecIdentity (CharonProbe)
- (void)charonSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)charonCertificates;
@end

static int failures = 0;
static void want(const char *what, long got, long expect)
{
    printf("%s\t%ld\t%ld\n", what, got, expect);
    if (got != expect) { printf("WRONG\t%s: got %ld and the port claims %ld\n", what, got, expect); failures++; }
}

int main(void)
{
    @autoreleasepool {
        // the STAND-IN: ephemeral, in memory, and ours to release
        CFDataRef standIn = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)"stand-in", 8);

        // OWNERSHIP ROUND TRIP: create holds the ref, copy_ref answers the SAME one with +1
        sec_identity_t identity = sec_identity_create((SecIdentityRef)standIn);
        if (!identity) { printf("WRONG\tcreate: NULL for a ref it was given\n"); return 1; }
        want("create-present", 1, 1);
        //
        // THE +1 IS COUNTED, NOT INFERRED. `copy_ref` hands back the caller's OWN CFTypeRef, so the
        // one thing that can be wrong about it is the retain: with the +1, a caller that releases the
        // copy leaves the wrapper still holding one. The stand-in is a CFDataRef, so CFGetRetainCount -
        // public CoreFoundation, the same counter every ownership row here leans on - reads the count the
        // port is responsible for. Pointer equality says the ref is the same; it cannot see a missing
        // retain, and a mutation that DROPS the CFRetain leaves every other row in this file untouched.
        CFIndex beforeCopy = CFGetRetainCount(standIn);
        SecIdentityRef got = sec_identity_copy_ref(identity);
        want("copy-ref-retains", CFGetRetainCount(standIn) > beforeCopy ? 1 : 0, 1);
        if (got != (SecIdentityRef)standIn)
            printf("WRONG\tcopy_ref: the port answered a DIFFERENT ref than it was given\n"), failures++;
        else
            printf("copy-ref-same\t1\n");
        if (got) CFRelease(got);

        // THE COPY, and it is a copy: mutating the caller's array afterwards must NOT change the
        // identity's list, which is what "the header says the certificates are copied" means
        // a REAL certificate, from the committed fixture: a five-byte hand-made DER is not a certificate
        // and SecCertificateCreateWithData answers NULL for it, which is what the first version appended
        NSData *der = [NSData dataWithContentsOfFile:@"tests/backports/host/security/fixtures/certificate.der"];
        SecCertificateRef leaf = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        if (!leaf) { printf("WRONG\tfixture: no certificate from the committed DER\n"); return 1; }
        const void *keys[] = { (const void *)leaf };
        CFMutableArrayRef source = CFArrayCreateMutable(kCFAllocatorDefault, 1, &kCFTypeArrayCallBacks);
        CFArrayAppendValue(source, keys[0]);
        sec_identity_t withCerts = sec_identity_create_with_certificates((SecIdentityRef)standIn, source);
        want("certificates-copied", (long)CFArrayGetCount(sec_identity_copy_certificates_ref(withCerts)), 1);
        // now empty the CALLER's array: a copy is unaffected, an alias is not
        CFArrayRemoveAllValues(source);
        want("copy-survives-source-change",
             (long)CFArrayGetCount(sec_identity_copy_certificates_ref(withCerts)), 1);

        // ACCESS: the handler runs once per certificate and the call returns true
        __block int runs = 0;
        bool accessed = sec_identity_access_certificates(withCerts, ^(sec_certificate_t c) {
            (void)c; runs++;
        });
        want("access-true", accessed ? 1 : 0, 1);
        want("handler-runs-per-certificate", runs, 1);
        // and on an identity with NO certificates: true, having run the handler zero times
        runs = 0;
        accessed = sec_identity_access_certificates(identity, ^(sec_certificate_t c) { (void)c; runs++; });
        want("access-empty-true", accessed ? 1 : 0, 1);
        want("handler-runs-on-empty", runs, 0);

        // THE NIL IDENTITY IS REFUSED, as the header's _Nullable says
        SecIdentityRef fromNil = sec_identity_copy_ref(NULL);
        want("copy_ref-of-nil", fromNil ? 1 : 0, 0);
        if (fromNil) CFRelease(fromNil);

        // SET_LOCAL_IDENTITY, held on the options object through the port's own holder
        Class holder = NSClassFromString(@"CharonSecProtocolLocalIdentity");
        printf("holder-class\t%s\n", holder ? "found" : "MISSING");
        if (holder) {
            sec_protocol_options_t options = (sec_protocol_options_t)[[holder alloc] init];
            sec_protocol_options_set_local_identity(options, identity);
            sec_identity_t readBack = [(CharonSecProtocolLocalIdentity *)options charonLocalIdentity];
            if (readBack == identity) printf("local-identity-holds\t1\n");
            else { printf("WRONG\tlocal-identity: the port did not hold the identity it was given\n"); failures++; }
            want("local-identity-present", readBack ? 1 : 0, 1);
        }
        printf("failures\t%d\n", failures);
    }
    return failures ? 1 : 0;
}
