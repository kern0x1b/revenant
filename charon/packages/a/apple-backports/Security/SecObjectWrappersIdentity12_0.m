#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>
#import <Security/SecIdentity.h>
#import <Security/SecProtocolTypes.h>
#import <CoreFoundation/CoreFoundation.h>

// The sec_identity_t family. Five rows, one type, one object.
//
// THE TYPE IS DECLARED AND THE PORT SUPPLIES THE OBJECT. SecProtocolTypes.h:42 declares
// sec_identity with SEC_OBJECT_DECL, and as the preprocessor emits it the type is a POINTER TO A
// PROTOCOL, so there is no sec_identity class to add a method to and no ivar to add to one.
//
// EVERY ONE OF THE FIVE CALLS IS NOT EXPORTED BY 6.1.3 - read from that release's own cache, the
// Security image at 0x32e79000 with 660 exports, none of _sec_identity_create,
// _sec_identity_create_with_certificates, _sec_identity_copy_ref, _sec_identity_copy_certificates_ref or
// _sec_identity_access_certificates appears. So the port supplies them; nothing is carried by the
// release. What the release DOES have is SecIdentityRef, and that is what these wrap.
//
// THE STAND-IN, and it is a STAND-IN. SecIdentityRef cannot be made on this Mac without a keychain:
// every factory in SecIdentity.h is __IPHONE_NA - SecIdentityCreateWithCertificate at :65, the
// preference, preferred and system-identity calls at :126, :150 and :174 - and SecIdentityCreate, the
// one taking a key or a certificate directly, is not declared at all. The host case therefore hands the
// wrapper an ephemeral in-memory CFTypeRef where a SecIdentityRef would go, and says so. NO KEYCHAIN IS
// TOUCHED: no SecItemAdd, no SecItemDelete, no query, no identity import, on this Mac or anywhere.
// A REAL IDENTITY IS A GUEST MEASUREMENT, and it is owed.

@interface CharonSecIdentity : NSObject <OS_sec_identity>
{
    SecIdentityRef _identity;       // NULL when the caller passed none
    CFArrayRef _certificates;       // the COPY, not an alias
}
- (instancetype)initWithIdentity:(SecIdentityRef)identity;
- (void)charonSetCertificates:(CFArrayRef)certificates;
- (CFArrayRef)charonCertificates;
@end

@implementation CharonSecIdentity
- (instancetype)initWithIdentity:(SecIdentityRef)identity
{
    self = [super init];
    if (self)
        _identity = identity ? (SecIdentityRef)CFRetain(identity) : NULL;
    return self;
}
- (void)charonSetCertificates:(CFArrayRef)certificates
{
    if (_certificates)
        CFRelease(_certificates);
    // A COPY, because the header says the certificates are copied into the object, and an alias would
    // show the caller a list that changes under it.
    _certificates = certificates ? (CFArrayRef)CFArrayCreateCopy(kCFAllocatorDefault, certificates) : NULL;
}
- (CFArrayRef)charonCertificates { return _certificates; }
- (SecIdentityRef)charonIdentity { return _identity; }
- (void)dealloc
{
    if (_identity) CFRelease(_identity);
    if (_certificates) CFRelease(_certificates);
}
@end

//   218  SEC_RETURNS_RETAINED _Nullable sec_identity_t sec_identity_create(SecIdentityRef identity)
sec_identity_t sec_identity_create(SecIdentityRef identity)
{
    return (sec_identity_t)[[CharonSecIdentity alloc] initWithIdentity:identity];
}

//   237  … sec_identity_create_with_certificates(SecIdentityRef identity, CFArrayRef certificates)
sec_identity_t sec_identity_create_with_certificates(SecIdentityRef identity, CFArrayRef certificates)
{
    CharonSecIdentity *wrapper = [[CharonSecIdentity alloc] initWithIdentity:identity];
    [wrapper charonSetCertificates:certificates];
    return (sec_identity_t)wrapper;
}

//   273  _Nullable SecIdentityRef sec_identity_copy_ref(sec_identity_t identity)
SecIdentityRef sec_identity_copy_ref(sec_identity_t identity)
{
    if (![identity isKindOfClass:CharonSecIdentity.class])
        return NULL;
    // +1 OVER THE REF THE OBJECT HOLDS: the object keeps its own, and a caller that releases the copy
    // leaves the object still holding it.
    SecIdentityRef held = [(CharonSecIdentity *)identity charonIdentity];
    return held ? (SecIdentityRef)CFRetain(held) : NULL;
}

//   288  _Nullable CFArrayRef sec_identity_copy_certificates_ref(sec_identity_t identity)
CFArrayRef sec_identity_copy_certificates_ref(sec_identity_t identity)
{
    if (![identity isKindOfClass:CharonSecIdentity.class])
        return NULL;
    CFArrayRef held = [(CharonSecIdentity *)identity charonCertificates];
    return held ? (CFArrayRef)CFRetain(held) : NULL;
}
