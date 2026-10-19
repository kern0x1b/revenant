#import <Foundation/Foundation.h>
#import <Security/Security.h>

static BOOL charon_der_read(const uint8_t *bytes, size_t length, size_t *offset, uint8_t *tag, size_t *size)
{
    if (*offset + 2 > length)
        return NO;
    *tag = bytes[(*offset)++];
    size_t count = bytes[(*offset)++];
    if (count & 0x80) {
        size_t octets = count & 0x7F;
        if (!octets || octets > sizeof(size_t) || *offset + octets > length)
            return NO;
        count = 0;
        while (octets--)
            count = (count << 8) | bytes[(*offset)++];
    }
    if (count > length - *offset)
        return NO;
    *size = count;
    return YES;
}

CFDataRef SecCertificateCopySerialNumberData(SecCertificateRef certificate, CFErrorRef *error)
{
    CFDataRef data = certificate ? SecCertificateCopyData(certificate) : NULL;
    const uint8_t *bytes = data ? CFDataGetBytePtr(data) : NULL;
    size_t length = data ? (size_t)CFDataGetLength(data) : 0, offset = 0, size = 0;
    uint8_t tag = 0;
    CFDataRef serial = NULL;
    if (bytes && charon_der_read(bytes, length, &offset, &tag, &size) && tag == 0x30 && charon_der_read(bytes, length, &offset, &tag, &size) && tag == 0x30) {
        if (charon_der_read(bytes, length, &offset, &tag, &size) && tag == 0xA0) {
            offset += size;
            charon_der_read(bytes, length, &offset, &tag, &size);
        }
        if (tag == 0x02 && size > 0)
            serial = CFDataCreate(NULL, bytes + offset, (CFIndex)size);
    }
    if (data)
        CFRelease(data);
    if (!serial && error)
        *error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:NSOSStatusErrorDomain code:errSecDecode userInfo:nil]);
    else if (error)
        *error = NULL;
    return serial;
}
