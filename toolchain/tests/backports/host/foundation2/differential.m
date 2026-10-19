#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "foundation2-cases.h"

void host_attach_prefixed(const char *prefix);

extern CFTypeRef RevenantHostCFAutorelease(CFTypeRef);
extern NSString * const RevenantHostNSKeyedArchiveRootObjectKey;
extern NSString * const RevenantHostNSProgressEstimatedTimeRemainingKey;
extern NSString * const RevenantHostNSProgressFileOperationKindReceiving;
extern NSString * const RevenantHostNSProgressFileOperationKindUploading;
extern NSString * const RevenantHostNSURLUbiquitousItemDownloadingStatusKey;
extern NSString * const RevenantHostNSURLUbiquitousItemDownloadingErrorKey;
extern NSString * const RevenantHostNSURLUbiquitousItemUploadingErrorKey;
extern NSString * const RevenantHostNSURLUbiquitousItemDownloadingStatusNotDownloaded;
extern NSString * const RevenantHostNSURLUbiquitousItemDownloadingStatusDownloaded;
extern NSString * const RevenantHostNSURLUbiquitousItemDownloadingStatusCurrent;
extern NSString * const RevenantHostNSStringTransformLatinToKatakana;
extern NSString * const RevenantHostNSStringTransformLatinToHiragana;
extern NSString * const RevenantHostNSStringTransformLatinToHangul;
extern NSString * const RevenantHostNSStringTransformLatinToArabic;
extern NSString * const RevenantHostNSStringTransformLatinToHebrew;
extern NSString * const RevenantHostNSStringTransformLatinToThai;
extern NSString * const RevenantHostNSStringTransformLatinToCyrillic;
extern NSString * const RevenantHostNSStringTransformLatinToGreek;
extern NSString * const RevenantHostNSStringTransformToLatin;
extern NSString * const RevenantHostNSStringTransformMandarinToLatin;
extern NSString * const RevenantHostNSStringTransformHiraganaToKatakana;
extern NSString * const RevenantHostNSStringTransformFullwidthToHalfwidth;
extern NSString * const RevenantHostNSStringTransformToXMLHex;
extern NSString * const RevenantHostNSStringTransformToUnicodeName;
extern NSString * const RevenantHostNSStringTransformStripCombiningMarks;
extern NSString * const RevenantHostNSStringTransformStripDiacritics;

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
        Foundation2Implementation revenant = {
            .prefix = @"revenantHost_",
            .autorelease = RevenantHostCFAutorelease,
            .rootObjectKey = RevenantHostNSKeyedArchiveRootObjectKey,
            .ubiquityKeys = @[RevenantHostNSURLUbiquitousItemDownloadingStatusKey, RevenantHostNSURLUbiquitousItemDownloadingErrorKey, RevenantHostNSURLUbiquitousItemUploadingErrorKey,
                              RevenantHostNSURLUbiquitousItemDownloadingStatusNotDownloaded, RevenantHostNSURLUbiquitousItemDownloadingStatusDownloaded, RevenantHostNSURLUbiquitousItemDownloadingStatusCurrent],
            .transformNames = @[RevenantHostNSStringTransformLatinToKatakana, RevenantHostNSStringTransformLatinToHiragana, RevenantHostNSStringTransformLatinToHangul, RevenantHostNSStringTransformLatinToArabic,
                                RevenantHostNSStringTransformLatinToHebrew, RevenantHostNSStringTransformLatinToThai, RevenantHostNSStringTransformLatinToCyrillic, RevenantHostNSStringTransformLatinToGreek,
                                RevenantHostNSStringTransformToLatin, RevenantHostNSStringTransformMandarinToLatin, RevenantHostNSStringTransformHiraganaToKatakana,
                                RevenantHostNSStringTransformFullwidthToHalfwidth, RevenantHostNSStringTransformToXMLHex, RevenantHostNSStringTransformToUnicodeName,
                                RevenantHostNSStringTransformStripCombiningMarks, RevenantHostNSStringTransformStripDiacritics],
            .progressConstants = @[RevenantHostNSProgressEstimatedTimeRemainingKey, RevenantHostNSProgressFileOperationKindReceiving, RevenantHostNSProgressFileOperationKindUploading],
            .queryItemClass = NSClassFromString(@"RevenantHostNSURLQueryItem")
        };
        Foundation2Recorder *theirs = [[Foundation2Recorder alloc] init];
        Foundation2Recorder *mine = [[Foundation2Recorder alloc] init];
        foundation2_run(system, theirs);
        foundation2_run(revenant, mine);
        NSOperatingSystemVersion hostVersion = [NSProcessInfo processInfo].operatingSystemVersion;
        NSOperatingSystemVersion revenantVersion = ((NSOperatingSystemVersion (*)(id, SEL))objc_msgSend)([NSProcessInfo processInfo], NSSelectorFromString(@"revenantHost_operatingSystemVersion"));
        check(hostVersion.majorVersion == revenantVersion.majorVersion && hostVersion.minorVersion == revenantVersion.minorVersion && hostVersion.patchVersion == revenantVersion.patchVersion,
              @"processInfo.version", [NSString stringWithFormat:@"%ld.%ld.%ld != %ld.%ld.%ld", (long)revenantVersion.majorVersion, (long)revenantVersion.minorVersion, (long)revenantVersion.patchVersion,
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
