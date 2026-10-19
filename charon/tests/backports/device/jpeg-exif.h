#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#include <string.h>

// Read by the photo output's host oracle (host/photosettings) and its device test (device/photooutput10.m) alike.

static unsigned read16(const uint8_t *p, BOOL big) { return big ? (p[0] << 8 | p[1]) : (p[1] << 8 | p[0]); }
static unsigned read32(const uint8_t *p, BOOL big) { return big ? ((unsigned)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]) : ((unsigned)p[3] << 24 | p[2] << 16 | p[1] << 8 | p[0]); }

// What a JPEG file holds, read by the Exif standard's layout rather than through ImageIO (which on the host answers a
// thumbnail for a file that has none): the picture's size and Exif user comment by ImageIO, then IFD1 of the Exif
// segment, each tag with its type, count and value (a rational read out; the thumbnail's offset and length as "set"),
// the APPn segments of the thumbnail and its size.
static NSString *jpeg_contents(NSData *file)
{
    if (!file)
        return @"nil";
    NSMutableString *out = [NSMutableString string];
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)file, NULL);
    NSDictionary *properties = source ? CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) : nil;
    [out appendFormat:@"%@x%@ comment %@;", properties[(id)kCGImagePropertyPixelWidth], properties[(id)kCGImagePropertyPixelHeight],
                      properties[(id)kCGImagePropertyExifDictionary][(id)kCGImagePropertyExifUserComment]];
    if (source)
        CFRelease(source);
    const uint8_t *b = file.bytes;
    size_t n = file.length, at = 2;
    while (at + 4 <= n && b[at] == 0xFF && b[at + 1] != 0xDA) {
        size_t length = b[at + 2] << 8 | b[at + 3];
        if (b[at + 1] == 0xE1 && length > 8 && memcmp(b + at + 4, "Exif\0\0", 6) == 0) {
            const uint8_t *t = b + at + 10;
            BOOL big = t[0] == 'M';
            unsigned ifd0 = read32(t + 4, big), ifd1 = read32(t + ifd0 + 2 + 12 * read16(t + ifd0, big), big);
            if (!ifd1) {
                [out appendString:@" no IFD1"];
                return out;
            }
            unsigned offset = 0, size = 0, entries = read16(t + ifd1, big);
            [out appendString:@" IFD1"];
            for (unsigned k = 0; k < entries; k++) {
                const uint8_t *e = t + ifd1 + 2 + 12 * k;
                unsigned tag = read16(e, big), type = read16(e + 2, big), count = read32(e + 4, big);
                unsigned value = type == 3 ? read16(e + 8, big) : read32(e + 8, big);
                if (tag == 0x0201)
                    offset = value;
                if (tag == 0x0202)
                    size = value;
                NSString *shown = tag == 0x0201 || tag == 0x0202 ? @"set" : type == 5 ? [NSString stringWithFormat:@"%u/%u", read32(t + value, big), read32(t + value + 4, big)]
                                                                                  : [NSString stringWithFormat:@"%u", value];
                [out appendFormat:@" %04x/%u/%u=%@", tag, type, count, shown];
            }
            [out appendFormat:@" next %u;", read32(t + ifd1 + 2 + 12 * entries, big)];
            NSData *thumbnail = offset && size ? [NSData dataWithBytes:t + offset length:size] : nil;
            const uint8_t *tb = thumbnail.bytes;
            for (size_t i = 2; thumbnail && i + 4 <= size && tb[i] == 0xFF && tb[i + 1] != 0xDA; i += 2 + (tb[i + 2] << 8 | tb[i + 3]))
                if (tb[i + 1] >= 0xE0 && tb[i + 1] <= 0xEF)
                    [out appendFormat:@" thumbnail APP%d", tb[i + 1] - 0xE0];
            CGImageSourceRef ts = thumbnail ? CGImageSourceCreateWithData((__bridge CFDataRef)thumbnail, NULL) : NULL;
            NSDictionary *tp = ts ? CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(ts, 0, NULL)) : nil;
            [out appendFormat:@" thumbnail %@x%@", tp[(id)kCGImagePropertyPixelWidth], tp[(id)kCGImagePropertyPixelHeight]];
            if (ts)
                CFRelease(ts);
            return out;
        }
        at += 2 + length;
    }
    [out appendString:@" no Exif"];
    return out;
}
