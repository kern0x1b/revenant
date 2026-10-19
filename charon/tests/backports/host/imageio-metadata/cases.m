// The cases CGImageMetadata has to answer, compiled twice: once against the HOST's own ImageIO and once
// against the port's object, so the two sets of answers are compared by run.sh line by line.
//
// Records are one per line, `name <TAB> answer`, in the same order in both builds, so a diff of the two
// outputs is the differential. A record whose name starts with PORTONLY is the port's own guard (an object
// that is not this library's, and which the host's own function has no defined answer for); run.sh drops
// them from both sides before it compares and asserts that the port printed them and the host did not.
//
// Values are printed by charon_show(), never by CFCopyDescription: a description carries the object's
// address, so it would differ between the two builds on every line and the comparison would read as noise.

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#include <dlfcn.h>

// Every (dictionary, property) pair the SDK's CGImageProperties.h declares, generated from it by
// tools/gen/property_map.lua so the list cannot drift from the header. The property bridge below is
// asked about all of them, and table.sh is where the same list is measured on the host alone.
#include "property-pairs-all.h"

static void record(NSString *name, NSString *answer)
{
    printf("%s\t%s\n", name.UTF8String, answer.UTF8String);
}

// a tag prints as its own accessors in both builds, so the two sides are compared on namespace, prefix,
// name, type and value and not on which library's container holds them: the host's tag is a private CF
// object and the port's is a dictionary, and printing either as "obj(...)" would read as a difference
// where there is none. The test for the port's tag is its marker; the test for the host's is the type id
// the host hands out, which is not a dictionary's.
static BOOL isTag(id value)
{
    if (!value)
        return NO;
    CFTypeRef ref = (__bridge CFTypeRef)value;
    if ([value isKindOfClass:[NSDictionary class]] && [(NSDictionary *)value objectForKey:@"charon.tag"])
        return YES;
    return CFGetTypeID(ref) == CGImageMetadataTagGetTypeID() && CFGetTypeID(ref) != CFDictionaryGetTypeID();
}

static NSString *show(id value)
{
    if (!value)
        return @"(nil)";
    if (isTag(value)) {
        CGImageMetadataTagRef tag = (__bridge CGImageMetadataTagRef)value;
        NSString *ns = (__bridge_transfer NSString *)CGImageMetadataTagCopyNamespace(tag);
        NSString *prefix = (__bridge_transfer NSString *)CGImageMetadataTagCopyPrefix(tag);
        NSString *name = (__bridge_transfer NSString *)CGImageMetadataTagCopyName(tag);
        id inner = (__bridge_transfer id)CGImageMetadataTagCopyValue(tag);
        return [NSString stringWithFormat:@"tag{ns=%@ prefix=%@ name=%@ type=%ld value=%@}", ns, prefix, name,
                                          (long)CGImageMetadataTagGetType(tag), show(inner)];
    }
    if ([value isKindOfClass:[NSString class]])
        return [NSString stringWithFormat:@"str(%@)", value];
    if ([value isKindOfClass:[NSNumber class]])
        return [NSString stringWithFormat:@"num(%g)", [(NSNumber *)value doubleValue]];
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableString *out = [NSMutableString stringWithString:@"arr["];
        for (id element in (NSArray *)value)
            [out appendFormat:@"%@,", show(element)];
        [out appendString:@"]"];
        return out;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSArray *keys = [[(NSDictionary *)value allKeys] sortedArrayUsingSelector:@selector(compare:)];
        NSMutableString *out = [NSMutableString stringWithString:@"dict{"];
        for (id key in keys)
            [out appendFormat:@"%@=%@,", key, show([(NSDictionary *)value objectForKey:key])];
        [out appendString:@"}"];
        return out;
    }
    return [NSString stringWithFormat:@"obj(%@)", [value class]];
}

static NSString *tagline(CGImageMetadataTagRef tag)
{
    if (!tag)
        return @"(nil)";
    NSString *ns = (__bridge_transfer NSString *)CGImageMetadataTagCopyNamespace(tag);
    NSString *prefix = (__bridge_transfer NSString *)CGImageMetadataTagCopyPrefix(tag);
    NSString *name = (__bridge_transfer NSString *)CGImageMetadataTagCopyName(tag);
    id value = (__bridge_transfer id)CGImageMetadataTagCopyValue(tag);
    NSInteger type = (NSInteger)CGImageMetadataTagGetType(tag);
    CFArrayRef qualifiers = CGImageMetadataTagCopyQualifiers(tag);
    NSInteger count = qualifiers ? (NSInteger)CFArrayGetCount(qualifiers) : -1;
    if (qualifiers)
        CFRelease(qualifiers);
    return [NSString stringWithFormat:@"ns=%@ prefix=%@ name=%@ type=%ld value=%@ qualifiers=%ld", ns, prefix, name,
                                      (long)type, show(value), (long)count];
}

static void report(NSString *label, CGImageMetadataTagRef tag)
{
    record([NSString stringWithFormat:@"tag %@", label], tagline(tag));
}

static void reportValue(NSString *label, CGImageMetadataTagRef tag)
{
    id value = tag ? (__bridge_transfer id)CGImageMetadataTagCopyValue(tag) : nil;
    record([NSString stringWithFormat:@"value %@", label], show(value));
}

