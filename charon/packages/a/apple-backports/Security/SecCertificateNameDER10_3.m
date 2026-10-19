#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#include <string.h>

// SecCertificateCopyNormalizedIssuerSequence and SecCertificateCopyNormalizedSubjectSequence.
//
//    135  CFDataRef SecCertificateCopyNormalizedIssuerSequence(SecCertificateRef certificate)
//         __OSX_AVAILABLE_STARTING(__MAC_10_12_4, __IPHONE_10_3);
//    145  CFDataRef SecCertificateCopyNormalizedSubjectSequence(SecCertificateRef certificate)
//         __OSX_AVAILABLE_STARTING(__MAC_10_12_4, __IPHONE_10_3);
//
// WHERE THE RELEASE'S DATA ENDS AND THE PORT'S PARSING BEGINS, which is the line this file is written on:
//
//   the release ends at SecCertificateCopyData (__IPHONE_2_0, SecCertificate.h:86), which hands over the
//   certificate's DER - the whole structure, the tbsCertificate inside it and the issuer and subject
//   Names among its fields. The port parses that DER and gives back the Name's own TLV.
//
// So this is NOT a reimplementation of anything the release has: there is no release call that returns a
// Name. It is a bounded reader over bytes the release provides, and every offset below is FOUND BY
// WALKING the structure, never hard-coded - a certificate of another length, key or issuer walks the
// same way because nothing here knows a position in advance.
//
// X.509, as RFC 5280 4.1 writes it:
//
//   Certificate  ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
//   TBSCertificate ::= SEQUENCE {
//        version         [0] EXPLICIT Version DEFAULT v1,
//        serialNumber        CertificateSerialNumber,
//        signature           AlgorithmIdentifier,
//        issuer              Name,
//        validity            Validity,
//        subject             Name, ... }
//
// so the walk is: SEQUENCE, SEQUENCE, step over [0] if it is there, INTEGER, SEQUENCE, and the Name is
// next. The two functions differ only in which of the two Names they stop at.

// --- the reader, and nothing in it that knows a certificate ---
bool CharonCertificateReadTLV(const uint8_t *bytes, size_t length, size_t at, uint8_t *tag,
                                    size_t *content, size_t *next, size_t limit)
{
    if (at + 2 > limit || limit > length)
        return false;
    uint8_t identifier = bytes[at];
    size_t cursor = at + 1;
    size_t size = bytes[cursor++];
    if ((size & 0x80) != 0) {                    // long form: low bits are the count of length bytes
        size_t count = size & 0x7f;
        if (count == 0 || count > 4 || cursor + count > limit)
            return false;                         // indefinite length is DER-illegal, and 0 means it
        size = 0;
        for (size_t i = 0; i < count; i++)
            size = (size << 8) | bytes[cursor++];
    }
    if (cursor + size > limit)
        return false;                             // a length that runs past what was handed over
    *tag = identifier;
    *content = cursor;
    *next = cursor + size;
    return true;
}

bool CharonCertificateNameTLV(const uint8_t *bytes, size_t length, bool wantSubject,
                                    size_t *outStart, size_t *outEnd)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = 0;
    // THE CURSOR IS ALWAYS `next`, NEVER `content`: a TLV's content is where its bytes begin, and the
    // field after it begins where the whole TLV ends. Stepping by `content` lands inside the field just
    // read, which is a place the structure never describes.
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;                             // the Certificate SEQUENCE
    at = content;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;                             // tbsCertificate
    at = content;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length))
        return false;                             // the first tbsCertificate field
    at = content;
    if (tag == 0xa0) {                            // the [0] EXPLICIT version, present or not
        if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length))
            return false;
        at = next;                                // the version's own TLV ended here
    }
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x02)
        return false;                             // serialNumber, an INTEGER
    at = next;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;                             // signature, an AlgorithmIdentifier SEQUENCE
    at = next;
    *outStart = at;                               // the issuer Name's OWN first byte, tag included
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;                             // issuer, a Name
    *outEnd = next;
    if (!wantSubject)
        return true;
    at = next;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;                             // validity
    at = next;
    *outStart = at;                               // the subject Name's own first byte
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;                             // subject, a Name
    *outEnd = next;
    return true;
}

