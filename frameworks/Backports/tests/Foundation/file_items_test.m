#import "check.h"

BOOL revenant_trash_item(NSFileManager *manager, NSURL *url, NSString *trash, NSURL **resulting, NSError **error);

static NSString *revenant_scratch(void)
{
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    return folder;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *folder = revenant_scratch();
    NSString *trash = [folder stringByAppendingPathComponent:@".Trash"];
    NSString *file = [folder stringByAppendingPathComponent:@"note.txt"];
    [@"one" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSURL *moved = nil;
    NSError *error = nil;
    BOOL trashed = revenant_trash_item(manager, [NSURL fileURLWithPath:file], trash, &moved, &error);
    revenant_check(trashed && ![manager fileExistsAtPath:file] && [manager fileExistsAtPath:moved.path], "an item moves into the trash", [NSString stringWithFormat:@"%@", error]);
    revenant_expect_string("the item keeps its name when nothing collides", moved.lastPathComponent, @"note.txt");
    [@"two" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSURL *second = nil;
    revenant_trash_item(manager, [NSURL fileURLWithPath:file], trash, &second, &error);
    revenant_expect_string("a collision renames the second item", second.lastPathComponent, revenant_negative ? @"note.txt" : @"note 2.txt");
    revenant_check(![manager fileExistsAtPath:[folder stringByAppendingPathComponent:@"missing"]] && !revenant_trash_item(manager, [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"missing"]], trash, NULL, &error) && error.code == NSFileNoSuchFileError, "a missing item is an error", [NSString stringWithFormat:@"%@", error]);

    NSString *target = [folder stringByAppendingPathComponent:@"target.txt"];
    [@"x" writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSURL *targetURL = [NSURL fileURLWithPath:target];
    NSURL *aliasURL = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"alias"]];
    NSData *bookmark = [targetURL bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
    [NSURL writeBookmarkData:bookmark toURL:aliasURL options:NSURLBookmarkCreationSuitableForBookmarkFile error:NULL];
    SEL resolve = @selector(URLByResolvingAliasFileAtURL:options:error:);
    typedef NSURL *(*Resolve)(id, SEL, NSURL *, NSURLBookmarkResolutionOptions, NSError **);
    Resolve resolver = REVENANT_CLASS_IMP(NSURL, resolve, Resolve);
    NSURL *resolved = resolver([NSURL class], resolve, aliasURL, 0, &error);
    revenant_check([resolved.path.stringByResolvingSymlinksInPath isEqualToString:target.stringByResolvingSymlinksInPath], "an alias file resolves to its target", [NSString stringWithFormat:@"%@ %@", resolved, error]);
    NSURL *plain = resolver([NSURL class], resolve, targetURL, 0, &error);
    revenant_check([plain isEqual:targetURL], "a plain file resolves to itself", [NSString stringWithFormat:@"%@", plain]);
    NSURL *absent = resolver([NSURL class], resolve, [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"absent"]], 0, &error);
    revenant_check(absent == nil && error != nil, "an unreachable URL fails with an error", @"resolved");

    id version = [[NSObject alloc] init];
    revenant_check(REVENANT_IMP(NSFileVersion, @selector(hasLocalContents), BOOL (*)(id, SEL))(version, @selector(hasLocalContents)), "a local version has local contents", @"NO");
    revenant_check(!REVENANT_IMP(NSFileVersion, @selector(hasThumbnail), BOOL (*)(id, SEL))(version, @selector(hasThumbnail)), "a local version has no thumbnail", @"YES");
    revenant_check(REVENANT_IMP(NSFileVersion, @selector(originatorNameComponents), id (*)(id, SEL))(version, @selector(originatorNameComponents)) == nil, "a local version has no originator", @"has one");
    SEL nonlocal = @selector(getNonlocalVersionsOfItemAtURL:completionHandler:);
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSArray *versions = nil;
    __block NSError *failure = nil;
    typedef void (*Nonlocal)(id, SEL, NSURL *, void (^)(NSArray *, NSError *));
    REVENANT_CLASS_IMP(NSFileVersion, nonlocal, Nonlocal)([NSFileVersion class], nonlocal, targetURL, ^(NSArray *found, NSError *problem) {
        versions = found;
        failure = problem;
        dispatch_semaphore_signal(done);
    });
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    revenant_check(versions != nil && versions.count == 0 && failure == nil, "a file outside iCloud has no non-local versions", [NSString stringWithFormat:@"%@ %@", versions, failure]);
    NSString *text = [@"plain" variantFittingPresentationWidth:20];
    revenant_expect_string("a string without variations is its own variant", text, @"plain");
    [manager removeItemAtPath:folder error:NULL];
    return revenant_finish();
}
