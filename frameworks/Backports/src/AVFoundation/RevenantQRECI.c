#include "RevenantQRCode.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFStringEncodingExt.h>
#include <stdlib.h>

static const char *charset_name(int eci)
{
    switch (eci) {
    case 0:
    case 2:
        return "IBM437";
    case 4:
        return "ISO-8859-2";
    case 5:
        return "ISO-8859-3";
    case 6:
        return "ISO-8859-4";
    case 7:
        return "ISO-8859-5";
    case 8:
        return "ISO-8859-6";
    case 9:
        return "ISO-8859-7";
    case 10:
        return "ISO-8859-8";
    case 11:
        return "ISO-8859-9";
    case 12:
        return "ISO-8859-10";
    case 13:
        return "ISO-8859-11";
    case 15:
        return "ISO-8859-13";
    case 16:
        return "ISO-8859-14";
    case 17:
        return "ISO-8859-15";
    case 18:
        return "ISO-8859-16";
    case 20:
        return "Shift_JIS";
    case 21:
        return "windows-1250";
    case 22:
        return "windows-1251";
    case 23:
        return "windows-1252";
    case 24:
        return "windows-1256";
    case 25:
        return "UTF-16BE";
    case 27:
    case 170:
        return "US-ASCII";
    case 28:
        return "Big5";
    case 29:
        return "GB18030";
    case 30:
        return "EUC-KR";
    default:
        return NULL;
    }
}

static int convert_to_utf8(int eci, const uint8_t *bytes, size_t length, char **out, size_t *outLength)
{
    const char *name = charset_name(eci);
    if (!name)
        return 0;
    CFStringRef iana = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingASCII);
    CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding(iana);
    CFRelease(iana);
    if (encoding == kCFStringEncodingInvalidId)
        return 0;
    CFStringRef string = CFStringCreateWithBytes(kCFAllocatorDefault, bytes, (CFIndex)length, encoding, false);
    if (!string)
        return 0;
    CFIndex characters = CFStringGetLength(string);
    CFRange range = CFRangeMake(0, characters);
    CFIndex needed = 0;
    CFStringGetBytes(string, range, kCFStringEncodingUTF8, 0, false, NULL, 0, &needed);
    char *buffer = malloc((size_t)needed + 1);
    CFIndex written = 0;
    CFIndex converted = CFStringGetBytes(string, range, kCFStringEncodingUTF8, 0, false, (UInt8 *)buffer, needed, &written);
    CFRelease(string);
    if (converted != characters) {
        free(buffer);
        return 0;
    }
    buffer[written] = 0;
    *out = buffer;
    *outLength = (size_t)written;
    return 1;
}

void revenant_qr_install_default_converter(void)
{
    revenant_qr_set_converter(convert_to_utf8);
}
