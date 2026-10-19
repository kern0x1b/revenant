#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "check.h"

/* The second N-Z Foundation batch on the device: every implemented member of the progress's state,
   the number formatter, the request flags, the URL encoders and promised items, the cache and the
   credential storage, the XML parser's policy, an operation, the platform flags, a protocol's task,
   the term of address, the person name keys, the two XPC members and a user activity's own two. */

static void progress_state(void)
{
    NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    CHECK(progress.isIndeterminate, "a progress with no units is indeterminate, as the host answers");
    progress.totalUnitCount = 10;
    CHECK(!progress.isIndeterminate, "and one with ten units is not");
    progress.completedUnitCount = 5;
    CHECK(!progress.isIndeterminate && progress.fractionCompleted == 0.5, "half of ten is half");
    CHECK(!progress.isPaused, "a fresh progress is not paused");
    [progress pause];
    CHECK(progress.isPaused, "pause pauses it");
    __block int resumed = 0;
    progress.resumingHandler = ^{ resumed++; };
    [progress resume];
    CHECK(resumed == 1 && !progress.isPaused, "resume runs the handler and unpauses it");
    [progress resume];
    CHECK(resumed == 1, "and a second resume on a progress that was not paused does not run it again");
    progress.localizedAdditionalDescription = @"more";
    CHECK_EQUAL(progress.localizedAdditionalDescription, @"more", "the additional description is kept");
    progress.localizedAdditionalDescription = nil;
    CHECK(progress.localizedAdditionalDescription == nil, "and nil puts the default back, which is nil without the file counts");
    progress.userInfo = @{NSProgressFileTotalCountKey: @3, NSProgressFileCompletedCountKey: @1};
    progress.localizedAdditionalDescription = nil;
    CHECK_EQUAL(progress.localizedAdditionalDescription, @"1 of 3", "with the file counts the default is what they say");
}

static void number_formatter(void)
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    CHECK(formatter.formattingContext == NSFormattingContextUnknown, "a fresh formatter has the unknown context");
    formatter.formattingContext = NSFormattingContextStandalone;
    CHECK(formatter.formattingContext == NSFormattingContextStandalone, "and keeps the one it is given");
    CHECK(formatter.minimumGroupingDigits == 1, "the minimum grouping digits default to 1, as the host answers");
    CHECK_EQUAL([formatter stringFromNumber:@1234], @"1,234", "1,234 keeps its separator at one digit");
    formatter.minimumGroupingDigits = 2;
    CHECK(formatter.minimumGroupingDigits == 2, "and are kept");
    CHECK_EQUAL([formatter stringFromNumber:@1234], @"1234", "a three digit group loses it at two digits");
    CHECK_EQUAL([formatter stringFromNumber:@12345], @"12,345", "while a five digit group keeps it");
    formatter.minimumGroupingDigits = 1;
    CHECK_EQUAL([formatter stringFromNumber:@1234], @"1,234", "and one digit puts it back");
}

static void request_flags(void)
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/"]];
    CHECK(!request.allowsPersistentDNS && !request.assumesHTTP3Capable && !request.attribution &&
          !request.requiresDNSSECValidation && !request.allowsUltraConstrainedNetworkAccess,
          "a fresh request has every one of the six off");
    request.allowsPersistentDNS = YES;
    request.assumesHTTP3Capable = YES;
    request.attribution = YES;
    request.requiresDNSSECValidation = YES;
    request.allowsUltraConstrainedNetworkAccess = YES;
    request.cookiePartitionIdentifier = @"a-partition";
    CHECK(request.allowsPersistentDNS && request.assumesHTTP3Capable && request.attribution &&
          request.requiresDNSSECValidation && request.allowsUltraConstrainedNetworkAccess,
          "and all five of the flags are kept");
    CHECK_EQUAL(request.cookiePartitionIdentifier, @"a-partition", "with the partition identifier beside them");
    NSURLRequest *copied = [request copy];
    CHECK(copied.cookiePartitionIdentifier == nil, "and a copy of a request starts fresh, as the release's does");
}

