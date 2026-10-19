// What the HOST's own CGImageMetadataCopyTagMatchingImageProperty answers, for every (dictionary, property)
// pair the iOS 16.4 header declares. This is the measurement the port's table is generated from, and the
// command that produces it is named in packages/a/apple-backports/facts/ImageIO/Metadata.md.
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

// CFStringGetCStringPtr answers NULL for a string it cannot return in place, which is most of ImageIO's
// own tag names, and a probe that printed a name that way said "(null)" for 89 of the names the table
// carries while CFStringGetLength and CFCopyDescription both answered the real name. So the C string is
// copied out instead, into one of four rotating buffers, because one printf here uses three of them.
#define CHARON_S_BUFFERS 4
static const char *S(CFStringRef s)
{
    static char buffers[CHARON_S_BUFFERS][1024];
    static unsigned next = 0;
    if (!s)
        return "(nil)";
    char *buffer = buffers[next++ % CHARON_S_BUFFERS];
    if (!CFStringGetCString(s, buffer, sizeof buffers[0], kCFStringEncodingUTF8))
        return "(unprintable)";
    return buffer;
}

static void answer(const char *dictName, const char *propName, CFStringRef dictionary, CFStringRef property,
                   CGImageMetadataRef metadata)
{
    CGImageMetadataTagRef tag = CGImageMetadataCopyTagMatchingImageProperty(metadata, dictionary, property);
    if (!tag) {
        printf("empty\t%s\t%s\tNULL\n", dictName, propName);
        return;
    }
    printf("empty\t%s\t%s\t%s\t%s\t%s\t%d\n", dictName, propName, S(CGImageMetadataTagCopyNamespace(tag)),
           S(CGImageMetadataTagCopyPrefix(tag)), S(CGImageMetadataTagCopyName(tag)), (int)CGImageMetadataTagGetType(tag));
}

static void answerValue(const char *label, const char *dictName, const char *propName, CFStringRef dictionary,
                        CFStringRef property, CGImageMetadataRef metadata)
{
    CGImageMetadataTagRef tag = CGImageMetadataCopyTagMatchingImageProperty(metadata, dictionary, property);
    id value = tag ? (__bridge_transfer id)CGImageMetadataTagCopyValue(tag) : nil;
    printf("%s\t%s\t%s\tvalue=%s\n", label, dictName, propName, value ? S((__bridge CFStringRef)value) : "(nil)");
}

typedef struct {
    CFStringRef dictionary;
    CFStringRef property;
} charon_probe_pair;

typedef struct {
    CFStringRef prefix;
    CFStringRef namespace;
} charon_probe_space;

static size_t charon_probe_spaces(charon_probe_space *out)
{
    out[0].prefix = kCGImageMetadataPrefixExif;          out[0].namespace = kCGImageMetadataNamespaceExif;
    out[1].prefix = kCGImageMetadataPrefixTIFF;          out[1].namespace = kCGImageMetadataNamespaceTIFF;
    out[2].prefix = kCGImageMetadataPrefixPhotoshop;    out[2].namespace = kCGImageMetadataNamespacePhotoshop;
    out[3].prefix = kCGImageMetadataPrefixDublinCore;   out[3].namespace = kCGImageMetadataNamespaceDublinCore;
    out[4].prefix = kCGImageMetadataPrefixIPTCCore;     out[4].namespace = kCGImageMetadataNamespaceIPTCCore;
    out[5].prefix = kCGImageMetadataPrefixXMPBasic;      out[5].namespace = kCGImageMetadataNamespaceXMPBasic;
    out[6].prefix = kCGImageMetadataPrefixXMPRights;    out[6].namespace = kCGImageMetadataNamespaceXMPRights;
    out[7].prefix = kCGImageMetadataPrefixExifAux;      out[7].namespace = kCGImageMetadataNamespaceExifAux;
    out[8].prefix = kCGImageMetadataPrefixIPTCExtension;
    out[8].namespace = kCGImageMetadataNamespaceIPTCExtension;
    return 9;
}

#include "property-pairs.h"

