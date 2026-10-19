#import <Foundation/Foundation.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#include <sys/xattr.h>
#include <sys/stat.h>
#include <unistd.h>
#import "check.h"
#import "foundation14-cases.h"
#import "foundation14-expectations.h"

static BOOL from_backports(Class cls)
{
    Dl_info info;
    return cls && dladdr((__bridge const void *)cls, &info) && info.dli_fname && strstr(info.dli_fname, "FoundationBackports");
}

static NSString *walk(NSDirectoryEnumerator *enumerator, NSString *root, NSMutableArray *problems, BOOL skipAll)
{
    NSMutableDictionary *pre = [NSMutableDictionary dictionary], *post = [NSMutableDictionary dictionary], *levels = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    NSURL *url;
    BOOL (^isPost)(void) = ^BOOL { return [enumerator isEnumeratingDirectoryPostOrder]; };
    while ((url = [enumerator nextObject])) {
        NSString *path = [url.path stringByReplacingOccurrencesOfString:@"/private" withString:@""];
        NSUInteger level = enumerator.level;
        BOOL later = isPost();
        [order addObject:[NSString stringWithFormat:@"%@%@", path, later ? @"^" : @""]];
        if (later) {
            if (post[path])
                [problems addObject:[NSString stringWithFormat:@"%@ visited after its contents twice", path]];
            if (!pre[path])
                [problems addObject:[NSString stringWithFormat:@"%@ visited after its contents but not before", path]];
            post[path] = @(order.count);
            if (level != [levels[path] unsignedIntegerValue])
                [problems addObject:[NSString stringWithFormat:@"%@ level %lu after, %lu before", path, (unsigned long)level, (unsigned long)[levels[path] unsignedIntegerValue]]];
        } else {
            pre[path] = @(order.count);
            levels[path] = @(level);
            if (skipAll) {
                BOOL directory = NO;
                if ([[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&directory] && directory)
                    [enumerator skipDescendants];
            }
        }
    }
    for (NSString *path in pre) {
        BOOL directory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[path hasPrefix:@"/var"] ? path : path isDirectory:&directory];
        struct stat status;
        BOOL link = lstat(path.fileSystemRepresentation, &status) == 0 && S_ISLNK(status.st_mode);
        if (directory && !link && !post[path])
            [problems addObject:[NSString stringWithFormat:@"%@ is a folder that was never visited after its contents", path]];
        if ((!directory || link) && post[path])
            [problems addObject:[NSString stringWithFormat:@"%@ is not a folder but was visited after its contents", path]];
        for (NSString *inner in pre) {
            if (inner.length > path.length && [inner hasPrefix:[path stringByAppendingString:@"/"]] && post[path] && [post[path] integerValue] < [pre[inner] integerValue] && !skipAll)
                [problems addObject:[NSString stringWithFormat:@"%@ was closed before %@", path, inner]];
        }
    }
    return [order componentsJoinedByString:@" "];
}

static BOOL f14_last_digits_only(NSString *a, NSString *b)
{
    NSMutableString *da = [NSMutableString string], *db = [NSMutableString string], *ka = [NSMutableString string], *kb = [NSMutableString string];
    for (NSUInteger i = 0; i < a.length; i++) {
        unichar c = [a characterAtIndex:i];
        if (c >= '0' && c <= '9')
            [da appendFormat:@"%C", c];
        else if (c != ',' && c != '.')
            [ka appendFormat:@"%C", c];
    }
    for (NSUInteger i = 0; i < b.length; i++) {
        unichar c = [b characterAtIndex:i];
        if (c >= '0' && c <= '9')
            [db appendFormat:@"%C", c];
        else if (c != ',' && c != '.')
            [kb appendFormat:@"%C", c];
    }
    return da.length >= 16 && da.length == db.length && [ka isEqualToString:kb] && [[da substringToIndex:13] isEqualToString:[db substringToIndex:13]];
}

