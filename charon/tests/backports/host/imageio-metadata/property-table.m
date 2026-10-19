// The HOST's property-to-tag table, measured one (dictionary, property) pair per process.
//
// Both directions of the pair are recorded in the same process, and the process's exit status is the
// answer to "does the host answer at all for this pair": a pair the host cannot answer for is a pair
// whose table row is absent, and a trap would be recorded as such rather than swallowed.
//
// WHAT THIS FILE IS NOT: it does not guess the XMP tag a property maps to. The name comes out of the
// host's own CGImageMetadataSetValueMatchingImageProperty, which writes the tag it maps the property to,
// and the tag is then read back out of the tree with CGImageMetadataCopyTags. The lookup direction is
// then asked the question the port has to answer: hold that tag in a container and ask
// CGImageMetadataCopyTagMatchingImageProperty which tag it hands back.
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>

// TWO MEASUREMENT DEFECTS ARE BUILT OUT OF THIS ONE FUNCTION, and both were found on 2026-10-03 by
// measuring this pair list rather than by reading it:
//
//  1. ARC owns what ImageIO hands back. These accessors are declared as returning a retained CFStringRef
//     and ARC keeps it, so a probe that CFRelease's the result releases it twice and traps inside the
//     ObjC runtime's release path - a trap in the probe, not an answer from ImageIO. An earlier reading
//     of this same pair list recorded that as "the host traps on the set direction for 173 of 192
//     pairs"; the host answers all 518.
//  2. CFStringGetCStringPtr answers NULL for a string it cannot hand back in place, which is most of
//     ImageIO's own tag names: 89 of the 357 names this table carries printed "(null)" that way while
//     CFStringGetLength and CFCopyDescription both answered the real name. So the C string is copied
//     out instead, into one of four rotating buffers, because one printf here uses three of them.
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

// The prefix a path may use for a namespace: the public prefix when the namespace is one of the ten
// ImageIO declares a prefix for, and the namespace URI itself otherwise. This is the prefix the host's
// own default is, measured (facts/ImageIO/Metadata.md, "TagCreate with a NULL prefix").
static CFStringRef prefix_for_namespace(CFStringRef ns)
{
    // filled into the caller's own array: the constants are not compile-time constants for a static
    // initializer (CFSTR is a builtin call), which is why packages/a/apple-backports/Graphics/
    // ImageIOMetadata7.m builds its namespace table the same way.
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

// Put a tag with this namespace, prefix and name into a fresh container, the way a caller holding XMP
// would: by its path. A tag whose prefix the host answers NULL for is held under the namespace's public
// prefix, which is what a path written without one resolves to.
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
        static charon_pair pairs[600];
        size_t npairs = charon_pairs(pairs);
        if (argc < 2)
            return 2;
        size_t index = (size_t)atoi(argv[1]);
        if (index >= npairs)
            return 2;

        printf("# pair\t%s\t%s\n", S(pairs[index].dictionary), S(pairs[index].property));

        // 1. THE SET DIRECTION: what tag does the host write for this property?
        CGMutableImageMetadataRef one = CGImageMetadataCreateMutable();
        BOOL ok = CGImageMetadataSetValueMatchingImageProperty(one, pairs[index].dictionary, pairs[index].property,
                                                               CFSTR("v"));
        printf("set\t%d\n", (int)ok);
        dump_tags(one, "set");

        // 2. THE LOOKUP DIRECTION over the tree the set just wrote: the tag the host wrote is in it.
        CGImageMetadataTagRef none = CGImageMetadataCopyTagMatchingImageProperty(one, pairs[index].dictionary,
                                                                                 pairs[index].property);
        printf("lookup-written-in-place\t%s\n", none ? "tag" : "NULL");
        if (none)
            print_tag(none);

        // 3. AND OVER A FRESH CONTAINER HOLDING ONLY THAT TAG: if the lookup does not answer it here,
        //    the two functions disagree inside the host and the table is not one table.
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
            // 4. AND OVER AN EMPTY CONTAINER, which must answer NULL: a property the host maps is still
            //    absent from a tree that does not hold it.
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