static void dumpAll(const char *label, CGImageMetadataRef m)
        {
            CFArrayRef tags = CGImageMetadataCopyTags(m);
            NSMutableString *out = [NSMutableString stringWithString:[NSString stringWithFormat:@"%@", @(label)]];
            for (CFIndex i = 0; tags && i < CFArrayGetCount(tags); i++) {
                CGImageMetadataTagRef tag = (CGImageMetadataTagRef)CFArrayGetValueAtIndex(tags, i);
                [out appendFormat:@"|%@", show((__bridge id)tag)];
            }
            record(@"tags", out);
            if (tags)
                CFRelease(tags);
        }

// Put a tag into a tree the way a caller holding XMP would: by its path, after registering the prefix when
// the namespace is not one of the ten ImageIO declares a prefix for. Both builds answer the same question,
// so a difference here is a difference in the library and not in the setup.
static void put(CGImageMetadataRef metadata, CFStringRef ns, CFStringRef prefix, CFStringRef name, CFTypeRef value)
{
    CGImageMetadataRegisterNamespaceForPrefix(metadata, ns, prefix, NULL);
    NSString *path = [NSString stringWithFormat:@"%@:%@", (__bridge NSString *)prefix, (__bridge NSString *)name];
    if (!CGImageMetadataSetValueWithPath(metadata, NULL, (__bridge CFStringRef)path, value))
        record([NSString stringWithFormat:@"PUT FAILED %@", path], @"(no)");
}

// Both functions of the image-property bridge, for one pair: the set direction's answer and the tag it
// leaves behind, the lookup over that tree, and the lookup over an empty one.
static void bridgeCase(CGImageMetadataRef one, CFStringRef dictionary, CFStringRef property)
{
    NSString *label = [NSString stringWithFormat:@"%@/%@", (__bridge NSString *)dictionary,
                                                 (__bridge NSString *)property];
    BOOL ok = CGImageMetadataSetValueMatchingImageProperty(one, dictionary, property, CFSTR("v"));
    record([NSString stringWithFormat:@"set %@", label], ok ? @"true" : @"false");
    dumpAll([NSString stringWithFormat:@"after set %@", label].UTF8String, one);
    report([NSString stringWithFormat:@"lookup set %@", label],
           CGImageMetadataCopyTagMatchingImageProperty(one, dictionary, property));
    CGMutableImageMetadataRef nothing = CGImageMetadataCreateMutable();
    report([NSString stringWithFormat:@"lookup empty %@", label],
           CGImageMetadataCopyTagMatchingImageProperty(nothing, dictionary, property));
    if (nothing)
        CFRelease(nothing);
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);

        // A tag the host's own type identity: an ObjC object of a class of ours is never a CF dictionary,
        // and this harness needs the port binary to be provably running the port's code, not ImageIO's.
#ifdef CHARON_PORT
        {
            struct { const char *name; const void *address; } rows[] = {
                { "CGImageMetadataTagCreate", (const void *)&CGImageMetadataTagCreate },
                { "CGImageMetadataTagCopyName", (const void *)&CGImageMetadataTagCopyName },
                { "CGImageMetadataCreateMutable", (const void *)&CGImageMetadataCreateMutable },
                { "CGImageMetadataCopyTags", (const void *)&CGImageMetadataCopyTags },
            };
            NSMutableString *held = [NSMutableString string];
            for (size_t i = 0; i < sizeof rows / sizeof rows[0]; i++) {
                Dl_info info;
                if (dladdr(rows[i].address, &info) && info.dli_fname &&
                    strstr(info.dli_fname, "ImageIO") == NULL)
                    [held appendFormat:@"%s=port,", rows[i].name];
                else
                    [held appendFormat:@"%s=imageio,", rows[i].name];
            }
            record(@"PORTONLY binding", held);
        }
        // an object that is not this library's must be refused, never read
        {
            NSDictionary *foreign = [NSDictionary dictionary];
            // the inert row, called twice: the line it logs has to appear once, and run.sh counts it in stderr
        CGImageSourceRemoveCacheAtIndex(NULL, 0);
        CGImageSourceRemoveCacheAtIndex(NULL, 1);
        record(@"PORTONLY inert-row", @"called twice");
        record(@"PORTONLY foreign-tag", tagline(CGImageMetadataTagCopyName((__bridge CGImageMetadataTagRef)foreign)));
            record(@"PORTONLY foreign-metadata",
                   CGImageMetadataCopyTags((__bridge CGImageMetadataRef)foreign) ? @"answered" : @"(nil)");
            record(@"PORTONLY foreign-copy",
                   CGImageMetadataCreateMutableCopy((__bridge CGImageMetadataRef)foreign) ? @"answered" : @"(nil)");
            record(@"PORTONLY foreign-copy-string",
                   CGImageMetadataCreateMutableCopy((CGImageMetadataRef)CFSTR("x")) ? @"answered" : @"(nil)");
            // a nonnull the header declares _Nonnull: the host traps on these (measured, SIGTRAP), so
            // there is no host answer to compare and the port's refusal is recorded on its own
            record(@"PORTONLY precondition null-name",
                   CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, NULL, kCGImageMetadataTypeString, CFSTR("v"))
                       ? @"answered"
                       : @"(nil)");
            record(@"PORTONLY precondition null-namespace",
                   CGImageMetadataTagCreate(NULL, CFSTR("mine"), CFSTR("Name"), kCGImageMetadataTypeString, CFSTR("v"))
                       ? @"answered"
                       : @"(nil)");
            record(@"PORTONLY precondition null-value",
                   CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"), kCGImageMetadataTypeString, NULL)
                       ? @"answered"
                       : @"(nil)");
        }
