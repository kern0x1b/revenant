#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "foundation2-cases.h"

void host_attach_prefixed(const char *prefix);

extern CFTypeRef CharonHostCFAutorelease(CFTypeRef);
extern NSString * const CharonHostNSKeyedArchiveRootObjectKey;
extern NSString * const CharonHostNSProgressEstimatedTimeRemainingKey;
extern NSString * const CharonHostNSProgressFileOperationKindReceiving;
extern NSString * const CharonHostNSProgressFileOperationKindUploading;
extern NSString * const CharonHostNSURLUbiquitousItemDownloadingStatusKey;
extern NSString * const CharonHostNSURLUbiquitousItemDownloadingErrorKey;
extern NSString * const CharonHostNSURLUbiquitousItemUploadingErrorKey;
extern NSString * const CharonHostNSURLUbiquitousItemDownloadingStatusNotDownloaded;
extern NSString * const CharonHostNSURLUbiquitousItemDownloadingStatusDownloaded;
extern NSString * const CharonHostNSURLUbiquitousItemDownloadingStatusCurrent;
extern NSString * const CharonHostNSStringTransformLatinToKatakana;
extern NSString * const CharonHostNSStringTransformLatinToHiragana;
extern NSString * const CharonHostNSStringTransformLatinToHangul;
extern NSString * const CharonHostNSStringTransformLatinToArabic;
extern NSString * const CharonHostNSStringTransformLatinToHebrew;
extern NSString * const CharonHostNSStringTransformLatinToThai;
extern NSString * const CharonHostNSStringTransformLatinToCyrillic;
extern NSString * const CharonHostNSStringTransformLatinToGreek;
extern NSString * const CharonHostNSStringTransformToLatin;
extern NSString * const CharonHostNSStringTransformMandarinToLatin;
extern NSString * const CharonHostNSStringTransformHiraganaToKatakana;
extern NSString * const CharonHostNSStringTransformFullwidthToHalfwidth;
extern NSString * const CharonHostNSStringTransformToXMLHex;
extern NSString * const CharonHostNSStringTransformToUnicodeName;
extern NSString * const CharonHostNSStringTransformStripCombiningMarks;
extern NSString * const CharonHostNSStringTransformStripDiacritics;

static int failures;
static int checks;

static void check(BOOL passed, NSString *name, NSString *detail)
{
    checks++;
    if (!passed) {
        failures++;
        printf("FAIL %s: %s\n", name.UTF8String, detail.UTF8String);
    }
}

