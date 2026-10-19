#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"
#import "foundation2-cases.h"
#import "foundation2-expectations.h"

@interface NSData (Foundation2Legacy)
- (NSString *)base64Encoding;
- (id)initWithBase64Encoding:(NSString *)string;
@end

static NSString *image_of_pointer(void *pointer)
{
    Dl_info info;
    if (!pointer || !dladdr(pointer, &info) || !info.dli_fname)
        return @"?";
    return @(info.dli_fname).lastPathComponent;
}

static NSString *image_of_method(Class class, SEL selector, BOOL classMethod)
{
    Method method = classMethod ? class_getClassMethod(class, selector) : class_getInstanceMethod(class, selector);
    return method ? image_of_pointer(method_getImplementation(method)) : @"<missing>";
}

static NSString *text(id value)
{
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[value ?: @"<missing>"] options:0 error:NULL];
    return json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : [value description];
}

static void check_sources(void)
{
    NSString *library = @"libFoundationBackports.dylib";
    NSArray *instance = @[@[@"NSData", @"base64EncodedStringWithOptions:"], @[@"NSData", @"base64EncodedDataWithOptions:"], @[@"NSData", @"initWithBase64EncodedString:options:"],
                          @[@"NSData", @"initWithBase64EncodedData:options:"], @[@"NSData", @"enumerateByteRangesUsingBlock:"], @[@"NSData", @"initWithBytesNoCopy:length:deallocator:"],
                          @[@"NSIndexPath", @"getIndexes:range:"], @[@"NSURL", @"initFileURLWithFileSystemRepresentation:isDirectory:relativeToURL:"], @[@"NSURL", @"fileSystemRepresentation"],
                          @[@"NSURL", @"getFileSystemRepresentation:maxLength:"], @[@"NSURL", @"setTemporaryResourceValue:forKey:"], @[@"NSURL", @"removeCachedResourceValueForKey:"],
                          @[@"NSURL", @"removeAllCachedResourceValues"], @[@"NSProcessInfo", @"operatingSystemVersion"], @[@"NSProcessInfo", @"isOperatingSystemAtLeastVersion:"],
                          @[@"NSProcessInfo", @"beginActivityWithOptions:reason:"], @[@"NSProcessInfo", @"endActivity:"], @[@"NSProcessInfo", @"performActivityWithOptions:reason:usingBlock:"],
                          @[@"NSString", @"localizedUppercaseString"], @[@"NSString", @"localizedLowercaseString"], @[@"NSString", @"localizedCapitalizedString"],
                          @[@"NSString", @"localizedStandardContainsString:"], @[@"NSString", @"localizedStandardRangeOfString:"], @[@"NSString", @"stringByApplyingTransform:reverse:"],
                          @[@"NSMutableString", @"applyTransform:reverse:range:updatedRange:"],
                          @[@"NSProgress", @"performAsCurrentWithPendingUnitCount:usingBlock:"], @[@"NSProgress", @"isFinished"], @[@"NSProgress", @"cancellationHandler"],
                          @[@"NSProgress", @"pausingHandler"], @[@"NSProgress", @"estimatedTimeRemaining"], @[@"NSProgress", @"setEstimatedTimeRemaining:"],
                          @[@"NSProgress", @"throughput"], @[@"NSProgress", @"setThroughput:"], @[@"NSProgress", @"fileOperationKind"], @[@"NSProgress", @"setFileOperationKind:"],
                          @[@"NSProgress", @"fileURL"], @[@"NSProgress", @"setFileURL:"], @[@"NSProgress", @"fileTotalCount"], @[@"NSProgress", @"setFileTotalCount:"],
                          @[@"NSProgress", @"fileCompletedCount"], @[@"NSProgress", @"setFileCompletedCount:"]];
    for (NSArray *pair in instance) {
        NSString *name = [NSString stringWithFormat:@"-[%@ %@] comes from the backports", pair[0], pair[1]];
        CHECK_EQUAL(image_of_method(NSClassFromString(pair[0]), NSSelectorFromString(pair[1]), NO), library, name.UTF8String);
    }
    CHECK_EQUAL(image_of_method([NSURL class], @selector(fileURLWithFileSystemRepresentation:isDirectory:relativeToURL:), YES), library, "+[NSURL fileURLWithFileSystemRepresentation:isDirectory:relativeToURL:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSExpression class], @selector(expressionForConditional:trueExpression:falseExpression:), YES), library, "+[NSExpression expressionForConditional:trueExpression:falseExpression:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSProgress class], @selector(discreteProgressWithTotalUnitCount:), YES), library, "+[NSProgress discreteProgressWithTotalUnitCount:] comes from the backports");
    CHECK_EQUAL(image_of_method([NSProgress class], @selector(progressWithTotalUnitCount:parent:pendingUnitCount:), YES), library, "+[NSProgress progressWithTotalUnitCount:parent:pendingUnitCount:] comes from the backports");
    CHECK_EQUAL(image_of_pointer((void *)&NSProgressEstimatedTimeRemainingKey), library, "NSProgressEstimatedTimeRemainingKey comes from the backports");
    CHECK_EQUAL(image_of_method([NSProgress class], @selector(addChild:withPendingUnitCount:), NO), library, "-[NSProgress addChild:withPendingUnitCount:] comes from the backports");
    CHECK([NSProgress instancesRespondToSelector:@selector(resume)] == NO, "resume is not offered where the release has no way back from paused");
    CHECK_EQUAL(image_of_pointer(&CFAutorelease), library, "CFAutorelease comes from the backports");
    CHECK_EQUAL(image_of_pointer((void *)&NSKeyedArchiveRootObjectKey), library, "NSKeyedArchiveRootObjectKey comes from the backports");
}