static CFDataRef CharonCertificateCopyName(SecCertificateRef certificate, bool wantSubject)
{
    if (!certificate)
        return NULL;
    CFDataRef der = SecCertificateCopyData(certificate);   // the release's own, iOS 2.0
    if (!der)
        return NULL;
    size_t length = (size_t)CFDataGetLength(der);
    const uint8_t *bytes = (const uint8_t *)CFDataGetBytePtr(der);
    size_t start = 0, end = 0;
    // A NAME IS ITS OWN TLV, TAG AND LENGTH INCLUDED - and that is not an assumption, it is what the
    // host's own accessors returned: 68 bytes for a Name whose content is 66, so the two header bytes
    // are part of the answer. The slice therefore runs from the Name's own first byte to where its TLV
    // ends, and it is the release's own bytes either way, with nothing re-encoded.
    bool found = length && bytes && CharonCertificateNameTLV(bytes, length, wantSubject, &start, &end);
    // THE COPY IS TAKEN BEFORE THE DER IS RELEASED, because `bytes` points INTO the release's own
    // CFDataRef and not into a buffer of its own: releasing first and copying after reads freed memory.
    // The length was right and the bytes were zeros, which is the shape that failure takes - a correct
    // length and content that is gone.
    CFDataRef name = (found && end > start)
        ? CFDataCreate(kCFAllocatorDefault, bytes + start, (CFIndex)(end - start))
        : NULL;                                  // malformed input is NULL, and says nothing else
    CFRelease(der);
    return name;
}

CFDataRef SecCertificateCopyNormalizedIssuerSequence(SecCertificateRef certificate)
{
    return CharonCertificateCopyName(certificate, false);
}

CFDataRef SecCertificateCopyNormalizedSubjectSequence(SecCertificateRef certificate)
{
    return CharonCertificateCopyName(certificate, true);
}

// --- the two field accessors, on the same walk ---
//
//    114  OSStatus SecCertificateCopyCommonName(SecCertificateRef certificate,
//                                                CFStringRef * __nonnull CF_RETURNS_RETAINED)
//         __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_10_3);
//    125  OSStatus SecCertificateCopyEmailAddresses(SecCertificateRef certificate,
//                                                   CFArrayRef * __nonnull CF_RETURNS_RETAINED)
//         __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_10_3);
//
// THE OIDs, and every one of them is located BY ITS OWN ENCODED BYTES rather than by a position:
//
//    2.5.4.3                commonName       06 03 55 04 03
//    1.2.840.113549.1.9.1   emailAddress     06 09 2A 86 48 86 F7 0D 01 09 01   (a subject attribute)
//    2.5.29.17              subjectAltName   06 03 55 1D 11                     (an extension)
//
// and inside the extension the rfc822Name is GeneralName's [1] IMPLICIT IA5String, so the tag is 0x81 -
// a one-byte tag, which is why a reader that only understood low-tag-number forms would miss it.

// A Name is RDNSequence ::= SEQUENCE OF RelativeDistinguishedName, and an RDN is a SET OF
// AttributeTypeAndValue ::= SEQUENCE { type OID, value ANY }. So the walk into a Name is a nested one and
// every level is found by its tag.
static bool CharonCertificateOIDIs(const uint8_t *bytes, size_t content, size_t size,
                                  const uint8_t *oid, size_t oidSize)
{
    return size == oidSize && memcmp(bytes + content, oid, oidSize) == 0;
}

static const uint8_t CharonOIDCommonName[] = {0x55, 0x04, 0x03};
static const uint8_t CharonOIDEmailAddress[] = {0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01};
static const uint8_t CharonOIDSubjectAltName[] = {0x55, 0x1D, 0x11};

// A string value out of the DER, and the tag says which encoding it is - DER does not leave it to be
// guessed, and a UTF8String read as Latin-1 is a different name.
static CFStringRef CharonCertificateStringValue(const uint8_t *bytes, uint8_t tag, size_t content, size_t size)
{
    CFStringEncoding encoding;
    if (tag == 0x0c)                                 // UTF8String
        encoding = kCFStringEncodingUTF8;
    else if (tag == 0x13)                            // PrintableString
        encoding = kCFStringEncodingASCII;
    else if (tag == 0x16)                            // IA5String, which is ASCII
        encoding = kCFStringEncodingASCII;
    else if (tag == 0x1e)                            // BMPString, UTF-16BE
        encoding = kCFStringEncodingUTF16BE;
    else
        return NULL;                                 // a string type this port does not claim to read
    if (size == 0)
        return NULL;
    return CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)bytes + content, (CFIndex)size,
                                   encoding, false);
}

// Walks the RDNs of the Name at [start, end) and hands every matching value to `visit`, which is how one
// walk serves both the first-match (the common name) and the collect-all (the addresses) case.
typedef void (*CharonCertificateFieldVisitor)(CFStringRef value, void *context);

