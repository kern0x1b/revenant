#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>

#define REVENANT_S_BUFFERS 4
static const char *S(CFStringRef s)
{
    static char buffers[REVENANT_S_BUFFERS][1024];
    static unsigned next = 0;
    if (!s)
        return "(nil)";
    char *buffer = buffers[next++ % REVENANT_S_BUFFERS];
    if (!CFStringGetCString(s, buffer, sizeof buffers[0], kCFStringEncodingUTF8))
        return "(unprintable)";
    return buffer;
}

static void print_tag(CGImageMetadataTagRef tag)
{
    printf("tag\t%s\t%s\t%s\t%d\n", S(CGImageMetadataTagCopyNamespace(tag)), S(CGImageMetadataTagCopyPrefix(tag)),
           S(CGImageMetadataTagCopyName(tag)), (int)CGImageMetadataTagGetType(tag));
}

static void dump_tags(CGImageMetadataRef metadata, const char *label)
{
    NSArray *tags = (__bridge_transfer NSArray *)CGImageMetadataCopyTags(metadata);
    for (CFIndex i = 0; i < (CFIndex)tags.count; i++) {
        printf("%s\t%ld\t", label, (long)i);
        print_tag((__bridge CGImageMetadataTagRef)tags[(NSUInteger)i]);
    }
    printf("%s-count\t%lu\n", label, (unsigned long)tags.count);
}

static CFStringRef prefix_for_namespace(CFStringRef ns)
{
    CFStringRef publics[10];
    CFStringRef spaces[10];
    size_t count = 0;
    count++, publics[count - 1] = kCGImageMetadataPrefixExif, spaces[count - 1] = kCGImageMetadataNamespaceExif;
    count++, publics[count - 1] = kCGImageMetadataPrefixExifAux, spaces[count - 1] = kCGImageMetadataNamespaceExifAux;
    count++, publics[count - 1] = kCGImageMetadataPrefixExifEX, spaces[count - 1] = kCGImageMetadataNamespaceExifEX;
    count++, publics[count - 1] = kCGImageMetadataPrefixDublinCore, spaces[count - 1] = kCGImageMetadataNamespaceDublinCore;
    count++, publics[count - 1] = kCGImageMetadataPrefixIPTCCore, spaces[count - 1] = kCGImageMetadataNamespaceIPTCCore;
    count++, publics[count - 1] = kCGImageMetadataPrefixIPTCExtension, spaces[count - 1] = kCGImageMetadataNamespaceIPTCExtension;
    count++, publics[count - 1] = kCGImageMetadataPrefixPhotoshop, spaces[count - 1] = kCGImageMetadataNamespacePhotoshop;
    count++, publics[count - 1] = kCGImageMetadataPrefixTIFF, spaces[count - 1] = kCGImageMetadataNamespaceTIFF;
    count++, publics[count - 1] = kCGImageMetadataPrefixXMPBasic, spaces[count - 1] = kCGImageMetadataNamespaceXMPBasic;
    count++, publics[count - 1] = kCGImageMetadataPrefixXMPRights, spaces[count - 1] = kCGImageMetadataNamespaceXMPRights;
    for (size_t i = 0; i < count; i++)
        if (CFEqual(spaces[i], ns))
            return publics[i];
    return ns;
}

static CGImageMetadataRef container_holding(CFStringRef ns, CFStringRef prefix, CFStringRef name)
{
    CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
    CGImageMetadataRegisterNamespaceForPrefix(m, ns, prefix, NULL);
    NSString *path = [NSString stringWithFormat:@"%@:%@", (__bridge NSString *)prefix, (__bridge NSString *)name];
    if (!CGImageMetadataSetValueWithPath(m, NULL, (__bridge CFStringRef)path, CFSTR("v")))
        printf("container-hold-failed\t%s\n", path.UTF8String);
    return m;
}

#include "property-pairs-all.h"

int main(int argc, const char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        static revenant_pair pairs[600];
        size_t npairs = revenant_pairs(pairs);
        if (argc < 2)
            return 2;
        size_t index = (size_t)atoi(argv[1]);
        if (index >= npairs)
            return 2;

        printf("# pair\t%s\t%s\n", S(pairs[index].dictionary), S(pairs[index].property));

        CGMutableImageMetadataRef one = CGImageMetadataCreateMutable();
        BOOL ok = CGImageMetadataSetValueMatchingImageProperty(one, pairs[index].dictionary, pairs[index].property,
                                                               CFSTR("v"));
        printf("set\t%d\n", (int)ok);
        dump_tags(one, "set");

        CGImageMetadataTagRef none = CGImageMetadataCopyTagMatchingImageProperty(one, pairs[index].dictionary,
                                                                                 pairs[index].property);
        printf("lookup-written-in-place\t%s\n", none ? "tag" : "NULL");
        if (none)
            print_tag(none);

        NSArray *tags = (__bridge_transfer NSArray *)CGImageMetadataCopyTags(one);
        printf("tag-count\t%lu\n", (unsigned long)tags.count);
        if (tags.count == 1) {
            CGImageMetadataTagRef written = (__bridge CGImageMetadataTagRef)tags[0];
            CFStringRef ns = CGImageMetadataTagCopyNamespace(written);
            CFStringRef prefix = CGImageMetadataTagCopyPrefix(written);
            CFStringRef name = CGImageMetadataTagCopyName(written);
            CFStringRef effective = prefix ? prefix : prefix_for_namespace(ns);
            CGImageMetadataRef holding = container_holding(ns, effective, name);
            CGImageMetadataTagRef found = CGImageMetadataCopyTagMatchingImageProperty(holding,
                                                                                      pairs[index].dictionary,
                                                                                      pairs[index].property);
            printf("lookup-fresh\t%s\t%s\n", found ? "tag" : "NULL", prefix ? "prefixed" : "default-prefix");
            if (found)
                print_tag(found);
            CGMutableImageMetadataRef empty = CGImageMetadataCreateMutable();
            CGImageMetadataTagRef absent = CGImageMetadataCopyTagMatchingImageProperty(empty,
                                                                                      pairs[index].dictionary,
                                                                                      pairs[index].property);
            printf("lookup-empty\t%s\n", absent ? "tag" : "NULL");
            CFRelease(empty);
            CFRelease(holding);
        }
        return 0;
    }
}
