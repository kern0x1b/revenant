#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#include <string.h>

bool RevenantCertificateReadTLV(const uint8_t *bytes, size_t length, size_t at, uint8_t *tag,
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

bool RevenantCertificateNameTLV(const uint8_t *bytes, size_t length, bool wantSubject,
                                    size_t *outStart, size_t *outEnd)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = 0;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = content;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = content;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length))
        return false;
    at = content;
    if (tag == 0xa0) {
        if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length))
            return false;
        at = next;
    }
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x02)
        return false;
    at = next;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = next;
    *outStart = at;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    *outEnd = next;
    if (!wantSubject)
        return true;
    at = next;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = next;
    *outStart = at;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    *outEnd = next;
    return true;
}

static CFDataRef RevenantCertificateCopyName(SecCertificateRef certificate, bool wantSubject)
{
    if (!certificate)
        return NULL;
    CFDataRef der = SecCertificateCopyData(certificate);
    if (!der)
        return NULL;
    size_t length = (size_t)CFDataGetLength(der);
    const uint8_t *bytes = (const uint8_t *)CFDataGetBytePtr(der);
    size_t start = 0, end = 0;
    bool found = length && bytes && RevenantCertificateNameTLV(bytes, length, wantSubject, &start, &end);
    CFDataRef name = (found && end > start)
        ? CFDataCreate(kCFAllocatorDefault, bytes + start, (CFIndex)(end - start))
        : NULL;
    CFRelease(der);
    return name;
}

CFDataRef SecCertificateCopyNormalizedIssuerSequence(SecCertificateRef certificate)
{
    return RevenantCertificateCopyName(certificate, false);
}

CFDataRef SecCertificateCopyNormalizedSubjectSequence(SecCertificateRef certificate)
{
    return RevenantCertificateCopyName(certificate, true);
}

static bool RevenantCertificateOIDIs(const uint8_t *bytes, size_t content, size_t size,
                                  const uint8_t *oid, size_t oidSize)
{
    return size == oidSize && memcmp(bytes + content, oid, oidSize) == 0;
}

static const uint8_t RevenantOIDCommonName[] = {0x55, 0x04, 0x03};
static const uint8_t RevenantOIDEmailAddress[] = {0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01};
static const uint8_t RevenantOIDSubjectAltName[] = {0x55, 0x1D, 0x11};

static CFStringRef RevenantCertificateStringValue(const uint8_t *bytes, uint8_t tag, size_t content, size_t size)
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

typedef void (*RevenantCertificateFieldVisitor)(CFStringRef value, void *context);

