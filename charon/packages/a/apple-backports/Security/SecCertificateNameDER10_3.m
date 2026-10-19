#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#include <string.h>

bool CharonCertificateReadTLV(const uint8_t *bytes, size_t length, size_t at, uint8_t *tag,
                                    size_t *content, size_t *next, size_t limit)
{
    if (at + 2 > limit || limit > length)
        return false;
    uint8_t identifier = bytes[at];
    size_t cursor = at + 1;
    size_t size = bytes[cursor++];
    if ((size & 0x80) != 0) {
        size_t count = size & 0x7f;
        if (count == 0 || count > 4 || cursor + count > limit)
            return false;
        size = 0;
        for (size_t i = 0; i < count; i++)
            size = (size << 8) | bytes[cursor++];
    }
    if (cursor + size > limit)
        return false;
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
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = content;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = content;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length))
        return false;
    at = content;
    if (tag == 0xa0) {
        if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length))
            return false;
        at = next;
    }
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x02)
        return false;
    at = next;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = next;
    *outStart = at;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    *outEnd = next;
    if (!wantSubject)
        return true;
    at = next;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = next;
    *outStart = at;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    *outEnd = next;
    return true;
}

static CFDataRef CharonCertificateCopyName(SecCertificateRef certificate, bool wantSubject)
{
    if (!certificate)
        return NULL;
    CFDataRef der = SecCertificateCopyData(certificate);
    if (!der)
        return NULL;
    size_t length = (size_t)CFDataGetLength(der);
    const uint8_t *bytes = (const uint8_t *)CFDataGetBytePtr(der);
    size_t start = 0, end = 0;
    bool found = length && bytes && CharonCertificateNameTLV(bytes, length, wantSubject, &start, &end);
    CFDataRef name = (found && end > start)
        ? CFDataCreate(kCFAllocatorDefault, bytes + start, (CFIndex)(end - start))
        : NULL;
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

static bool CharonCertificateOIDIs(const uint8_t *bytes, size_t content, size_t size,
                                  const uint8_t *oid, size_t oidSize)
{
    return size == oidSize && memcmp(bytes + content, oid, oidSize) == 0;
}

static const uint8_t CharonOIDCommonName[] = {0x55, 0x04, 0x03};
static const uint8_t CharonOIDEmailAddress[] = {0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01};
static const uint8_t CharonOIDSubjectAltName[] = {0x55, 0x1D, 0x11};

static CFStringRef CharonCertificateStringValue(const uint8_t *bytes, uint8_t tag, size_t content, size_t size)
{
    CFStringEncoding encoding;
    if (tag == 0x0c)
        encoding = kCFStringEncodingUTF8;
    else if (tag == 0x13)
        encoding = kCFStringEncodingASCII;
    else if (tag == 0x16)
        encoding = kCFStringEncodingASCII;
    else if (tag == 0x1e)
        encoding = kCFStringEncodingUTF16BE;
    else
        return NULL;
    if (size == 0)
        return NULL;
    return CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)bytes + content, (CFIndex)size,
                                   encoding, false);
}

typedef void (*CharonCertificateFieldVisitor)(CFStringRef value, void *context);

static void CharonCertificateVisitNameFields(const uint8_t *bytes, size_t start, size_t end,
                                            const uint8_t *wanted, size_t wantedSize,
                                            CharonCertificateFieldVisitor visit, void *context)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = start;
    if (!CharonCertificateReadTLV(bytes, end, at, &tag, &content, &next, end) || tag != 0x30)
        return;
    at = content;
    while (at < end && CharonCertificateReadTLV(bytes, end, at, &tag, &content, &next, end)) {
        if (tag != 0x31) {
            at = next;
            continue;
        }
        size_t setAt = content;
        while (setAt < end && CharonCertificateReadTLV(bytes, end, setAt, &tag, &content, &next, end)) {
            if (tag != 0x30) {
                setAt = next;
                continue;
            }
            uint8_t typeTag = 0;
            uint8_t valueTag = 0;
            size_t atv = content, typeContent = 0, typeNext = 0, valueContent = 0, valueNext = 0;
            if (!CharonCertificateReadTLV(bytes, end, atv, &typeTag, &typeContent, &typeNext, end))
                break;
            if (typeTag != 0x06) {
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
            atv = valueNext;
            (void)atv;
            setAt = next;
            break;
        }
        at = next;
    }
}

typedef struct { CFStringRef first; } CharonFirstMatch;
static void CharonKeepFirst(CFStringRef value, void *context)
{
    CharonFirstMatch *match = (CharonFirstMatch *)context;
    if (!match->first)
        match->first = (CFStringRef)CFRetain(value);
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
        return errSecInternalComponent;
    size_t length = (size_t)CFDataGetLength(der);
    const uint8_t *bytes = (const uint8_t *)CFDataGetBytePtr(der);
    size_t start = 0, end = 0;
    CharonFirstMatch match = {NULL};
    if (length && bytes && CharonCertificateNameTLV(bytes, length, true, &start, &end))
        CharonCertificateVisitNameFields(bytes, start, end, CharonOIDCommonName,
                                         sizeof CharonOIDCommonName, CharonKeepFirst, &match);
    CFRelease(der);
    if (!match.first)
        return errSecItemNotFound;
    *name = match.first;
    return errSecSuccess;
}

static bool CharonCertificateSANs(const uint8_t *bytes, size_t length, CharonCertificateFieldVisitor visit,
                                  void *context)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = 0;
    if (!CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    if (!CharonCertificateReadTLV(bytes, length, content, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = content;
    while (at < length && CharonCertificateReadTLV(bytes, length, at, &tag, &content, &next, length)) {
        if (tag == 0xa3) {
            size_t wrapper = 0, wrapperEnd = 0, listContent = 0, listNext = 0;
            if (!CharonCertificateReadTLV(bytes, length, content, &tag, &listContent, &listNext, length)
                || tag != 0x30)
                return false;
            (void)wrapper;
            (void)wrapperEnd;
            size_t exts = listContent, extsEnd = listNext;
            while (exts < extsEnd && CharonCertificateReadTLV(bytes, extsEnd, exts, &tag, &content, &next, extsEnd)) {
                if (tag != 0x30) {
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
                if (tag == 0x01) {
                    if (!CharonCertificateReadTLV(bytes, length, valContent, &valTag, &valContent, &valNext, length))
                        break;
                }
                if (valTag == 0x04
                    && CharonCertificateOIDIs(bytes, oidContent, oidNext - oidContent,
                                              CharonOIDSubjectAltName, sizeof CharonOIDSubjectAltName)) {
                    size_t names = 0, nameEnd = 0, listContent = 0, listNext = 0;
                    if (!CharonCertificateReadTLV(bytes, valNext, valContent, &tag, &listContent,
                                                  &listNext, valNext) || tag != 0x30)
                        return false;
                    names = listContent;
                    nameEnd = listNext;
                    while (names < nameEnd && CharonCertificateReadTLV(bytes, nameEnd, names, &tag, &content, &next, nameEnd)) {
                        if (tag == 0x81) {
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
        return errSecInternalComponent;
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
        return errSecItemNotFound;
    }
    *addresses = found;
    return errSecSuccess;
}