static void check_system(void)
{
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    NSString *described = [NSString stringWithFormat:@"Version %ld.%ld", (long)version.majorVersion, (long)version.minorVersion];
    if (version.patchVersion)
        described = [described stringByAppendingFormat:@".%ld", (long)version.patchVersion];
    CHECK([[NSProcessInfo processInfo].operatingSystemVersionString hasPrefix:[described stringByAppendingString:@" "]], "operatingSystemVersion agrees with operatingSystemVersionString");
    printf("operatingSystemVersion %ld.%ld.%ld, %s\n", (long)version.majorVersion, (long)version.minorVersion, (long)version.patchVersion, [NSProcessInfo processInfo].operatingSystemVersionString.UTF8String);
    NSOperatingSystemVersion six = {6, 0, 0}, seven = {7, 0, 0};
    CHECK([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:six], "iOS 6.0 is at least 6.0.0");
    CHECK(![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:seven], "iOS 6 is not at least 7.0.0");
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:@[@"payload"]];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    CHECK_EQUAL([unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey], @[@"payload"], "NSKeyedArchiveRootObjectKey reads the root of an iOS 6 archive");
    NSMutableData *written = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:written];
    [archiver encodeObject:@"root object" forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    CHECK_EQUAL([NSKeyedUnarchiver unarchiveObjectWithData:written], @"root object", "an archive keyed with NSKeyedArchiveRootObjectKey unarchives with +unarchiveObjectWithData:");
    NSMutableData *sample = [NSMutableData data];
    int legacyDifferences = 0;
    for (NSUInteger length = 0; length < 300; length++) {
        uint8_t byte = (uint8_t)(length * 131 + 17);
        if ([sample respondsToSelector:@selector(base64Encoding)] && ![[sample base64Encoding] isEqualToString:[sample base64EncodedStringWithOptions:0]])
            legacyDifferences++;
        [sample appendBytes:&byte length:1];
    }
    printf("iOS 6 private -[NSData base64Encoding] differs from base64EncodedStringWithOptions:0 for %d of 300 lengths\n", legacyDifferences);
    CHECK(legacyDifferences == 0, "the private iOS 6 base64Encoding agrees with the backport");
    for (NSString *input in @[@"YWJj", @"YQ==", @"YQ", @"YW\r\nJj", @"YW*Jj", @"YQ===", @"YQ==YQ=="]) {
        NSData *legacy = [[NSData alloc] initWithBase64Encoding:input];
        NSData *mine = [[NSData alloc] initWithBase64EncodedString:input options:0];
        NSData *ignoring = [[NSData alloc] initWithBase64EncodedString:input options:NSDataBase64DecodingIgnoreUnknownCharacters];
        printf("iOS 6 initWithBase64Encoding: %s -> %s (backport strict %s, ignoring %s)\n", [[input stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<CRLF>"] UTF8String],
               legacy ? legacy.description.UTF8String : "nil", mine ? mine.description.UTF8String : "nil", ignoring ? ignoring.description.UTF8String : "nil");
    }
}

static NSString *device_tolerance(NSString *name)
{
    if ([name hasPrefix:@"string.transform."])
        return @"iOS 6 CFStringTransform ignores the reverse direction and carries older ICU data";
    if ([name rangeOfString:@".quarter."].location != NSNotFound || [name rangeOfString:@".zoneQuarter."].location != NSNotFound)
        return @"iOS 6 computes no quarter component, so the backport derives it from the month";
    if ([name hasPrefix:@"locale."])
        return @"iOS 6 carries older locale data than macOS 27";
    if ([name isEqualToString:@"calendar.edges.leapMonthValid"])
        return @"whether a leap month flag names a real month is the release's ICU, which iOS 6 ignores and macOS 27 checks per calendar";
    if ([name isEqualToString:@"progress.resignCreditsPendingUnits"])
        return @"iOS 6 resignCurrent leaves the pending units of a progress no child took uncounted, where the newest release counts them as completed";
    if ([name isEqualToString:@"url.dataRepresentation.latin1.string"])
        return @"iOS 6 CFURL escapes the string of a URL read as ISO Latin 1 in ISO Latin 1, not in UTF-8";
    if ([name isEqualToString:@"url.representation.5"] || [name isEqualToString:@"url.representation.8"])
        return @"iOS 6 CFURL keeps %00 and %2F percent-encoded in a file system representation";
    return nil;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_sources();
        check_system();
        NSDictionary *expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:foundation2_expectations length:strlen(foundation2_expectations)] options:0 error:NULL];
        CHECK(expected != nil, "expectations parse");
        Foundation2Implementation native = {
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
        Foundation2Recorder *recorder = [[Foundation2Recorder alloc] init];
        foundation2_run(native, recorder);
        NSDictionary *records = expected[@"records"];
        int matched = 0, mismatched = 0;
        NSCountedSet *tolerated = [NSCountedSet set];
        NSMutableSet *names = [NSMutableSet setWithArray:records.allKeys];
        [names addObjectsFromArray:recorder.records.allKeys];
        for (NSString *name in [names.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
            id want = records[name], got = recorder.records[name];
            if ([name isEqualToString:@"calendar.edges.validity"] && [want isKindOfClass:[NSArray class]] && [want count]) {
                NSMutableArray *patched = [want mutableCopy];
                NSMutableArray *rows = [patched[0] mutableCopy];
                rows[11] = @"1101";
                patched[0] = rows;
                want = patched;
            }
            if ([want isEqual:got]) {
                matched++;
                continue;
            }
            NSString *tolerance = device_tolerance(name);
            if (tolerance) {
                [tolerated addObject:tolerance];
                if ([tolerated countForObject:tolerance] <= 3)
                    printf("tolerated %s: %s\n    device %s\n    macOS  %s\n", tolerance.UTF8String, name.UTF8String, text(got).UTF8String, text(want).UTF8String);
                continue;
            }
            mismatched++;
            charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"device %@ != host %@", text(got), text(want)]);
        }
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        gregorian.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        NSDateComponents *cutover = [[NSDateComponents alloc] init];
        cutover.year = 1582;
        cutover.month = 10;
        cutover.day = 10;
        NSDateComponents *roundTrip = [gregorian components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[gregorian dateFromComponents:cutover]];
        CHECK(roundTrip.year == 1582 && roundTrip.month == 10 && roundTrip.day == 10, "the Gregorian calendar of this release has no gap in October 1582, so the 10th exists and is valid");
        CHECK_EQUAL(recorder.records[@"progress.resignCreditsPendingUnits"], @0, "resignCurrent leaves the pending units of a progress with no child uncounted on this release");
        extern void *__NSArray0__, *__NSDictionary0__;
        NSArray *emptyArray = (__bridge NSArray *)__NSArray0__;
        NSDictionary *emptyDictionary = (__bridge NSDictionary *)__NSDictionary0__;
        CHECK(emptyArray != nil && [emptyArray isKindOfClass:[NSArray class]] && emptyArray.count == 0 && ![emptyArray respondsToSelector:@selector(addObject:)], "__NSArray0__ holds an empty immutable array");
        CHECK(emptyDictionary != nil && [emptyDictionary isKindOfClass:[NSDictionary class]] && emptyDictionary.count == 0 && ![emptyDictionary respondsToSelector:@selector(setObject:forKey:)], "__NSDictionary0__ holds an empty immutable dictionary");
        CHECK([[emptyArray arrayByAddingObject:@1] isEqual:@[@1]] && [emptyDictionary objectForKey:@"a"] == nil, "the empty collections answer as the release's own");
        {
            NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"com.charon.test"];
            CHECK([activity.activityType isEqualToString:@"com.charon.test"] && activity.userInfo.count == 0 && activity.needsSave && activity.eligibleForHandoff && !activity.eligibleForSearch, "a new activity has the system's defaults");
            [activity addUserInfoEntriesFromDictionary:@{@"k": @1}];
            CHECK([activity.userInfo isEqual:@{@"k": @1}], "user info can be added to");
            NSString *raised = @"none";
            @try {
                activity.webpageURL = [NSURL URLWithString:@"ftp://x"];
            } @catch (NSException *exception) {
                raised = exception.name;
            }
            CHECK([raised isEqualToString:NSInvalidArgumentException], "a web page URL of another scheme is refused");
            __block int saved = 0;
            __block BOOL needsSaveWhenAsked = YES;
            Class delegateClass = objc_allocateClassPair([NSObject class], "CharonActivityDelegate", 0);
            class_addMethod(delegateClass, @selector(userActivityWillSave:), imp_implementationWithBlock(^(id self_, NSUserActivity *a) { saved++; needsSaveWhenAsked = a.needsSave; }), "v@:@");
            objc_registerClassPair(delegateClass);
            id delegate = [[delegateClass alloc] init];
            activity.delegate = delegate;
            [activity becomeCurrent];
            CHECK(saved == 0, "the delegate is not asked while becomeCurrent runs");
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            CHECK(saved == 1 && !needsSaveWhenAsked && !activity.needsSave, "the delegate is asked once, with needsSave off");
            __block NSInteger code = 0;
            [activity getContinuationStreamsWithCompletionHandler:^(NSInputStream *i, NSOutputStream *o, NSError *e) { code = e.code; }];
            CHECK(code == 3328, "the streams of an activity nobody continues fail");
        }
        CHECK([NSProcessInfo processInfo].isLowPowerModeEnabled == NO && [NSProcessInfoPowerStateDidChangeNotification isEqualToString:@"NSProcessInfoPowerStateDidChangeNotification"], "Low Power Mode is off, and the notification carries the release's name");
        CHECK(emptyArray == [NSArray array] && emptyArray == [NSArray new] && emptyArray == [[NSArray alloc] init] && emptyArray == [[NSMutableArray array] copy], "the empty array of the release is the one __NSArray0__ holds, however it is made");
        CHECK(emptyDictionary == [NSDictionary dictionary] && emptyDictionary == [NSDictionary new] && emptyDictionary == [[NSDictionary alloc] init], "and the empty dictionary is the one __NSDictionary0__ holds");
        for (NSString *tolerance in tolerated)
            printf("tolerated %lu records: %s\n", (unsigned long)[tolerated countForObject:tolerance], tolerance.UTF8String);
        printf("records matched=%d mismatched=%d\n", matched, mismatched);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