#endif

        record(@"metadata create", CGImageMetadataCreateMutable() ? @"yes" : @"no");
        CGMutableImageMetadataRef empty = CGImageMetadataCreateMutable();
        CFArrayRef noTags = CGImageMetadataCopyTags(empty);
        record(@"metadata empty count", [NSString stringWithFormat:@"%ld", noTags ? (long)CFArrayGetCount(noTags) : -1L]);
        if (noTags)
            CFRelease(noTags);

        record(@"typeid tag nonzero", CGImageMetadataTagGetTypeID() != 0 ? @"yes" : @"no");

        // the default prefix of every public namespace, asked of the host and answered the same way
        struct { const char *label; CFStringRef ns; } namespaces[] = {
            { "exif", kCGImageMetadataNamespaceExif },
            { "exifAux", kCGImageMetadataNamespaceExifAux },
            { "exifEX", kCGImageMetadataNamespaceExifEX },
            { "dc", kCGImageMetadataNamespaceDublinCore },
            { "iptcCore", kCGImageMetadataNamespaceIPTCCore },
            { "iptcExt", kCGImageMetadataNamespaceIPTCExtension },
            { "photoshop", kCGImageMetadataNamespacePhotoshop },
            { "tiff", kCGImageMetadataNamespaceTIFF },
            { "xmp", kCGImageMetadataNamespaceXMPBasic },
            { "xmpRights", kCGImageMetadataNamespaceXMPRights },
        };
        for (size_t i = 0; i < sizeof namespaces / sizeof namespaces[0]; i++) {
            NSString *label = [NSString stringWithFormat:@"default-prefix %@", @(namespaces[i].label)];
            CGImageMetadataTagRef tag = CGImageMetadataTagCreate(namespaces[i].ns, NULL, CFSTR("Name"),
                                                                 kCGImageMetadataTypeDefault, CFSTR("v"));
            NSString *prefix = tag ? (__bridge_transfer NSString *)CGImageMetadataTagCopyPrefix(tag) : nil;
            if (tag)
                CFRelease(tag);
            record(label, prefix ?: @"(nil)");
        }

        report(@"given-prefix", CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, CFSTR("mine"), CFSTR("Name"),
                                                        kCGImageMetadataTypeString, CFSTR("v")));
        report(@"unknown-ns-no-prefix",
               CGImageMetadataTagCreate(CFSTR("not a namespace"), NULL, CFSTR("Name"), kCGImageMetadataTypeString, CFSTR("v")));
        report(@"unknown-ns-prefix",
               CGImageMetadataTagCreate(CFSTR("not a namespace"), CFSTR("mine"), CFSTR("Name"), kCGImageMetadataTypeString,
                                        CFSTR("v")));
        report(@"invalid-type",
               CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"), (CGImageMetadataType)99, CFSTR("v")));

        // kCGImageMetadataTypeDefault reads the type off the CFType of the value
        CGImageMetadataTagRef fromString = CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"),
                                                                    kCGImageMetadataTypeDefault, CFSTR("v"));
        CGImageMetadataTagRef fromNumber = CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"),
                                                                    kCGImageMetadataTypeDefault, (__bridge CFTypeRef)@2);
        CGImageMetadataTagRef fromArray = CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"),
                                                                   kCGImageMetadataTypeDefault,
                                                                   (__bridge CFTypeRef)[NSArray arrayWithObjects:@"a", @"b", nil]);
        CGImageMetadataTagRef fromDictionary =
            CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"), kCGImageMetadataTypeDefault,
                                     (__bridge CFTypeRef)[NSDictionary dictionaryWithObject:@"v" forKey:@"F"]);
        record(@"default string", [NSString stringWithFormat:@"%ld", (long)CGImageMetadataTagGetType(fromString)]);
        record(@"default number", [NSString stringWithFormat:@"%ld", (long)CGImageMetadataTagGetType(fromNumber)]);
        record(@"default array", [NSString stringWithFormat:@"%ld", (long)CGImageMetadataTagGetType(fromArray)]);
        record(@"default dictionary", [NSString stringWithFormat:@"%ld", (long)CGImageMetadataTagGetType(fromDictionary)]);
        reportValue(@"default array elements", fromArray);
        reportValue(@"default dictionary elements", fromDictionary);

        // A NUMBER IS THE STRING XMP SPELLS IT. The records below print the tag's VALUE (tagline() carries
        // it), not only its type, which is what makes this a check and not a type check: a port that keeps
        // the CFNumber answers type=1 here and would answer type=1 on the cases above as well.
        // The spelling follows the number's own CFNumber type, and a number inside an array or inside a
        // structure's fields is NOT spelled - it stays a number (measured: the host's own tag for
        // @[@1, @"two", @2.5] holds a number, a tag and a number).
        {
            struct { const char *label; id value; } scalars[] = {
                { "integer", @3 },
                { "negative", @(-2) },
                { "long-long", @(1234567890123LL) },
                { "double-integral", @3.0 },
                { "double", @1.5 },
                { "small", @0.1 },
                { "bool-yes", @YES },
                { "bool-no", @NO },
            };
            for (size_t i = 0; i < sizeof scalars / sizeof scalars[0]; i++) {
                NSString *label = @(scalars[i].label);
                report([NSString stringWithFormat:@"number tag %@", label],
                       CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("N"),
                                                kCGImageMetadataTypeDefault, (__bridge CFTypeRef)scalars[i].value));
                CGMutableImageMetadataRef pathedNumber = CGImageMetadataCreateMutable();
                CGImageMetadataSetValueWithPath(pathedNumber, NULL, CFSTR("exif:N"),
                                                (__bridge CFTypeRef)scalars[i].value);
                record([NSString stringWithFormat:@"number set %@", label], @"yes");
                report([NSString stringWithFormat:@"number at %@", label],
                       CGImageMetadataCopyTagWithPath(pathedNumber, NULL, CFSTR("exif:N")));
                reportValue([NSString stringWithFormat:@"number value %@", label],
                            CGImageMetadataCopyTagWithPath(pathedNumber, NULL, CFSTR("exif:N")));
                if (pathedNumber)
                    CFRelease(pathedNumber);
            }
            // and the two containers, whose numbers stay numbers
            {
                CGImageMetadataTagRef array = CGImageMetadataTagCreate(
                    kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("N"), kCGImageMetadataTypeDefault,
                    (__bridge CFTypeRef)@[ @1, @"two", @2.5 ]);
                report(@"number in array", array);
                reportValue(@"number in array value", array);
                CGImageMetadataTagRef structure =
                    CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("N"),
                                             kCGImageMetadataTypeDefault,
                                             (__bridge CFTypeRef)@{ @"A" : @1 });
                report(@"number in structure", structure);
                reportValue(@"number in structure value", structure);
                CGMutableImageMetadataRef mixed = CGImageMetadataCreateMutable();
                CGImageMetadataSetValueWithPath(mixed, NULL, CFSTR("exif:N"), (__bridge CFTypeRef)@[ @1, @2 ]);
                report(@"number in path array", CGImageMetadataCopyTagWithPath(mixed, NULL, CFSTR("exif:N")));
                if (mixed)
                    CFRelease(mixed);
            }
        }

        // every declared type, asked of the type getter and answered as a number
        for (int type = 0; type <= 6; type++) {
            CGImageMetadataTagRef tag = CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"),
                                                                 (CGImageMetadataType)type, CFSTR("v"));
            record([NSString stringWithFormat:@"declared type %d", type],
                   [NSString stringWithFormat:@"%ld", (long)CGImageMetadataTagGetType(tag)]);
        }

        // a mutable copy is a different container. Its tags are compared in full once the path API
        // (the next commit of this slice) can put tags into one; until then the empty container is what
        // the copy case says, and it says so in its own name rather than by a comment.
        CGMutableImageMetadataRef source = CGImageMetadataCreateMutable();
        CGMutableImageMetadataRef copy = CGImageMetadataCreateMutableCopy(source);
        record(@"copy of empty", copy ? @"yes" : @"no");
        CFArrayRef sourceTags = CGImageMetadataCopyTags(source);
        CFArrayRef copyTags = CGImageMetadataCopyTags(copy);
        record(@"copy count of empty", [NSString stringWithFormat:@"%ld/%ld", sourceTags ? (long)CFArrayGetCount(sourceTags) : -1L,
                                                                     copyTags ? (long)CFArrayGetCount(copyTags) : -1L]);
        record(@"copy is another container", source == copy ? @"same" : @"different");
        // MARK: paths
        // Every path function is asked of the same paths and the container is printed after each step, so a
        // difference in what a path DID shows up as a difference in what the container then holds, not only
        // in a boolean the caller never checks.
        CGMutableImageMetadataRef pathed = CGImageMetadataCreateMutable();
        struct { const char *label; const char *path; int value; } sets[] = {
            { "string", "exif:Flash", 0 },
            { "number", "tiff:Orientation", 1 },
            { "field", "exif:Flash.Fired", 1 },
            { "array", "dc:subject", 2 },
            { "element", "dc:subject[1]", 3 },
            { "unregistered", "ex:Thing", 0 },
            { "unknown-ns", "nope:Thing", 0 },
            { "no-prefix", "Thing", 0 },
        };
        for (size_t i = 0; i < sizeof sets / sizeof sets[0]; i++) {
            CFStringRef path = CFRetain((__bridge CFStringRef)[NSString stringWithUTF8String:sets[i].path]);
            CFTypeRef value = sets[i].value == 1 ? (__bridge CFTypeRef)@"1"
                             : sets[i].value == 2 ? (__bridge CFTypeRef)[NSArray arrayWithObjects:@"one", @"two", nil]
                                                  : (CFTypeRef)CFSTR("v");
            BOOL ok = CGImageMetadataSetValueWithPath(pathed, NULL, path, value);
            record([NSString stringWithFormat:@"set %@", @(sets[i].label)],
                   [NSString stringWithFormat:@"%d %@", (int)ok, show((__bridge id)value)]);
            dumpAll("after set", pathed);
            CFRelease(path);
        }
        for (size_t i = 0; i < sizeof sets / sizeof sets[0]; i++) {
            CFStringRef path = CFRetain((__bridge CFStringRef)[NSString stringWithUTF8String:sets[i].path]);
            CFStringRef text = CGImageMetadataCopyStringValueWithPath(pathed, NULL, path);
            NSString *answer = text ? (__bridge_transfer NSString *)text : @"(nil)";
            if (text)
                CFRelease(text);
            record([NSString stringWithFormat:@"string %@", @(sets[i].label)], answer);
            CGImageMetadataTagRef tag = CGImageMetadataCopyTagWithPath(pathed, NULL, path);
            record([NSString stringWithFormat:@"tag-at %@", @(sets[i].label)], tagline(tag));
            if (tag)
                CFRelease(tag);
            CFRelease(path);
        }
        // a tag set through the path API, then replaced by SetTagWithPath
        CGImageMetadataTagRef made = CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Made"),
                                                             kCGImageMetadataTypeString, CFSTR("by tag"));
        record(@"set-tag made", CGImageMetadataSetTagWithPath(pathed, NULL, CFSTR("exif:Made"), made) ? @"yes" : @"no");
        dumpAll("after set-tag", pathed);
        record(@"set-tag missing path",
               CGImageMetadataSetTagWithPath(pathed, NULL, CFSTR("nope:Made"), made) ? @"yes" : @"no");
        record(@"set-tag foreign tag",
               CGImageMetadataSetTagWithPath(pathed, NULL, CFSTR("exif:Foreign"), (CGImageMetadataTagRef)(const void *)CFSTR("x"))
                   ? @"yes"
                   : @"no");
        // a parent tag: the header says the children of the parent are modified and have to be committed
        CGImageMetadataTagRef parentTag = CGImageMetadataCopyTagWithPath(pathed, NULL, CFSTR("exif:Flash"));
        record(@"parent found", parentTag ? @"yes" : @"no");
        record(@"set in parent", CGImageMetadataSetValueWithPath(pathed, parentTag, CFSTR("RedEyeMode"), CFSTR("on"))
                                       ? @"yes"
                                       : @"no");
        dumpAll("after set in parent", pathed);
        {
            CFStringRef text = CGImageMetadataCopyStringValueWithPath(pathed, parentTag, CFSTR("RedEyeMode"));
            record(@"parent value", text ? (__bridge_transfer NSString *)text : @"(nil)");
            if (text)
                CFRelease(text);
        }

        record(@"remove present", CGImageMetadataRemoveTagWithPath(pathed, NULL, CFSTR("exif:Made")) ? @"yes" : @"no");
        record(@"remove again", CGImageMetadataRemoveTagWithPath(pathed, NULL, CFSTR("exif:Made")) ? @"yes" : @"no");
        record(@"remove missing ns", CGImageMetadataRemoveTagWithPath(pathed, NULL, CFSTR("nope:Made")) ? @"yes" : @"no");
        dumpAll("after removes", pathed);

        CGMutableImageMetadataRef registered = CGImageMetadataCreateMutable();
        CFErrorRef conflict = NULL;
        record(@"register new", CGImageMetadataRegisterNamespaceForPrefix(registered, CFSTR("http://example.com/ns/"),
                                                                        CFSTR("ex"), NULL)
                                      ? @"yes"
                                      : @"no");
        record(@"register same again",
               CGImageMetadataRegisterNamespaceForPrefix(registered, CFSTR("http://example.com/ns/"), CFSTR("ex"), NULL)
                   ? @"yes"
                   : @"no");
        record(@"register conflict",
               CGImageMetadataRegisterNamespaceForPrefix(registered, CFSTR("http://other.example/"), CFSTR("ex"),
                                                         &conflict)
                   ? @"yes"
                   : @"no");
        record(@"register conflict error", conflict ? @"yes" : @"no");
        if (conflict)
            CFRelease(conflict);
        record(@"set with registered prefix",
               CGImageMetadataSetValueWithPath(registered, NULL, CFSTR("ex:Thing"), CFSTR("v")) ? @"yes" : @"no");
        {
            CFStringRef text = CGImageMetadataCopyStringValueWithPath(registered, NULL, CFSTR("ex:Thing"));
            NSString *answer = text ? (__bridge_transfer NSString *)text : @"(nil)";
            if (text)
                CFRelease(text);
            record(@"string with registered prefix", answer);
        }
        dumpAll("registered", registered);

        // enumeration: the paths the block is given, with and without the recursive option
        NSMutableString *flat = [NSMutableString string];
        CGImageMetadataEnumerateTagsUsingBlock(pathed, NULL, NULL, ^(CFStringRef path, CGImageMetadataTagRef tag) {
            [flat appendFormat:@"%@;", (__bridge NSString *)path];
            return YES;
        });
        record(@"enumerate", flat);
        NSMutableString *deep = [NSMutableString string];
        CGImageMetadataEnumerateTagsUsingBlock(
            pathed, NULL, (__bridge CFDictionaryRef)@{ (__bridge id)kCGImageMetadataEnumerateRecursively : @YES },
            ^(CFStringRef path, CGImageMetadataTagRef tag) {
                [flat class]; // keep the block's captures honest for the compiler
                [deep appendFormat:@"%@;", (__bridge NSString *)path];
                return YES;
            });
        record(@"enumerate recursive", deep);
        NSMutableString *stopped = [NSMutableString string];
        CGImageMetadataEnumerateTagsUsingBlock(pathed, NULL, NULL, ^(CFStringRef path, CGImageMetadataTagRef tag) {
            [stopped appendFormat:@"%@;", (__bridge NSString *)path];
            return NO; // "return false to stop"
        });
        record(@"enumerate stopped", stopped);
        NSMutableString *rooted = [NSMutableString string];
        CGImageMetadataEnumerateTagsUsingBlock(pathed, CFSTR("exif:Flash"), NULL, ^(CFStringRef path, CGImageMetadataTagRef tag) {
            [rooted appendFormat:@"%@;", (__bridge NSString *)path];
            return YES;
        });
        record(@"enumerate rooted", rooted);
        NSMutableString *none = [NSMutableString string];
        CGImageMetadataEnumerateTagsUsingBlock(pathed, CFSTR("nope:Flash"), NULL, ^(CFStringRef path, CGImageMetadataTagRef tag) {
            [none appendString:@"called"];
            return YES;
        });
        record(@"enumerate missing root", none);

        // MARK: the image-property bridge
        // CGImageMetadataCopyTagMatchingImageProperty and CGImageMetadataSetValueMatchingImageProperty over
        // every pair the header declares. 518 pairs, each in a fresh container: the set direction's answer,
        // the tag it wrote, the lookup over that tree and the lookup over an empty one. A pair the host does
        // not map answers false, writes nothing, and answers NULL for the lookup, which is the header's own
        // position as well: not every dictionary and property is supported yet.
        {
            charon_pair pairs[600];
            size_t npairs = charon_pairs(pairs);
            record(@"bridge pairs", [NSString stringWithFormat:@"%lu", (unsigned long)npairs]);
            for (size_t i = 0; i < npairs; i++) {
                CGMutableImageMetadataRef one = CGImageMetadataCreateMutable();
                bridgeCase(one, pairs[i].dictionary, pairs[i].property);
                if (one)
                    CFRelease(one);
            }
        }

        // THE RULES THE TABLE ALONE DOES NOT SAY. Each of these is a pair the table answers, asked of a tree
        // that holds something else as well, because a table that is right and a lookup that matches only
        // names would agree on all 518 above and differ here.
        {
            CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
            // one name, two namespaces: LensSerialNumber is exifEX's for kCGImagePropertyExifLensSerialNumber
            // and aux's for kCGImagePropertyExifAuxLensSerialNumber, so the namespace is part of the match
            put(m, CFSTR("http://cipa.jp/exif/1.0/"), CFSTR("exifEX"), CFSTR("LensSerialNumber"), CFSTR("e"));
            report(@"namespace exifEX asked for ExifAux",
                   CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyExifAuxDictionary,
                                                               kCGImagePropertyExifAuxLensSerialNumber));
            report(@"namespace exifEX asked for Exif",
                   CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifLensSerialNumber));
            if (m)
                CFRelease(m);
            CGMutableImageMetadataRef n = CGImageMetadataCreateMutable();
            put(n, CFSTR("http://ns.adobe.com/exif/1.0/aux/"), CFSTR("aux"), CFSTR("LensSerialNumber"), CFSTR("a"));
            report(@"namespace aux asked for Exif",
                   CGImageMetadataCopyTagMatchingImageProperty(n, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifLensSerialNumber));
            report(@"namespace aux asked for ExifAux",
                   CGImageMetadataCopyTagMatchingImageProperty(n, kCGImagePropertyExifAuxDictionary,
                                                               kCGImagePropertyExifAuxLensSerialNumber));
            if (n)
                CFRelease(n);
            CGMutableImageMetadataRef r = CGImageMetadataCreateMutable();
            put(r, CFSTR("http://ns.adobe.com/xap/1.0/"), CFSTR("xmp"), CFSTR("Rating"), CFSTR("x"));
            report(@"namespace xmp asked for IPTCStarRating",
                   CGImageMetadataCopyTagMatchingImageProperty(r, kCGImagePropertyIPTCDictionary,
                                                               kCGImagePropertyIPTCStarRating));
            report(@"namespace xmp asked for IPTCExtRating",
                   CGImageMetadataCopyTagMatchingImageProperty(r, kCGImagePropertyIPTCDictionary,
                                                               kCGImagePropertyIPTCExtRating));
            if (r)
                CFRelease(r);
            // both of the name: each pair answers its own tag and not the other's
            CGMutableImageMetadataRef both = CGImageMetadataCreateMutable();
            put(both, CFSTR("http://cipa.jp/exif/1.0/"), CFSTR("exifEX"), CFSTR("LensSerialNumber"), CFSTR("e"));
            put(both, CFSTR("http://ns.adobe.com/exif/1.0/aux/"), CFSTR("aux"), CFSTR("LensSerialNumber"), CFSTR("a"));
            report(@"both namespaces asked for Exif",
                   CGImageMetadataCopyTagMatchingImageProperty(both, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifLensSerialNumber));
            report(@"both namespaces asked for ExifAux",
                   CGImageMetadataCopyTagMatchingImageProperty(both, kCGImagePropertyExifAuxDictionary,
                                                               kCGImagePropertyExifAuxLensSerialNumber));
            if (both)
                CFRelease(both);
        }

        // A PROPERTY'S OWN NAME IS NOT ITS TAG: kCGImagePropertyExifDateTimeOriginal maps to
        // photoshop:DateCreated, so a tree holding only exif:DateTimeOriginal answers NULL and a tree
        // holding both answers the mapped one whichever order they went in.
        {
            CGMutableImageMetadataRef own = CGImageMetadataCreateMutable();
            put(own, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("DateTimeOriginal"), CFSTR("e"));
            report(@"own name only",
                   CGImageMetadataCopyTagMatchingImageProperty(own, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifDateTimeOriginal));
            if (own)
                CFRelease(own);
            CGMutableImageMetadataRef mappedFirst = CGImageMetadataCreateMutable();
            put(mappedFirst, kCGImageMetadataNamespacePhotoshop, kCGImageMetadataPrefixPhotoshop, CFSTR("DateCreated"),
                CFSTR("p"));
            put(mappedFirst, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("DateTimeOriginal"),
                CFSTR("e"));
            report(@"mapped then own name",
                   CGImageMetadataCopyTagMatchingImageProperty(mappedFirst, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifDateTimeOriginal));
            if (mappedFirst)
                CFRelease(mappedFirst);
            CGMutableImageMetadataRef ownFirst = CGImageMetadataCreateMutable();
            put(ownFirst, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("DateTimeOriginal"), CFSTR("e"));
            put(ownFirst, kCGImageMetadataNamespacePhotoshop, kCGImageMetadataPrefixPhotoshop, CFSTR("DateCreated"),
                CFSTR("p"));
            report(@"own name then mapped",
                   CGImageMetadataCopyTagMatchingImageProperty(ownFirst, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifDateTimeOriginal));
            if (ownFirst)
                CFRelease(ownFirst);
        }

        // THE TOP LEVEL OF THE TREE, AND NOT INTO IT: a tag inside a structure's fields is not what the
        // lookup answers, for the property's own name and for the name it maps to.
        {
            CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
            CGImageMetadataRegisterNamespaceForPrefix(m, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, NULL);
            CGImageMetadataRegisterNamespaceForPrefix(m, kCGImageMetadataNamespacePhotoshop,
                                                     kCGImageMetadataPrefixPhotoshop, NULL);
            record(@"nested structure put",
                   CGImageMetadataSetValueWithPath(m, NULL, CFSTR("exif:Sub"),
                                                   (__bridge CFTypeRef)@{ @"DateTimeOriginal" : @"v" })
                       ? @"yes"
                       : @"no");
            report(@"nested own name",
                   CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifDateTimeOriginal));
            if (m)
                CFRelease(m);
            CGMutableImageMetadataRef n = CGImageMetadataCreateMutable();
            CGImageMetadataRegisterNamespaceForPrefix(n, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, NULL);
            CGImageMetadataRegisterNamespaceForPrefix(n, kCGImageMetadataNamespacePhotoshop,
                                                     kCGImageMetadataPrefixPhotoshop, NULL);
            record(@"nested mapped name put",
                   CGImageMetadataSetValueWithPath(n, NULL, CFSTR("exif:Sub"),
                                                   (__bridge CFTypeRef)@{ @"DateCreated" : @"v" })
                       ? @"yes"
                       : @"no");
            report(@"nested mapped name",
                   CGImageMetadataCopyTagMatchingImageProperty(n, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifDateTimeOriginal));
            if (n)
                CFRelease(n);
        }

        // THE PREFIX IS NOT PART OF THE MATCH: a tag whose namespace and name are the row's and whose
        // prefix is one a caller registered is still the answer.
        {
            CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
            put(m, CFSTR("http://cipa.jp/exif/1.0/"), CFSTR("charonprobe"), CFSTR("ISOSpeed"), CFSTR("v"));
            report(@"custom prefix mapped namespace",
                   CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifISOSpeed));
            if (m)
                CFRelease(m);
            CGMutableImageMetadataRef n = CGImageMetadataCreateMutable();
            put(n, kCGImageMetadataNamespaceExif, CFSTR("charonprobe"), CFSTR("Flash"), CFSTR("v"));
            report(@"custom prefix exif flash",
                   CGImageMetadataCopyTagMatchingImageProperty(n, kCGImagePropertyExifDictionary,
                                                               kCGImagePropertyExifFlash));
            if (n)
                CFRelease(n);
        }

        // THE VALUE DECIDES THE TYPE OF THE TAG THE SET DIRECTION WRITES, and a second set for the same
        // pair keeps one tag and its second value.
        {
            const char *labels[3] = { "string", "number", "array" };
            for (int v = 0; v < 3; v++) {
                CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
                CFTypeRef value = v == 0 ? CFSTR("v")
                                 : v == 1 ? (__bridge CFTypeRef)@3
                                          : (__bridge CFTypeRef)[NSArray arrayWithObjects:@"one", @"two", nil];
                BOOL ok = CGImageMetadataSetValueMatchingImageProperty(m, kCGImagePropertyExifDictionary,
                                                                       kCGImagePropertyExifISOSpeed, value);
                NSString *label = [NSString stringWithFormat:@"%s", labels[v]];
                record([NSString stringWithFormat:@"value %@ set", label], ok ? @"true" : @"false");
                report([NSString stringWithFormat:@"value %@ tag", label],
                       CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyExifDictionary,
                                                                   kCGImagePropertyExifISOSpeed));
                if (m)
                    CFRelease(m);
            }
            CGMutableImageMetadataRef twice = CGImageMetadataCreateMutable();
            BOOL first = CGImageMetadataSetValueMatchingImageProperty(twice, kCGImagePropertyExifDictionary,
                                                                      kCGImagePropertyExifDateTimeOriginal,
                                                                      CFSTR("one"));
            BOOL second = CGImageMetadataSetValueMatchingImageProperty(twice, kCGImagePropertyExifDictionary,
                                                                       kCGImagePropertyExifDateTimeOriginal,
                                                                       CFSTR("two"));
            record(@"set twice", [NSString stringWithFormat:@"%d %d", (int)first, (int)second]);
            dumpAll(@"after set twice", twice);
            if (twice)
                CFRelease(twice);
        }

        // A DICTIONARY AND A PROPERTY NO HEADER DECLARES, AND A PROPERTY THE HEADER DECLARES AND THE TABLE
        // DOES NOT CARRY: all three are "not supported at this time", and all three write nothing.
        {
            CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
            record(@"no such dictionary set",
                   CGImageMetadataSetValueMatchingImageProperty(m, CFSTR("NoSuchDictionary"),
                                                                kCGImagePropertyTIFFOrientation, CFSTR("v"))
                       ? @"true"
                       : @"false");
            record(@"no such property set",
                   CGImageMetadataSetValueMatchingImageProperty(m, kCGImagePropertyTIFFDictionary, CFSTR("NoSuchProperty"),
                                                                CFSTR("v"))
                       ? @"true"
                       : @"false");
            dumpAll(@"after no such pair", m);
            report(@"no such dictionary lookup",
                   CGImageMetadataCopyTagMatchingImageProperty(m, CFSTR("NoSuchDictionary"),
                                                               kCGImagePropertyTIFFOrientation));
            report(@"no such property lookup",
                   CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyTIFFDictionary, CFSTR("NoSuchProperty")));
            CGMutableImageMetadataRef unmapped = CGImageMetadataCreateMutable();
            put(unmapped, kCGImageMetadataNamespaceExif, kCGImageMetadataPrefixExif, CFSTR("DensityUnit"), CFSTR("d"));
            report(@"unmapped property holding its name",
                   CGImageMetadataCopyTagMatchingImageProperty(unmapped, kCGImagePropertyJFIFDictionary,
                                                               kCGImagePropertyJFIFDensityUnit));
            record(@"unmapped property set",
                   CGImageMetadataSetValueMatchingImageProperty(unmapped, kCGImagePropertyJFIFDictionary,
                                                                kCGImagePropertyJFIFDensityUnit, CFSTR("v"))
                       ? @"true"
                       : @"false");
            dumpAll(@"after unmapped property", unmapped);
            if (m)
                CFRelease(m);
            if (unmapped)
                CFRelease(unmapped);
        }

        // A container that is not this library's, and the _Nonnull arguments the host traps on: both are the
        // port's own guards, so they are recorded on their own and dropped from the comparison.
