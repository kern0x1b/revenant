#import <AuthenticationServices/AuthenticationServices.h>
#import <SafariServices/SafariServices.h>
#import "../SafariServices/CharonSafari.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

NSErrorDomain const ASWebAuthenticationSessionErrorDomain = @"com.apple.AuthenticationServices.WebAuthenticationSession";

static NSString *CharonWebAuthJournalPath(void)
{
    NSArray<NSString *> *directories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *directory = directories.firstObject ?: NSTemporaryDirectory();
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return [directory stringByAppendingPathComponent:@"charon-aswebauth-cookie-journal.plist"];
}

static void CharonWebAuthWriteJournal(NSArray<NSHTTPCookie *> *cookies, NSString *path)
{
    NSMutableArray<NSDictionary *> *properties = [NSMutableArray arrayWithCapacity:cookies.count];
    for (NSHTTPCookie *cookie in cookies)
        if (cookie.properties)
            [properties addObject:cookie.properties];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:properties format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    [data writeToFile:path atomically:YES];
}

static NSArray<NSDictionary *> *CharonWebAuthReadJournal(NSString *path)
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data)
        return nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    return [plist isKindOfClass:[NSArray class]] ? plist : nil;
}

static void CharonWebAuthReplaceCookies(NSArray<NSDictionary *> *properties)
{
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage.cookies copy])
        [storage deleteCookie:cookie];
    for (NSDictionary *property in properties) {
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:property];
        if (cookie)
            [storage setCookie:cookie];
    }
}

__attribute__((constructor)) static void charon_aswebauth_recover_journal(void)
{
    NSString *path = CharonWebAuthJournalPath();
    NSArray<NSDictionary *> *properties = CharonWebAuthReadJournal(path);
    if (!properties)
        return;
    CharonWebAuthReplaceCookies(properties);
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

@implementation ASWebAuthenticationSession {
    SFAuthenticationSession *_session;
    __weak id<ASWebAuthenticationPresentationContextProviding> _presentationContextProvider;
    BOOL _spent;
    BOOL _prefersEphemeralWebBrowserSession;
    BOOL _ephemeralJournalActive;
}

- (BOOL)prefersEphemeralWebBrowserSession
{
    return _prefersEphemeralWebBrowserSession;
}

- (void)setPrefersEphemeralWebBrowserSession:(BOOL)prefersEphemeralWebBrowserSession
{
    _prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession;
}

- (void)charon_restoreEphemeralJournal
{
    if (!_ephemeralJournalActive)
        return;
    _ephemeralJournalActive = NO;
    NSString *path = CharonWebAuthJournalPath();
    CharonWebAuthReplaceCookies(CharonWebAuthReadJournal(path));
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (instancetype)initWithURL:(NSURL *)URL callbackURLScheme:(NSString *)callbackURLScheme completionHandler:(ASWebAuthenticationSessionCompletionHandler)completionHandler
{
    self = [super init];
    if (self) {
        ASWebAuthenticationSessionCompletionHandler handler = [completionHandler copy];
        __weak ASWebAuthenticationSession *weakSelf = self;
        _session = [[SFAuthenticationSession alloc] initWithURL:URL callbackURLScheme:callbackURLScheme completionHandler:^(NSURL *callbackURL, NSError *error) {
            [weakSelf charon_restoreEphemeralJournal];
            if (!handler)
                return;
            NSError *mapped = error ? [NSError errorWithDomain:ASWebAuthenticationSessionErrorDomain code:ASWebAuthenticationSessionErrorCodeCanceledLogin userInfo:nil] : nil;
            handler(callbackURL, mapped);
        }];
    }
    return self;
}

- (id<ASWebAuthenticationPresentationContextProviding>)presentationContextProvider
{
    return _presentationContextProvider;
}

- (void)setPresentationContextProvider:(id<ASWebAuthenticationPresentationContextProviding>)presentationContextProvider
{
    _presentationContextProvider = presentationContextProvider;
}

- (BOOL)canStart
{
    return !_spent;
}

- (BOOL)start
{
    if (_prefersEphemeralWebBrowserSession && !_ephemeralJournalActive) {
        CharonWebAuthWriteJournal([NSHTTPCookieStorage sharedHTTPCookieStorage].cookies, CharonWebAuthJournalPath());
        CharonWebAuthReplaceCookies(@[]);
        _ephemeralJournalActive = YES;
    }
    id<ASWebAuthenticationPresentationContextProviding> provider = _presentationContextProvider;
    if ([provider respondsToSelector:@selector(presentationAnchorForWebAuthenticationSession:)]) {
        UIWindow *anchor = [provider presentationAnchorForWebAuthenticationSession:self];
        if (anchor)
            _session.charon_presentationWindow = anchor;
    }
    BOOL started = [_session start];
    _spent = _spent || started;
    if (!started)
        [self charon_restoreEphemeralJournal];
    return started;
}

- (void)cancel
{
    _spent = YES;
    [_session cancel];
    [self charon_restoreEphemeralJournal];
}

@end