int main(int argc, const char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        CGMutableImageMetadataRef empty = CGImageMetadataCreateMutable();
        // a metadata that holds the three tags the earlier probe used, to see whether the answer depends on
        // what the container holds or only on the pair it was asked about
        CGMutableImageMetadataRef filled = CGImageMetadataCreateMutable();
        CGImageMetadataSetValueWithPath(filled, NULL, CFSTR("exif:Flash"), CFSTR("1"));
        CGImageMetadataSetValueWithPath(filled, NULL, CFSTR("tiff:Orientation"), (__bridge CFNumberRef)@1);
        CGImageMetadataSetValueWithPath(filled, NULL, CFSTR("exif:DateTimeOriginal"), CFSTR("2010:01:02 03:04:05"));

        charon_probe_pair pairs[256];
        size_t npairs = charon_probe_pairs(pairs);
        if (argc > 1) {
        // WHERE DOES A SET LAND? One pair per process, chosen by argv[1]: the host TRAPS on
        // SetValueMatchingImageProperty for some pairs (measured 2026-10-01: pair 0, Exif/ApertureValue,
        // exits 133), and a trap is an answer of its own - the host cannot answer for that pair - so each
        // pair is asked in its own process and its exit status is recorded.
        if (argc > 1) {
            size_t index = (size_t)atoi(argv[1]);
            if (index >= npairs)
                return 2;
            CGMutableImageMetadataRef one = CGImageMetadataCreateMutable();
            BOOL ok = CGImageMetadataSetValueMatchingImageProperty(one, pairs[index].dictionary, pairs[index].property,
                                                                   CFSTR("v"));
            NSArray *tags = (__bridge_transfer NSArray *)CGImageMetadataCopyTags(one);
            NSMutableString *after = [NSMutableString string];
            for (CFIndex t = 0; t < (CFIndex)tags.count; t++) {
                CGImageMetadataTagRef tag = (__bridge CGImageMetadataTagRef)[tags objectAtIndex:(NSUInteger)t];
                // %s and not %@: a %@ with a C string sends -respondsToSelector: to a stack address, the
                // ObjC runtime answers with a trap and the process dies with SIGTRAP. That is what made
                // this probe report "the host traps" for 173 of the 192 pairs: the trap was in this line,
                // after SetValueMatchingImageProperty had already returned true and written its tag.
                char line[512];
                snprintf(line, sizeof line, "%s:%s:%s|", S(CGImageMetadataTagCopyNamespace(tag)),
                         S(CGImageMetadataTagCopyPrefix(tag)), S(CGImageMetadataTagCopyName(tag)));
                [after appendString:@(line)];
            }
            printf("set\t%s\t%s\t%d\t%lu\t%@\n", S(pairs[index].dictionary), S(pairs[index].property), (int)ok,
                   (unsigned long)tags.count, after);
            return 0;
        }

            return 0;
        }

        printf("# dict\tproperty\tns\tprefix\tname\ttype   (empty metadata)\n");
        for (size_t i = 0; i < npairs; i++)
            answer(S(pairs[i].dictionary), S(pairs[i].property), pairs[i].dictionary, pairs[i].property, empty);

        // CONTROLS, or a zero on every pair would prove nothing: a dictionary and a property no header
        // declares must answer NULL, and a property that IS in the container must still answer the same tag
        printf("# controls\n");
        printf("control\tNoSuchDictionary\tOrientation\t");
        answer("NoSuchDictionary", "Orientation", CFSTR("NoSuchDictionary"), kCGImagePropertyTIFFOrientation, empty);
        printf("control\tExif\tNoSuchProperty\t");
        answer("Exif", "NoSuchProperty", kCGImagePropertyExifDictionary, CFSTR("NoSuchProperty"), empty);
        printf("control\tExif\tNoSuchProperty-filled\t");
        answer("Exif", "NoSuchProperty", kCGImagePropertyExifDictionary, CFSTR("NoSuchProperty"), filled);
        printf("control\tExif\tDateTimeOriginal-filled\t");
        answer("Exif", "DateTimeOriginal", kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeOriginal,
               filled);
        printf("control\tTIFF\tOrientation-filled\t");
        answer("TIFF", "Orientation", kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFOrientation, filled);

        // does a property the container already holds answer the container's value?
        printf("# value of a tag the container holds\n");
        answerValue("held-orientation", "TIFF", "Orientation", kCGImagePropertyTIFFDictionary,
                    kCGImagePropertyTIFFOrientation, filled);
        answerValue("empty-orientation", "TIFF", "Orientation", kCGImagePropertyTIFFDictionary,
                    kCGImagePropertyTIFFOrientation, empty);
        answerValue("held-dto", "Exif", "DateTimeOriginal", kCGImagePropertyExifDictionary,
                    kCGImagePropertyExifDateTimeOriginal, filled);

        // WHICH TAG does each pair name? A container is built holding one tag, the property's own name in
        // one of the namespaces ImageIO knows, and the pair is asked which container answers: that names the
        // namespace the property maps to without guessing it, and a pair no namespace answers is a pair whose
        // tag is named something else (and the next run names what).
        charon_probe_space spaces[9];
        size_t nspaces = charon_probe_spaces(spaces);
        (void)nspaces;

        printf("# which namespace: dict\tproperty\tprefix-that-answered\n");
        for (size_t i = 0; i < npairs; i++) {
            const char *hit = "none";
            for (size_t k = 0; k < nspaces; k++) {
                CGMutableImageMetadataRef one = CGImageMetadataCreateMutable();
                NSString *path = [NSString stringWithFormat:@"%@:%@", (__bridge NSString *)spaces[k].prefix,
                                                            (__bridge NSString *)pairs[i].property];
                if (!CGImageMetadataSetValueWithPath(one, NULL, (__bridge CFStringRef)path, CFSTR("v")))
                    continue;
                if (CGImageMetadataCopyTagMatchingImageProperty(one, pairs[i].dictionary, pairs[i].property)) {
                    hit = S(spaces[k].prefix);
                    break;
                }
            }
            printf("ownname\t%s\t%s\t%s\n", S(pairs[i].dictionary), S(pairs[i].property), hit);
        }

        return 0;
    }
}