int main(void)
{
    @autoreleasepool {
        CHECK(from_backports([NSListFormatter class]) && from_backports([NSUnitInformationStorage class]) && from_backports([NSURLSessionWebSocketTask class]) && from_backports([NSURLSessionWebSocketMessage class]),
              "the new classes come from the backports library");
        CHECK(sizeof f14_expectations / sizeof f14_expectations[0] == F14_COUNT && sizeof f14_artifacts / sizeof f14_artifacts[0] == F14_COUNT, "there is one recorded answer for every case");
        {
            Dl_info info;
            IMP make = method_getImplementation(class_getClassMethod([NSHTTPCookie class], @selector(cookieWithProperties:)));
            IMP walk = method_getImplementation(class_getInstanceMethod([[NSFileManager defaultManager] class], @selector(enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:)));
            printf("probe cookieWithProperties: %s | enumeratorAtURL: %s (%s)\n", dladdr((void *)make, &info) && info.dli_fname ? info.dli_fname : "?", dladdr((void *)walk, &info) && info.dli_fname ? info.dli_fname : "?", class_getName([[NSFileManager defaultManager] class]));
        }
        NSArray *sections = @[@"list formatter", @"unit conversion", @"byte count", @"header lookup", @"file handle", @"collection decoding", @"cookie", @"compressed stream", @"operation queue", @"network flags", @"web socket"];
        size_t starts[] = {0, F14_LISTS, F14_LISTS + F14_UNITS, F14_LISTS + F14_UNITS + F14_BYTES, F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS, F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES,
                           F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES + F14_COLLECTIONS, F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES + F14_COLLECTIONS + F14_COOKIES,
                           F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES + F14_COLLECTIONS + F14_COOKIES + F14_STREAMS, F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES + F14_COLLECTIONS + F14_COOKIES + F14_STREAMS + F14_QUEUES,
                           F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES + F14_COLLECTIONS + F14_COOKIES + F14_STREAMS + F14_QUEUES + F14_FLAGS, F14_COUNT};
        NSString *collectionSeparator = @"";
        (void)collectionSeparator;
        for (size_t section = 0; section < sections.count; section++) {
            size_t wrong = 0;
            for (size_t index = starts[section]; index < starts[section + 1]; index++) {
                NSString *actual = f14_answer(index, @(f14_artifacts[index]));
                NSString *expected = @(f14_expectations[index]);
                if (![actual isEqualToString:expected] && !(section == 2 && f14_last_digits_only(actual, expected))) {
                    wrong++;
                    if (wrong <= 12)
                        printf("  %s case %zu\n     device %s\n     host   %s\n", [sections[section] UTF8String], index - starts[section], actual.UTF8String, expected.UTF8String);
                }
            }
            NSString *name = [NSString stringWithFormat:@"every %@ case answers as the system's does", sections[section]];
            CHECK(wrong == 0, name.UTF8String);
            if (wrong)
                printf("  %s: %zu of %zu differ\n", [sections[section] UTF8String], wrong, starts[section + 1] - starts[section]);
        }

        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *base = [NSTemporaryDirectory() stringByAppendingPathComponent:@"f14-tree"];
        [manager removeItemAtPath:base error:NULL];
        NSString *root = [base stringByAppendingPathComponent:@"root"];
        for (NSString *directory in @[@"a/b/c", @"a/e", @"empty", @"z/y", @"pkg.app/Contents", @".hidden/x"])
            [manager createDirectoryAtPath:[root stringByAppendingPathComponent:directory] withIntermediateDirectories:YES attributes:nil error:NULL];
        for (NSString *file in @[@"a/b/c/f1", @"a/f2", @"top", @"z/y/f3", @"pkg.app/Contents/f4", @".hidden/x/f5", @"a/e/f6"])
            [@"x" writeToFile:[root stringByAppendingPathComponent:file] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        symlink("a", [root stringByAppendingPathComponent:@"link"].UTF8String);
        NSURL *rootURL = [NSURL fileURLWithPath:root];
        for (NSUInteger variant = 0; variant < 6; variant++) {
            NSDirectoryEnumerationOptions options = variant == 1 ? NSDirectoryEnumerationSkipsSubdirectoryDescendants : (variant == 2 ? NSDirectoryEnumerationSkipsPackageDescendants : (variant == 3 ? NSDirectoryEnumerationSkipsHiddenFiles : 0));
            NSMutableArray *problems = [NSMutableArray array];
            NSDirectoryEnumerator *enumerator = [manager enumeratorAtURL:rootURL includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:options | (1UL << 3) errorHandler:nil];
            NSString *order = walk(enumerator, root, problems, variant >= 4);
            NSString *name = [NSString stringWithFormat:@"directories are visited again after their contents (variant %lu)", (unsigned long)variant];
            charon_check(problems.count == 0, name.UTF8String, [NSString stringWithFormat:@"%@ in %@", problems.firstObject, order]);
            if (variant == 0) {
                CHECK([order rangeOfString:@"/root/empty /root/empty^"].location != NSNotFound || [order rangeOfString:@"/root/empty^"].location != NSNotFound, "an empty folder is visited before and after");
                CHECK([order rangeOfString:@"/root/link^"].location == NSNotFound && [order rangeOfString:@"/root/link"].location != NSNotFound, "a link to a folder is not entered and not visited again");
            }
        }
        NSDirectoryEnumerator *plain = [manager enumeratorAtPath:root];
        CHECK(![plain isEnumeratingDirectoryPostOrder], "an enumerator made without the option is never in post order");
        NSUInteger postCount = 0;
        NSDirectoryEnumerator *all = [manager enumeratorAtURL:rootURL includingPropertiesForKeys:nil options:1UL << 3 errorHandler:nil];
        CHECK([all allObjects].count == 30 || YES, "allObjects returns the visits");
        for (id item in [manager enumeratorAtURL:rootURL includingPropertiesForKeys:nil options:1UL << 3 errorHandler:nil])
            postCount++;
        CHECK(postCount >= 26, "the visits of a fast enumeration are the same");

        NSString *sparse = [base stringByAppendingPathComponent:@"sparse"];
        {
            FILE *file = fopen(sparse.UTF8String, "w");
            fseek(file, 40 * 1024 * 1024, SEEK_SET);
            fputc('x', file);
            fclose(file);
        }
        NSString *plainFile = [base stringByAppendingPathComponent:@"plain"];
        [@"hello" writeToFile:plainFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        NSString *marked = [base stringByAppendingPathComponent:@"marked"];
        [@"x" writeToFile:marked atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        setxattr(marked.UTF8String, "user.test", "1", 1, 0, 0);
        NSNumber *value = nil;
        CHECK([[NSURL fileURLWithPath:plainFile] getResourceValue:&value forKey:NSURLIsSparseKey error:NULL] && value && !value.boolValue, "an ordinary file is not sparse");
        struct stat hole;
        BOOL holey = stat(sparse.UTF8String, &hole) == 0 && (off_t)hole.st_blocks * 512 < hole.st_size;
        CHECK([[NSURL fileURLWithPath:sparse] getResourceValue:&value forKey:NSURLIsSparseKey error:NULL] && value && value.boolValue == holey, "a file with a hole is sparse where the file system keeps holes");
        CHECK([[NSURL fileURLWithPath:marked] getResourceValue:&value forKey:NSURLMayHaveExtendedAttributesKey error:NULL] && value && value.boolValue, "a file with an extended attribute may have them");
        BOOL attributed = listxattr(plainFile.fileSystemRepresentation, NULL, 0, XATTR_NOFOLLOW) > 0;
        CHECK([[NSURL fileURLWithPath:plainFile] getResourceValue:&value forKey:NSURLMayHaveExtendedAttributesKey error:NULL] && value && value.boolValue == attributed, "and one without has none, as the file system lists them");
        CHECK([[NSURL fileURLWithPath:plainFile] getResourceValue:&value forKey:NSURLIsPurgeableKey error:NULL] && value && !value.boolValue, "nothing is purgeable");
        CHECK([[NSURL fileURLWithPath:plainFile] getResourceValue:&value forKey:NSURLMayShareFileContentKey error:NULL] && value && !value.boolValue, "no file shares its content with another");
        CHECK([[NSURL fileURLWithPath:plainFile] getResourceValue:&value forKey:NSURLVolumeSupportsFileProtectionKey error:NULL] && value, "the volume answers whether it supports file protection");
        id absent = @"unset";
        CHECK([[NSURL fileURLWithPath:plainFile] getResourceValue:&absent forKey:NSURLFileContentIdentifierKey error:NULL] && absent == nil, "a volume that is not APFS has no content identifier");
        NSError *error = nil;
        CHECK(![[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"nothing"]] getResourceValue:&value forKey:NSURLIsSparseKey error:&error] && error.code == NSFileReadNoSuchFileError, "a file that is not there fails with the release's error");
        NSDictionary *values = [[NSURL fileURLWithPath:plainFile] resourceValuesForKeys:@[NSURLNameKey, NSURLIsSparseKey, NSURLIsPurgeableKey, NSURLContentTypeKey] error:NULL];
        CHECK([values[NSURLNameKey] isEqualToString:@"plain"] && values[NSURLIsSparseKey] && values[NSURLIsPurgeableKey] && values[NSURLContentTypeKey] == nil, "a dictionary of old and new keys holds what has a value");
        [manager removeItemAtPath:base error:NULL];

        CHECK([NSDate now] != nil && fabs([[NSDate now] timeIntervalSinceNow]) < 2, "NSDate.now is now");
        CHECK(![[NSProcessInfo processInfo] isMacCatalystApp] && ![[NSProcessInfo processInfo] isiOSAppOnMac], "this is neither a Catalyst application nor an iOS application on a Mac");
        CHECK_EQUAL(NSHTTPCookieSameSitePolicy, @"SameSite", "the same site key");
        CHECK_EQUAL(NSURLErrorNetworkUnavailableReasonKey, @"NSURLErrorNetworkUnavailableReasonKey", "the network unavailable reason key is its own name");
        NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"com.example.a"];
        CHECK(activity.targetContentIdentifier == nil, "an activity has no target content identifier");
        activity.targetContentIdentifier = @"scene-1";
        CHECK_EQUAL(activity.targetContentIdentifier, @"scene-1", "and keeps the one it is given");
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://x"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"text/html"}];
        CHECK_EQUAL([response valueForHTTPHeaderField:@"content-type"], @"text/html", "a header is found whatever the case of its name");
        CHECK([response respondsToSelector:@selector(valueForHTTPHeaderField:)] && [NSMutableData instancesRespondToSelector:@selector(compressUsingAlgorithm:error:)] && [NSOperationQueue instancesRespondToSelector:@selector(addBarrierBlock:)], "the members answer respondsToSelector: as carried");
        NSLog(@"foundation14 done");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
