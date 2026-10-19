#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#include <dlfcn.h>

#include "property-pairs-all.h"

static void record(NSString *name, NSString *answer)
{
    printf("%s\t%s\n", name.UTF8String, answer.UTF8String);
}

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

static void put(CGImageMetadataRef metadata, CFStringRef ns, CFStringRef prefix, CFStringRef name, CFTypeRef value)
{
    CGImageMetadataRegisterNamespaceForPrefix(metadata, ns, prefix, NULL);
    NSString *path = [NSString stringWithFormat:@"%@:%@", (__bridge NSString *)prefix, (__bridge NSString *)name];
    if (!CGImageMetadataSetValueWithPath(metadata, NULL, (__bridge CFStringRef)path, value))
        record([NSString stringWithFormat:@"PUT FAILED %@", path], @"(no)");
}

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
        {
            NSDictionary *foreign = [NSDictionary dictionary];
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

        for (int type = 0; type <= 6; type++) {
            CGImageMetadataTagRef tag = CGImageMetadataTagCreate(kCGImageMetadataNamespaceExif, NULL, CFSTR("Name"),
                                                                 (CGImageMetadataType)type, CFSTR("v"));
            record([NSString stringWithFormat:@"declared type %d", type],
                   [NSString stringWithFormat:@"%ld", (long)CGImageMetadataTagGetType(tag)]);
        }

        CGMutableImageMetadataRef source = CGImageMetadataCreateMutable();
        CGMutableImageMetadataRef copy = CGImageMetadataCreateMutableCopy(source);
        record(@"copy of empty", copy ? @"yes" : @"no");
        CFArrayRef sourceTags = CGImageMetadataCopyTags(source);
        CFArrayRef copyTags = CGImageMetadataCopyTags(copy);
        record(@"copy count of empty", [NSString stringWithFormat:@"%ld/%ld", sourceTags ? (long)CFArrayGetCount(sourceTags) : -1L,
                                                                     copyTags ? (long)CFArrayGetCount(copyTags) : -1L]);
        record(@"copy is another container", source == copy ? @"same" : @"different");
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
                [flat class];
                [deep appendFormat:@"%@;", (__bridge NSString *)path];
                return YES;
            });
        record(@"enumerate recursive", deep);
        NSMutableString *stopped = [NSMutableString string];
        CGImageMetadataEnumerateTagsUsingBlock(pathed, NULL, NULL, ^(CFStringRef path, CGImageMetadataTagRef tag) {
            [stopped appendFormat:@"%@;", (__bridge NSString *)path];
            return NO;
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

        {
            CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
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