static void CharonCertificateVisitNameFields(const uint8_t *bytes, size_t start, size_t end,
                                            const uint8_t *wanted, size_t wantedSize,
                                            CharonCertificateFieldVisitor visit, void *context)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = start;
    // [start, end) IS THE NAME'S OWN TLV, so the walk begins at its CONTENT - where the RDN SETs are -
    // and not at the TLV, whose tag is the RDNSequence SEQUENCE and not an RDN at all.
    if (!CharonCertificateReadTLV(bytes, end, at, &tag, &content, &next, end) || tag != 0x30)
        return;
    at = content;
    while (at < end && CharonCertificateReadTLV(bytes, end, at, &tag, &content, &next, end)) {
        if (tag != 0x31) {                           // an RDN is a SET
            at = next;
            continue;
        }
        size_t setAt = content;
        while (setAt < end && CharonCertificateReadTLV(bytes, end, setAt, &tag, &content, &next, end)) {
            if (tag != 0x30) {                       // an AttributeTypeAndValue is a SEQUENCE
                setAt = next;
                continue;
            }
            uint8_t typeTag = 0;
            uint8_t valueTag = 0;
            size_t atv = content, typeContent = 0, typeNext = 0, valueContent = 0, valueNext = 0;
            if (!CharonCertificateReadTLV(bytes, end, atv, &typeTag, &typeContent, &typeNext, end))
                break;
            if (typeTag != 0x06) {                   // the type is an OID
                setAt = next;
                continue;
            }
            if (!CharonCertificateReadTLV(bytes, end, typeNext, &valueTag, &valueContent, &valueNext, end))
                break;
            if (CharonCertificateOIDIs(bytes, typeContent, typeNext - typeContent, wanted, wantedSize)) {
                CFStringRef value = CharonCertificateStringValue(bytes, valueTag, valueContent,
                                                                 valueNext - valueContent);
                if (value) {
                    visit(value, context);
                    CFRelease(value);
                }
            }
            atv = valueNext;                         // an AttributeTypeAndValue holds one pair
            (void)atv;
            setAt = next;
            break;                                   // one attribute per RDN is what is walked
        }
        at = next;
    }
}

typedef struct { CFStringRef first; } CharonFirstMatch;
static void CharonKeepFirst(CFStringRef value, void *context)
{
    CharonFirstMatch *match = (CharonFirstMatch *)context;
    if (!match->first)
        match->first = (CFStringRef)CFRetain(value);   // the FIRST one, which is what the header means
}

typedef struct { CFMutableArrayRef addresses; } CharonAllMatches;
static void CharonKeepAll(CFStringRef value, void *context)
{
    CFArrayAppendValue(((CharonAllMatches *)context)->addresses, value);
}

OSStatus SecCertificateCopyCommonName(SecCertificateRef certificate, CFStringRef *name)
{
    if (!certificate || !name)
        return errSecParam;
    *name = NULL;
    CFDataRef der = SecCertificateCopyData(certificate);
    if (!der)
        return errSecInternalComponent;   // SecBase.h:261 - there is no errSecInternal
    size_t length = (size_t)CFDataGetLength(der);
    const uint8_t *bytes = (const uint8_t *)CFDataGetBytePtr(der);
    size_t start = 0, end = 0;
    CharonFirstMatch match = {NULL};
    if (length && bytes && CharonCertificateNameTLV(bytes, length, true, &start, &end))
        // the SUBJECT's Name: a common name is a subject attribute, and an issuer's CN is not this
        CharonCertificateVisitNameFields(bytes, start, end, CharonOIDCommonName,
                                         sizeof CharonOIDCommonName, CharonKeepFirst, &match);
    CFRelease(der);
    if (!match.first)
        return errSecItemNotFound;                   // no CN is a fact about the certificate, not a fault
    *name = match.first;                             // +1, as the header's CF_RETURNS_RETAINED says
    return errSecSuccess;
}

