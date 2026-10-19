#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTag.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <stdio.h>

// Every CMTag function the port's object defines, against the host's own. The object is reached through
// dlopen, so the port keeps Apple's names and no system header is touched.
//
// Seven of CMTag's 25 are CF_INLINE in 26.2's header and the port's header carries those bodies, so
// the image exports no symbol for them and there is nothing to compare - the same reason a value the
// header carries needs no registry row. They are: CMTagIsValid, CMTagGetCategory, CMTagGetValue,
// CMTagGetValueDataType, CMTagHasCategory, CMTagCategoryEqualToTagCategory, CMTagCategoryValueEqualToValue.
static int failures, checks;
static void *port;

#define BIND(name) __typeof__(&name) port_##name = (__typeof__(&name))dlsym(port, #name); \
    if (!port_##name) { printf("missing %s in the port image\n", #name); return 1; }

static CMTag tag(CMTagCategory c, CMTagDataType d, uint64_t v) { CMTag m = {c, d, v}; return m; }
static void same(const char *name, NSString *system, NSString *ported)
{
    checks++;
    if (![system isEqualToString:ported]) {
        failures++;
        if (failures < 25)
            printf("DIFFERENT %s:\n  system %s\n  port   %s\n", name, system.UTF8String, ported.UTF8String);
    }
}
static NSString *fields(CMTag t)
{
    return [NSString stringWithFormat:@"%d/%u/%llu", (int)t.category, (unsigned)t.dataType, (unsigned long long)t.value];
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        port = dlopen(argc > 1 ? argv[1] : "libCharonCMTag.dylib", RTLD_LOCAL | RTLD_FIRST);
        if (!port) { printf("dlopen: %s\n", dlerror()); return 1; }
        BIND(CMTagMakeWithOSTypeValue) BIND(CMTagMakeWithSInt64Value) BIND(CMTagMakeWithFlagsValue)
        BIND(CMTagMakeWithFloat64Value) BIND(CMTagGetOSTypeValue) BIND(CMTagGetSInt64Value)
        BIND(CMTagGetFlagsValue) BIND(CMTagGetFloat64Value) BIND(CMTagEqualToTag)
        BIND(CMTagHasOSTypeValue) BIND(CMTagHasSInt64Value) BIND(CMTagHasFlagsValue)
        BIND(CMTagHasFloat64Value) BIND(CMTagCompare) BIND(CMTagHash) BIND(CMTagCopyAsDictionary)
        BIND(CMTagMakeFromDictionary) BIND(CMTagCopyDescription)

        CMTag all[] = {
            tag(kCMTagCategory_MediaType, kCMTagDataType_OSType, 'vide'),
            tag(kCMTagCategory_TrackID, kCMTagDataType_SInt64, 7),
            tag(kCMTagCategory_PixelFormat, kCMTagDataType_Flags, 3),
            tag(kCMTagCategory_TrackID, kCMTagDataType_Float64, 0x3FF8000000000000ULL),
            kCMTagInvalid,
            tag(kCMTagCategory_Undefined, kCMTagDataType_Invalid, 0),
            CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 0.0),
            CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, -0.5),
            tag(0, kCMTagDataType_OSType, 0),
            tag(0, kCMTagDataType_SInt64, -1),
            tag(2147483647, kCMTagDataType_SInt64, 18446744073709551615ULL),
            tag(kCMTagCategory_StereoViewInterpretation, kCMTagDataType_OSType, 'lfrt'),
            // The tags the two subtlest rules were derived from, which this probe did not have and should
            // have: without them CMTagCompare's NaN tie and its int64's unsigned order are never reached,
            // and both mutants of them stay green. All four share one category and data type with the
            // tags above, so the value is what gets compared.
            tag(kCMTagCategory_TrackID, kCMTagDataType_Float64, 0xBFE0000000000000ULL),
            tag(kCMTagCategory_TrackID, kCMTagDataType_Float64, 0x8000000000000000ULL),
            tag(kCMTagCategory_TrackID, kCMTagDataType_Float64, 0x7FF8000000000000ULL),
            tag(kCMTagCategory_TrackID, kCMTagDataType_SInt64, 0xFFFFFFFFFFFFFFFFULL),
        };
        size_t count = sizeof all / sizeof *all;
        for (size_t index = 0; index < count; index++)
            printf("  tag %2zu is %d/%u/0x%016llx\n", index, (int)all[index].category, (unsigned)all[index].dataType,
                   (unsigned long long)all[index].value);
        fflush(stdout);

        same("MakeWithOSTypeValue", fields(CMTagMakeWithOSTypeValue(kCMTagCategory_MediaType, 'vide')),
             fields(port_CMTagMakeWithOSTypeValue(kCMTagCategory_MediaType, 'vide')));
        same("MakeWithSInt64Value 7", fields(CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, 7)),
             fields(port_CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, 7)));
        same("MakeWithSInt64Value -1", fields(CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, -1)),
             fields(port_CMTagMakeWithSInt64Value(kCMTagCategory_TrackID, -1)));
        same("MakeWithFlagsValue", fields(CMTagMakeWithFlagsValue(kCMTagCategory_PixelFormat, 3)),
             fields(port_CMTagMakeWithFlagsValue(kCMTagCategory_PixelFormat, 3)));
        same("MakeWithFloat64Value 1.5", fields(CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 1.5)),
             fields(port_CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 1.5)));
        same("MakeWithFloat64Value zero", fields(CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 0.0)),
             fields(port_CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, 0.0)));
        same("MakeWithFloat64Value -0.5", fields(CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, -0.5)),
             fields(port_CMTagMakeWithFloat64Value(kCMTagCategory_TrackID, -0.5)));

        char label[80];
        for (size_t index = 0; index < count; index++) {
            CMTag one = all[index];
            snprintf(label, sizeof label, "GetOSTypeValue %zu", index);
            same(label, [NSString stringWithFormat:@"%u", (unsigned)CMTagGetOSTypeValue(one)],
                 [NSString stringWithFormat:@"%u", (unsigned)port_CMTagGetOSTypeValue(one)]);
            snprintf(label, sizeof label, "GetSInt64Value %zu", index);
            same(label, [NSString stringWithFormat:@"%lld", (long long)CMTagGetSInt64Value(one)],
                 [NSString stringWithFormat:@"%lld", (long long)port_CMTagGetSInt64Value(one)]);
            snprintf(label, sizeof label, "GetFlagsValue %zu", index);
            same(label, [NSString stringWithFormat:@"%llu", (unsigned long long)CMTagGetFlagsValue(one)],
                 [NSString stringWithFormat:@"%llu", (unsigned long long)port_CMTagGetFlagsValue(one)]);
            snprintf(label, sizeof label, "GetFloat64Value %zu", index);
            same(label, [NSString stringWithFormat:@"%.17g", CMTagGetFloat64Value(one)],
                 [NSString stringWithFormat:@"%.17g", port_CMTagGetFloat64Value(one)]);
            snprintf(label, sizeof label, "HasOSType %zu HasSInt64 %zu HasFlags %zu HasFloat %zu", index, index, index, index);
            same(label, [NSString stringWithFormat:@"%d %d %d %d", CMTagHasOSTypeValue(one), CMTagHasSInt64Value(one),
                          CMTagHasFlagsValue(one), CMTagHasFloat64Value(one)],
                 [NSString stringWithFormat:@"%d %d %d %d", port_CMTagHasOSTypeValue(one), port_CMTagHasSInt64Value(one),
                  port_CMTagHasFlagsValue(one), port_CMTagHasFloat64Value(one)]);
            // CMTagHash is a *consistent* hash, not the host's mixing: the host's values are about forty
            // bits (242338807774 for kCMTagInvalid, 930911443662 for the 'vide' tag) and the port's are a
            // CFHash of the three decimal fields, 11562196563089929323 for the same tag. What matters and
            // is measured below: equal tags hash equal and distinct tags do not collide. The difference
            // from the host is recorded in facts/CoreMedia/CMTag.md, as -12894 is.
            snprintf(label, sizeof label, "Hash consistent %zu", index);
            CFHashCode myHash = port_CMTagHash(one);
            BOOL collision = NO, equalSeen = NO;
            for (size_t seen = 0; seen < count; seen++) {
                if ([fields(all[seen]) isEqualToString:fields(one)]) {
                    equalSeen = YES;
                    if (port_CMTagHash(all[seen]) != myHash)
                        collision = YES;   // the same tag hashed two ways
                } else if (port_CMTagHash(all[seen]) == myHash) {
                    collision = YES;       // two different tags, one hash
                }
            }
            (void)equalSeen;
            same(label, [NSString stringWithFormat:@"%d", collision ? 1 : 0], @"0");
            for (size_t other = 0; other < count; other++) {
                snprintf(label, sizeof label, "Compare %zu vs %zu", index, other);
                // The one pair the fitter's candidates cannot explain: print the sixteen bytes of each
                // argument, and the order the call is made in, so the table can be asked about the
                // same bytes rather than about tags either side retyped.
                if (index == 3 && other == 7) {
                    for (int side = 0; side < 2; side++) {
                        CMTag which = side ? all[other] : one;
                        printf("  compare arg %d of all[%zu] vs all[%zu]:", side, index, other);
                        for (size_t byte = 0; byte < sizeof(CMTag); byte++)
                            printf(" %02x", ((const unsigned char *)&which)[byte]);
                        printf("\n");
                    }
                    printf("  the call is CMTagCompare(all[%zu], all[%zu]) and the port's the same way\n", index, other);
                    fflush(stdout);
                }
                same(label, [NSString stringWithFormat:@"%ld", (long)CMTagCompare(one, all[other])],
                     [NSString stringWithFormat:@"%ld", (long)port_CMTagCompare(one, all[other])]);
                snprintf(label, sizeof label, "Equal %zu vs %zu", index, other);
                same(label, [NSString stringWithFormat:@"%d", CMTagEqualToTag(one, all[other]) ? 1 : 0],
                     [NSString stringWithFormat:@"%d", port_CMTagEqualToTag(one, all[other]) ? 1 : 0]);
            }
            CFStringRef theirText = CMTagCopyDescription(NULL, one);
            CFStringRef myText = port_CMTagCopyDescription(NULL, one);
            snprintf(label, sizeof label, "CopyDescription %zu", index);
            same(label, theirText ? (__bridge NSString *)theirText : @"(null)", myText ? (__bridge NSString *)myText : @"(null)");
            CFDictionaryRef theirDict = CMTagCopyAsDictionary(one, NULL);
            CFDictionaryRef myDict = port_CMTagCopyAsDictionary(one, NULL);
            snprintf(label, sizeof label, "CopyAsDictionary %zu", index);
            same(label, theirDict ? [(__bridge NSDictionary *)theirDict description] : @"(null)",
                 myDict ? [(__bridge NSDictionary *)myDict description] : @"(null)");
            snprintf(label, sizeof label, "MakeFromDictionary %zu", index);
            same(label, fields(CMTagMakeFromDictionary(theirDict)), fields(port_CMTagMakeFromDictionary(myDict)));
        }
        same("MakeFromDictionary not a dictionary", fields(CMTagMakeFromDictionary((CFDictionaryRef)@"no")),
             fields(port_CMTagMakeFromDictionary((CFDictionaryRef)@"no")));
        same("MakeFromDictionary empty", fields(CMTagMakeFromDictionary((CFDictionaryRef)@{})),
             fields(port_CMTagMakeFromDictionary((CFDictionaryRef)@{})));
        printf("%d checks, %d different\n", checks, failures);
    }
    return failures != 0;
}