static void RevenantCertificateVisitNameFields(const uint8_t *bytes, size_t start, size_t end,
                                            const uint8_t *wanted, size_t wantedSize,
                                            RevenantCertificateFieldVisitor visit, void *context)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = start;
    if (!RevenantCertificateReadTLV(bytes, end, at, &tag, &content, &next, end) || tag != 0x30)
        return;
    at = content;
    while (at < end && RevenantCertificateReadTLV(bytes, end, at, &tag, &content, &next, end)) {
        if (tag != 0x31) {
            at = next;
            continue;
        }
        size_t setAt = content;
        while (setAt < end && RevenantCertificateReadTLV(bytes, end, setAt, &tag, &content, &next, end)) {
            if (tag != 0x30) {
                setAt = next;
                continue;
            }
            uint8_t typeTag = 0;
            uint8_t valueTag = 0;
            size_t atv = content, typeContent = 0, typeNext = 0, valueContent = 0, valueNext = 0;
            if (!RevenantCertificateReadTLV(bytes, end, atv, &typeTag, &typeContent, &typeNext, end))
                break;
            if (typeTag != 0x06) {
                setAt = next;
                continue;
            }
            if (!RevenantCertificateReadTLV(bytes, end, typeNext, &valueTag, &valueContent, &valueNext, end))
                break;
            if (RevenantCertificateOIDIs(bytes, typeContent, typeNext - typeContent, wanted, wantedSize)) {
                CFStringRef value = RevenantCertificateStringValue(bytes, valueTag, valueContent,
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

typedef struct { CFStringRef first; } RevenantFirstMatch;
static void RevenantKeepFirst(CFStringRef value, void *context)
{
    RevenantFirstMatch *match = (RevenantFirstMatch *)context;
    if (!match->first)
        match->first = (CFStringRef)CFRetain(value);
}

typedef struct { CFMutableArrayRef addresses; } RevenantAllMatches;
static void RevenantKeepAll(CFStringRef value, void *context)
{
    CFArrayAppendValue(((RevenantAllMatches *)context)->addresses, value);
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
    RevenantFirstMatch match = {NULL};
    if (length && bytes && RevenantCertificateNameTLV(bytes, length, true, &start, &end))
        RevenantCertificateVisitNameFields(bytes, start, end, RevenantOIDCommonName,
                                         sizeof RevenantOIDCommonName, RevenantKeepFirst, &match);
    CFRelease(der);
    if (!match.first)
        return errSecItemNotFound;
    *name = match.first;
    return errSecSuccess;
}

static bool RevenantCertificateSANs(const uint8_t *bytes, size_t length, RevenantCertificateFieldVisitor visit,
                                  void *context)
{
    uint8_t tag = 0;
    size_t content = 0, next = 0, at = 0;
    if (!RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length) || tag != 0x30)
        return false;
    if (!RevenantCertificateReadTLV(bytes, length, content, &tag, &content, &next, length) || tag != 0x30)
        return false;
    at = content;
    while (at < length && RevenantCertificateReadTLV(bytes, length, at, &tag, &content, &next, length)) {
        if (tag == 0xa3) {
            size_t wrapper = 0, wrapperEnd = 0, listContent = 0, listNext = 0;
            if (!RevenantCertificateReadTLV(bytes, length, content, &tag, &listContent, &listNext, length)
                || tag != 0x30)
                return false;
            (void)wrapper;
            (void)wrapperEnd;
            size_t exts = listContent, extsEnd = listNext;
            while (exts < extsEnd && RevenantCertificateReadTLV(bytes, extsEnd, exts, &tag, &content, &next, extsEnd)) {
                if (tag != 0x30) {
                    exts = next;
                    continue;
                }
                uint8_t extTag = 0, valTag = 0;
                size_t at2 = content, oidContent = 0, oidNext = 0, valContent = 0, valNext = 0;
                if (!RevenantCertificateReadTLV(bytes, length, at2, &extTag, &oidContent, &oidNext, length))
                    break;
                if (extTag != 0x06) {
                    exts = next;
                    continue;
                }
                if (!RevenantCertificateReadTLV(bytes, length, oidNext, &valTag, &valContent, &valNext, length))
                    break;
                if (tag == 0x01) {
                    if (!RevenantCertificateReadTLV(bytes, length, valContent, &valTag, &valContent, &valNext, length))
                        break;
                }
                if (valTag == 0x04
                    && RevenantCertificateOIDIs(bytes, oidContent, oidNext - oidContent,
                                              RevenantOIDSubjectAltName, sizeof RevenantOIDSubjectAltName)) {
                    size_t names = 0, nameEnd = 0, listContent = 0, listNext = 0;
                    if (!RevenantCertificateReadTLV(bytes, valNext, valContent, &tag, &listContent,
                                                  &listNext, valNext) || tag != 0x30)
                        return false;
                    names = listContent;
                    nameEnd = listNext;
                    while (names < nameEnd && RevenantCertificateReadTLV(bytes, nameEnd, names, &tag, &content, &next, nameEnd)) {
                        if (tag == 0x81) {
                            CFStringRef value = RevenantCertificateStringValue(bytes, 0x16, content,
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
    RevenantAllMatches all = {found};
    size_t start = 0, end = 0;
    if (length && bytes) {
        if (RevenantCertificateNameTLV(bytes, length, true, &start, &end))
            RevenantCertificateVisitNameFields(bytes, start, end, RevenantOIDEmailAddress,
                                             sizeof RevenantOIDEmailAddress, RevenantKeepAll, &all);
        RevenantCertificateSANs(bytes, length, RevenantKeepAll, &all);
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