#ifdef CHARON_PORT
        record(@"PORTONLY bridge foreign metadata",
               CGImageMetadataSetValueMatchingImageProperty((__bridge CGMutableImageMetadataRef)
                                                                [NSDictionary dictionary],
                                                            kCGImagePropertyTIFFDictionary,
                                                            kCGImagePropertyTIFFOrientation, CFSTR("v"))
                   ? @"true"
                   : @"false");
        record(@"PORTONLY bridge foreign copy",
               CGImageMetadataCopyTagMatchingImageProperty((__bridge CGImageMetadataRef)[NSDictionary dictionary],
                                                           kCGImagePropertyTIFFDictionary,
                                                           kCGImagePropertyTIFFOrientation)
                   ? @"answered"
                   : @"(nil)");
        record(@"PORTONLY bridge null value",
               CGImageMetadataSetValueMatchingImageProperty(CGImageMetadataCreateMutable(),
                                                            kCGImagePropertyTIFFDictionary,
                                                            kCGImagePropertyTIFFOrientation, NULL)
                   ? @"true"
                   : @"false");
        record(@"PORTONLY bridge null dictionary",
               CGImageMetadataSetValueMatchingImageProperty(CGImageMetadataCreateMutable(), NULL,
                                                            kCGImagePropertyTIFFOrientation, CFSTR("v"))
                   ? @"true"
                   : @"false");
        record(@"PORTONLY bridge null property copy",
               CGImageMetadataCopyTagMatchingImageProperty(CGImageMetadataCreateMutable(),
                                                           kCGImagePropertyTIFFDictionary, NULL)
                   ? @"answered"
                   : @"(nil)");
#endif

        if (sourceTags)
            CFRelease(sourceTags);
        if (copyTags)
            CFRelease(copyTags);
        return 0;
    }
}