static void url_encoding_and_promised(void)
{
    NSURL *spaced = [NSURL URLWithString:@"https://example.com/a b" encodingInvalidCharacters:YES];
    CHECK_EQUAL(spaced.absoluteString, @"https://example.com/a%20b", "a space is written as a percent escape");
    CHECK([NSURL URLWithString:@"https://example.com/a b" encodingInvalidCharacters:NO] == nil,
          "and without the flag the same string is nil, as the host answers");
    NSURL *init = [[NSURL alloc] initWithString:@"https://example.com/a b" encodingInvalidCharacters:YES];
    CHECK_EQUAL(init.absoluteString, @"https://example.com/a%20b", "the initializer escapes the same way");

    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://ex%61mple.com/p"];
    CHECK_EQUAL(components.host, @"example.com", "a host with a percent escape reads back decoded");
    CHECK_EQUAL(components.encodedHost, @"ex%61mple.com", "and keeps the escape in the encoded host");
    components.host = @"a b";
    CHECK_EQUAL(components.encodedHost, @"a%20b", "a host set with a space is written escaped");
    NSURLComponents *spacedComponents = [NSURLComponents componentsWithString:@"https://example.com/a b"
                                                        encodingInvalidCharacters:YES];
    CHECK_EQUAL(spacedComponents.URL.absoluteString, @"https://example.com/a%20b", "and so is a string with one");

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-promised.txt"];
    [@"hello" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSURL *file = [NSURL fileURLWithPath:path];
    id value = nil;
    CHECK([file getPromisedItemResourceValue:&value forKey:NSURLFileSizeKey error:NULL] && [value intValue] == 5,
          "a promised file that is there answers its size");
    CHECK([file checkPromisedItemIsReachableAndReturnError:NULL], "and is reachable");
    NSDictionary *values = [file promisedItemResourceValuesForKeys:@[NSURLFileSizeKey] error:NULL];
    CHECK([values[NSURLFileSizeKey] intValue] == 5, "and its values come back together");
    NSURL *missing = [NSURL fileURLWithPath:[path stringByAppendingString:@"-missing"]];
    NSError *error = nil;
    value = nil;
    CHECK(![missing getPromisedItemResourceValue:&value forKey:NSURLFileSizeKey error:&error] && value == nil,
          "a promised file that is not there answers nothing");
    CHECK([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileReadNoSuchFileError,
          "with the file-no-such-file error the host answers");
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

static void cache_and_credentials(void)
{
    NSURL *url = [NSURL URLWithString:@"https://charon-probe.invalid/resource"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"text/plain" expectedContentLength:5
                                                   textEncodingName:@"utf-8"];
    NSCachedURLResponse *cached = [[NSCachedURLResponse alloc] initWithResponse:response
                                                                            data:[@"hello" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLCache *cache = [[NSURLCache alloc] initWithMemoryCapacity:1024 diskCapacity:1024 diskPath:@"charon-probe"];
    SEL store = NSSelectorFromString(@"storeCachedResponse:forDataTask:");
    SEL read = NSSelectorFromString(@"getCachedResponseForDataTask:completionHandler:");
    SEL remove = NSSelectorFromString(@"removeCachedResponseForDataTask:");
    CHECK([cache respondsToSelector:store] && [cache respondsToSelector:read] && [cache respondsToSelector:remove],
          "the cache has the three data task methods");
    if (![cache respondsToSelector:store])
        return;
    /* A data task of the port's own session, which carries the request the cache is asked about. */
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    ((void (*)(id, SEL, id, id))objc_msgSend)(cache, store, cached, task);
    __block NSCachedURLResponse *answered = nil;
    ((void (*)(id, SEL, id, void (^)(NSCachedURLResponse *)))objc_msgSend)(cache, read, task, ^(NSCachedURLResponse *found) {
        answered = found;
    });
    CHECK(answered != nil, "a response stored for a task reads back for it");
    ((void (*)(id, SEL, id))objc_msgSend)(cache, remove, task);
    answered = nil;
    ((void (*)(id, SEL, id, void (^)(NSCachedURLResponse *)))objc_msgSend)(cache, read, task, ^(NSCachedURLResponse *found) {
        answered = found;
    });
    CHECK(answered == nil, "and the task's response can be taken away again");

    NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:@"charon-probe.invalid" port:443
                                                                      protocol:NSURLProtectionSpaceHTTPS realm:@"probe"
                                                         authenticationMethod:NSURLAuthenticationMethodServerTrust];
    NSURLCredential *credential = [NSURLCredential credentialWithUser:@"u" password:@"p"
                                                          persistence:NSURLCredentialPersistenceForSession];
    SEL setDefault = NSSelectorFromString(@"setDefaultCredential:forProtectionSpace:task:");
    SEL removeTask = NSSelectorFromString(@"removeCredential:forProtectionSpace:options:task:");
    CHECK([storage respondsToSelector:setDefault] && [storage respondsToSelector:removeTask],
          "the credential storage has its task methods");
    if (![storage respondsToSelector:setDefault])
        return;
    ((void (*)(id, SEL, id, id, id))objc_msgSend)(storage, setDefault, credential, space, task);
    __block NSURLCredential *defaulted = nil;
    ((void (*)(id, SEL, id, id, void (^)(NSURLCredential *)))objc_msgSend)(storage,
        NSSelectorFromString(@"getDefaultCredentialForProtectionSpace:task:completionHandler:"), space, task,
        ^(NSURLCredential *found) { defaulted = found; });
    CHECK_EQUAL(defaulted.user, @"u", "a default credential set for a task reads back for it");
    __block NSDictionary *credentials = nil;
    ((void (*)(id, SEL, id, id, void (^)(NSDictionary *)))objc_msgSend)(storage,
        NSSelectorFromString(@"getCredentialsForProtectionSpace:task:completionHandler:"), space, task,
        ^(NSDictionary *found) { credentials = found; });
    CHECK(credentials.count > 0, "and the space's credentials come back through the task spelling");
    ((void (*)(id, SEL, id, id, id))objc_msgSend)(storage, removeTask, defaulted, space, nil, task);
    defaulted = nil;
    ((void (*)(id, SEL, id, id, void (^)(NSURLCredential *)))objc_msgSend)(storage,
        NSSelectorFromString(@"getDefaultCredentialForProtectionSpace:task:completionHandler:"), space, task,
        ^(NSURLCredential *found) { defaulted = found; });
    CHECK(defaulted == nil, "and the task spelling can take it away again");
    CHECK_EQUAL(NSURLCredentialStorageRemoveSynchronizableCredentials,
                @"NSURLCredentialStorageRemoveSynchronizableCredentials", "the option key carries its own name");
}

static void parser_operation_platform(void)
{
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[@"<a/>" dataUsingEncoding:NSUTF8StringEncoding]];
    CHECK(parser.externalEntityResolvingPolicy == NSXMLParserResolveExternalEntitiesNever,
          "a fresh parser resolves no external entity, as the header says");
    parser.externalEntityResolvingPolicy = NSXMLParserResolveExternalEntitiesAlways;
    CHECK(parser.allowedExternalEntityURLs == nil, "and allows no URL until it is given one");
    parser.allowedExternalEntityURLs = [NSSet setWithObject:[NSURL URLWithString:@"https://example.com/e.dtd"]];
    CHECK(parser.allowedExternalEntityURLs.count == 1, "while the set it is given is kept");
    CHECK(parser.shouldResolveExternalEntities, "and the policy reaches the release's own knob");

    NSOperation *operation = [[NSOperation alloc] init];
    CHECK(operation.name == nil, "a fresh operation has no name");
    operation.name = @"a name";
    CHECK_EQUAL(operation.name, @"a name", "and keeps the one it is given");
    operation.asynchronous = YES;
    CHECK(operation.isAsynchronous, "the asynchronous flag is kept as well");
    operation.asynchronous = NO;
    CHECK(!operation.isAsynchronous, "and can be taken back");

    NSProcessInfo *info = NSProcessInfo.processInfo;
    CHECK(!info.iOSAppOnMac && !info.macCatalystApp && !info.iOSAppOnVision && !info.lowPowerModeEnabled,
          "a device that is not a Mac, not a Catalyst build, not a Vision Pro and has no low power mode answers NO to all four");

    Class protocol = [NSURLProtocol class];
    CHECK([protocol respondsToSelector:NSSelectorFromString(@"canInitWithTask:")],
          "a protocol can be asked whether it serves a task");
    CHECK(![protocol canInitWithTask:[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"about:blank"]]],
          "and the base protocol does not serve a task with no request");
}

static void term_and_activity(void)
{
    Class term = NSClassFromString(@"NSTermOfAddress");
    CHECK(term != Nil, "NSTermOfAddress is there");
    if (!term)
        return;
    id neutral = ((id (*)(id, SEL))objc_msgSend)(term, @selector(neutral));
    id feminine = ((id (*)(id, SEL))objc_msgSend)(term, @selector(feminine));
    id masculine = ((id (*)(id, SEL))objc_msgSend)(term, @selector(masculine));
    id current = ((id (*)(id, SEL))objc_msgSend)(term, @selector(currentUser));
    CHECK(neutral && feminine && masculine && current, "the four terms are made");
    CHECK(![neutral isEqual:feminine] && ![neutral isEqual:masculine] && ![neutral isEqual:current],
          "and are four different terms");
    CHECK([neutral isEqual:[NSTermOfAddress neutral]] && neutral.hash == [NSTermOfAddress neutral].hash,
          "each is a singleton equal to itself and hashing alike");
    CHECK(neutral.languageIdentifier == nil && neutral.pronouns == nil,
          "with no language and no pronouns, as the host answers");
    CHECK([current isEqual:[NSTermOfAddress currentUser]], "the current user's term equals itself too");
    NSTermOfAddress *german = [NSTermOfAddress localizedForLanguageIdentifier:@"de" withPronouns:nil];
    NSTermOfAddress *germanAgain = [NSTermOfAddress localizedForLanguageIdentifier:@"de" withPronouns:nil];
    NSTermOfAddress *english = [NSTermOfAddress localizedForLanguageIdentifier:@"en" withPronouns:nil];
    NSTermOfAddress *empty = [NSTermOfAddress localizedForLanguageIdentifier:@"de" withPronouns:@[]];
    CHECK_EQUAL(german.languageIdentifier, @"de", "a localized term keeps its language");
    CHECK([german isEqual:germanAgain], "and equals another with the same language and pronouns");
    CHECK(![german isEqual:english], "but not one in another language");
    CHECK(![german isEqual:empty], "and not one whose pronouns are an empty array rather than nil");
    CHECK([german isEqual:[german copy]], "a copy is equal to the term it was made from");

    CHECK_EQUAL(NSPersonNameComponentKey, @"NSPersonNameComponentKey", "the key carries its own name");
    CHECK_EQUAL(NSPersonNameComponentGivenName, @"givenName", "the given name's attribute is givenName");
    CHECK_EQUAL(NSPersonNameComponentFamilyName, @"familyName", "the family name's is familyName");
    CHECK_EQUAL(NSPersonNameComponentMiddleName, @"middleName", "the middle name's is middleName");
    CHECK_EQUAL(NSPersonNameComponentPrefix, @"namePrefix", "the prefix's is namePrefix");
    CHECK_EQUAL(NSPersonNameComponentSuffix, @"nameSuffix", "the suffix's is nameSuffix");
    CHECK_EQUAL(NSPersonNameComponentNickname, @"nickname", "the nickname's is nickname");
    CHECK_EQUAL(NSPersonNameComponentDelimiter, @"delimiter", "and the separator's is delimiter");

    NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"charon.probe"];
    CHECK(activity.referrerURL == nil && activity.persistentIdentifier == nil, "a fresh activity has neither");
    activity.referrerURL = [NSURL URLWithString:@"https://example.com/"];
    activity.persistentIdentifier = @"an-identifier";
    CHECK_EQUAL(activity.referrerURL.absoluteString, @"https://example.com/", "the referrer is kept");
    CHECK_EQUAL(activity.persistentIdentifier, @"an-identifier", "and so is the identifier");
}

static void orthographies(void)
{
    for (NSString *language in @[@"de", @"en", @"ja", @"zh", @"ar", @"ru"]) {
        NSOrthography *orthography = ((id (*)(id, SEL, id))objc_msgSend)([NSOrthography class],
                                NSSelectorFromString(@"defaultOrthographyForLanguage:"), language);
        CHECK(orthography != nil, ([[NSString stringWithFormat:@"the default orthography of %@", language] UTF8String]));
        if (!orthography)
            continue;
        NSArray *scripts = ((id (*)(id, SEL))objc_msgSend)(orthography, NSSelectorFromString(@"allScripts"));
        CHECK(scripts.count > 0, ([[NSString stringWithFormat:@"%@ has a script, the release's ICU naming it",
                                    language] UTF8String]));
        CHECK_EQUAL(((NSString * (*)(id, SEL))objc_msgSend)(orthography, NSSelectorFromString(@"dominantLanguage")),
                    language, ([[NSString stringWithFormat:@"%@ is its own dominant language", language] UTF8String]));
    }
    CHECK(((id (*)(id, SEL, id))objc_msgSend)([NSOrthography class],
          NSSelectorFromString(@"defaultOrthographyForLanguage:"), @"") == nil, "an empty language has none");
}

static void absences(void)
{
    CHECK(NSClassFromString(@"NSKeyValueSharedObservers") == Nil, "no shared observers class is invented");
    CHECK(![NSUndoManager instancesRespondToSelector:NSSelectorFromString(@"undoActionUserInfoValueForKey:")],
          "the undo manager's per-action user info stays absent");
    CHECK(![NSUndoManager instancesRespondToSelector:NSSelectorFromString(@"undoCount")],
          "and so does its undo count");
    CHECK(![NSTextCheckingResult respondsToSelector:NSSelectorFromString(
              @"correctionCheckingResultWithRange:replacementString:alternativeStrings:")],
          "a correction result is not built on a private selector");
    CHECK(![NSProgress respondsToSelector:NSSelectorFromString(@"addSubscriberForFileURL:withPublishingHandler:")],
          "and the progress subscriber stays off, as iOS marks it");
    CHECK(![NSUserActivity respondsToSelector:NSSelectorFromString(
              @"deleteAllSavedUserActivitiesWithCompletionHandler:")],
          "the user activity store stays the system's, which the port cannot reach");
    CHECK(![NSXPCInterface respondsToSelector:NSSelectorFromString(@"setXPCType:forSelector:argumentIndex:ofReply:")],
          "the XPC interface's type table stays where the release keeps it");
    CHECK(![NSXPCCoder instancesRespondToSelector:NSSelectorFromString(@"connection")],
          "and a coder's connection stays the system's");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        progress_state();
        number_formatter();
        request_flags();
        url_encoding_and_promised();
        cache_and_credentials();
        parser_operation_platform();
        term_and_activity();
        orthographies();
        absences();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