static NSString *text(id value)
{
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[value] options:0 error:NULL];
    return json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [value description];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s expectations.json\n", argv[0]);
            return 2;
        }
        host_attach_prefixed("");
        Foundation2Implementation system = {
            .prefix = @"",
            .autorelease = CFAutorelease,
            .rootObjectKey = NSKeyedArchiveRootObjectKey,
            .ubiquityKeys = @[NSURLUbiquitousItemDownloadingStatusKey, NSURLUbiquitousItemDownloadingErrorKey, NSURLUbiquitousItemUploadingErrorKey,
                              NSURLUbiquitousItemDownloadingStatusNotDownloaded, NSURLUbiquitousItemDownloadingStatusDownloaded, NSURLUbiquitousItemDownloadingStatusCurrent],
            .transformNames = @[NSStringTransformLatinToKatakana, NSStringTransformLatinToHiragana, NSStringTransformLatinToHangul, NSStringTransformLatinToArabic, NSStringTransformLatinToHebrew,
                                NSStringTransformLatinToThai, NSStringTransformLatinToCyrillic, NSStringTransformLatinToGreek, NSStringTransformToLatin, NSStringTransformMandarinToLatin,
                                NSStringTransformHiraganaToKatakana, NSStringTransformFullwidthToHalfwidth, NSStringTransformToXMLHex, NSStringTransformToUnicodeName,
                                NSStringTransformStripCombiningMarks, NSStringTransformStripDiacritics],
            .progressConstants = @[NSProgressEstimatedTimeRemainingKey, NSProgressFileOperationKindReceiving, NSProgressFileOperationKindUploading],
            .queryItemClass = [NSURLQueryItem class]
        };
        Foundation2Implementation charon = {
            .prefix = @"charonHost_",
            .autorelease = CharonHostCFAutorelease,
            .rootObjectKey = CharonHostNSKeyedArchiveRootObjectKey,
            .ubiquityKeys = @[CharonHostNSURLUbiquitousItemDownloadingStatusKey, CharonHostNSURLUbiquitousItemDownloadingErrorKey, CharonHostNSURLUbiquitousItemUploadingErrorKey,
                              CharonHostNSURLUbiquitousItemDownloadingStatusNotDownloaded, CharonHostNSURLUbiquitousItemDownloadingStatusDownloaded, CharonHostNSURLUbiquitousItemDownloadingStatusCurrent],
            .transformNames = @[CharonHostNSStringTransformLatinToKatakana, CharonHostNSStringTransformLatinToHiragana, CharonHostNSStringTransformLatinToHangul, CharonHostNSStringTransformLatinToArabic,
                                CharonHostNSStringTransformLatinToHebrew, CharonHostNSStringTransformLatinToThai, CharonHostNSStringTransformLatinToCyrillic, CharonHostNSStringTransformLatinToGreek,
                                CharonHostNSStringTransformToLatin, CharonHostNSStringTransformMandarinToLatin, CharonHostNSStringTransformHiraganaToKatakana,
                                CharonHostNSStringTransformFullwidthToHalfwidth, CharonHostNSStringTransformToXMLHex, CharonHostNSStringTransformToUnicodeName,
                                CharonHostNSStringTransformStripCombiningMarks, CharonHostNSStringTransformStripDiacritics],
            .progressConstants = @[CharonHostNSProgressEstimatedTimeRemainingKey, CharonHostNSProgressFileOperationKindReceiving, CharonHostNSProgressFileOperationKindUploading],
            .queryItemClass = NSClassFromString(@"CharonHostNSURLQueryItem")
        };
        Foundation2Recorder *theirs = [[Foundation2Recorder alloc] init];
        Foundation2Recorder *mine = [[Foundation2Recorder alloc] init];
        foundation2_run(system, theirs);
        foundation2_run(charon, mine);
        NSOperatingSystemVersion hostVersion = [NSProcessInfo processInfo].operatingSystemVersion;
        NSOperatingSystemVersion charonVersion = ((NSOperatingSystemVersion (*)(id, SEL))objc_msgSend)([NSProcessInfo processInfo], NSSelectorFromString(@"charonHost_operatingSystemVersion"));
        check(hostVersion.majorVersion == charonVersion.majorVersion && hostVersion.minorVersion == charonVersion.minorVersion && hostVersion.patchVersion == charonVersion.patchVersion,
              @"processInfo.version", [NSString stringWithFormat:@"%ld.%ld.%ld != %ld.%ld.%ld", (long)charonVersion.majorVersion, (long)charonVersion.minorVersion, (long)charonVersion.patchVersion,
                                       (long)hostVersion.majorVersion, (long)hostVersion.minorVersion, (long)hostVersion.patchVersion]);
        NSCountedSet *tolerated = [NSCountedSet set];
        NSMutableDictionary *examples = [NSMutableDictionary dictionary];
        NSSet *names = [[NSSet setWithArray:theirs.records.allKeys] setByAddingObjectsFromArray:mine.records.allKeys];
        for (NSString *name in [names.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
            id expected = theirs.records[name], actual = mine.records[name];
            NSString *divergence = mine.tolerated[name];
            if ([expected isEqual:actual]) {
                check(YES, name, nil);
                continue;
            }
            if (divergence && expected && actual) {
                [tolerated addObject:divergence];
                if ([tolerated countForObject:divergence] <= 5)
                    examples[divergence] = [examples[divergence] ?: @"" stringByAppendingFormat:@"\n    %@: macOS %@, backport %@", name, text(expected), text(actual)];
                continue;
            }
            check(NO, name, [NSString stringWithFormat:@"backport %@ != macOS %@", text(actual ?: @"<missing>"), text(expected ?: @"<missing>")]);
        }
        for (NSString *divergence in tolerated)
            printf("tolerated %lu: %s%s\n", (unsigned long)[tolerated countForObject:divergence], divergence.UTF8String, [examples[divergence] UTF8String]);
        NSDictionary *expectations = @{@"records": mine.records, @"tolerated": mine.tolerated};
        NSData *json = [NSJSONSerialization dataWithJSONObject:expectations options:NSJSONWritingSortedKeys error:NULL];
        if (![json writeToFile:@(argv[1]) atomically:YES]) {
            fprintf(stderr, "cannot write %s\n", argv[1]);
            return 2;
        }
        printf("records=%lu checks=%d failures=%d\n", (unsigned long)mine.records.count, checks, failures);
    }
    return failures;
}