// The addresses come from TWO places in a certificate, and both are read: the subject's own emailAddress
// attribute, and the rfc822Name inside the subjectAltName extension.
static bool CharonCertificateSANs(const uint8_t *bytes, size_t length, CharonCertificateFieldVisitor visit,
                                  void *context)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = 0;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    if (!CharonCertificateReadTLV(bytes, length, content, &tag, &content, &next, length) || tag != 0x30)
        return false;                                 // tbsCertificate
    at = content;
    // step to the [3] extensions, which sits after subjectUniqueID [1] and issuerUniqueID [2], so every
    // optional field between here and it is stepped over by tag rather than counted
    while (at < length && CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length)) {
        if (tag == 0xa3) {                           // [3] EXPLICIT Extensions
            // [3] IS EXPLICIT AND IT WRAPS A SEQUENCE: Extensions ::= SEQUENCE OF Extension, so the
            // wrapper's content begins with that SEQUENCE and the extensions are inside it. Taking the
            // wrapper's content as the first extension reads the SEQUENCE OF as though it were an
            // Extension, and then its first child is looked for as an OID and is not one.
            size_t wrapper = 0, wrapperEnd = 0, listContent = 0, listNext = 0;
            if (!CharonCertificateReadTLV(bytes, length, content, &tag, &listContent, &listNext, length)
                || tag != 0x30)
                return false;
            (void)wrapper;
            (void)wrapperEnd;
            size_t exts = listContent, extsEnd = listNext;
            while (exts < extsEnd && CharonCertificateReadTLV(bytes, extsEnd, exts, &tag, &content, &next, extsEnd)) {
                if (tag != 0x30) {                   // an Extension is a SEQUENCE
                    exts = next;
                    continue;
                }
                uint8_t extTag = 0, valTag = 0;
                size_t at2 = content, oidContent = 0, oidNext = 0, valContent = 0, valNext = 0;
                if (!CharonCertificateReadTLV(bytes, length, at2, &extTag, &oidContent, &oidNext, length))
                    break;
                if (extTag != 0x06) {
                    exts = next;
                    continue;
                }
                if (!CharonCertificateReadTLV(bytes, length, oidNext, &valTag, &valContent, &valNext, length))
                    break;
                if (tag == 0x01) {                    // the extnValue's `critical` BOOLEAN, DEFAULT FALSE
                    if (!CharonCertificateReadTLV(bytes, length, valContent, &valTag, &valContent, &valNext, length))
                        break;
                }
                if (valTag == 0x04
                    && CharonCertificateOIDIs(bytes, oidContent, oidNext - oidContent,
                                              CharonOIDSubjectAltName, sizeof CharonOIDSubjectAltName)) {
                    // the OID IS ASKED FIRST: every extension's extnValue is an OCTET STRING holding
                    // something DER-shaped, and walking the GeneralNames of the wrong extension would
                    // find rfc822Names that are not this extension's to give
                    // GeneralNames ::= SEQUENCE OF GeneralName, so extnValue holds a SEQUENCE whose
                    // ELEMENTS are the names: the loop has to go INTO that SEQUENCE, and starting at it
                    // instead steps over the whole list on the first iteration. On this fixture the
                    // extnValue begins 30 37 81 1F "charon...", which is exactly that SEQUENCE and its
                    // first [1] rfc822Name.
                    size_t names = 0, nameEnd = 0, listContent = 0, listNext = 0;
                    if (!CharonCertificateReadTLV(bytes, valNext, valContent, &tag, &listContent,
                                                  &listNext, valNext) || tag != 0x30)
                        return false;
                    names = listContent;
                    nameEnd = listNext;
                    while (names < nameEnd && CharonCertificateReadTLV(bytes, nameEnd, names, &tag, &content, &next, nameEnd)) {
                        if (tag == 0x81) {            // rfc822Name, [1] IMPLICIT IA5String, a ONE-BYTE
                                                       // tag, which a reader that only understood the
                                                       // low-tag forms would never match
                            CFStringRef value = CharonCertificateStringValue(bytes, 0x16, content,
                                                                             next - content);
                            if (value) {
                                visit(value, context);
                                CFRelease(value);
                            }
                        }
                        names = next;
                    }
                    return true;
                }
                exts = next;
            }
            return false;
        }
        at = next;
    }
    return false;
}

OSStatus SecCertificateCopyEmailAddresses(SecCertificateRef certificate, CFArrayRef *addresses)
{
    if (!certificate || !addresses)
        return errSecParam;
    *addresses = NULL;
    CFDataRef der = SecCertificateCopyData(certificate);
    if (!der)
        return errSecInternalComponent;   // SecBase.h:261 - there is no errSecInternal
    size_t length = (size_t)CFDataGetLength(der);
    const uint8_t *bytes = (const uint8_t *)CFDataGetBytePtr(der);
    CFMutableArrayRef found = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    CharonAllMatches all = {found};
    size_t start = 0, end = 0;
    if (length && bytes) {
        if (CharonCertificateNameTLV(bytes, length, true, &start, &end))
            CharonCertificateVisitNameFields(bytes, start, end, CharonOIDEmailAddress,
                                             sizeof CharonOIDEmailAddress, CharonKeepAll, &all);
        CharonCertificateSANs(bytes, length, CharonKeepAll, &all);
    }
    CFRelease(der);
    if (!found || CFArrayGetCount(found) == 0) {
        if (found)
            CFRelease(found);
        return errSecItemNotFound;                   // no address is a fact, not a fault
    }
    *addresses = found;                              // +1, as CF_RETURNS_RETAINED says
    return errSecSuccess;
}
