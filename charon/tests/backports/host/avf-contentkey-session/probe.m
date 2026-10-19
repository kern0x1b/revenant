// probe.m - AVContentKeySession, AVContentKeyRequest and AVContentKey (10.3 to 14.5), asked of the host's own
// AVFoundation and of the port's classes in one binary (run.sh builds it both ways and diffs the output). Each line is one
// answer with a label; no answer names a class, since the host's private subclasses are not the port's, and a class is
// asked about with isKindOfClass: where the answer is a class.
//
// What is not asked here, and why: -expire (the host forwards it to its delegate and raises when the delegate lacks it,
// a host behaviour the port does not reproduce), and the persistable paths that need a key to persist (no ClearKey or
// FairPlay request in this probe can be made persistable; facts/AVFoundation/ContentKeySession.md).
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

static void spin(double seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static NSString *Describe(NSError *e)
{
    if (!e) return @"none";
    NSError *underlying = e.userInfo[NSUnderlyingErrorKey];
    return [NSString stringWithFormat:@"%@ %ld underlying=%@", e.domain, (long)e.code,
            underlying ? [NSString stringWithFormat:@"%@ %ld", underlying.domain, (long)underlying.code] : @"none"];
}

// The host's refusals of a key response are not stable: the same vector gets CoreMedia -12160 in some runs and AVFoundation
// -11800 wrapping -12160 in others (ten runs, facts/AVFoundation/ContentKeySession.md). So stdout records that the request
// was refused, which is stable, and the shape goes to stderr as a measurement that run.sh does not diff. The probe's own
// error (domain "probe") is stable, so it is printed in full.
static BOOL RefusalShapeVaries(NSError *e)
{
    return e && ![e.domain isEqualToString:@"probe"];
}

static NSString *Stable(NSError *e)
{
    if (!e) return @"none";
    return RefusalShapeVaries(e) ? @"refused" : Describe(e);
}

// The success callback and the recipient's key callback are delivered in an order the host varies run to run (ten runs:
// the recipient first in some, the delegate first in others). While a case runs they are collected here; Case prints them
// sorted, so the diff does not depend on that order, and the order that happened goes to stderr.
static NSMutableArray<NSString *> *Events;

static void Emit(NSString *line)
{
    if (Events) [Events addObject:line];
    else printf("%s\n", [line UTF8String]);
}

// The delegate records what it hears and answers the request it is handed with the response the case asks for.
@interface Delegate : NSObject <AVContentKeySessionDelegate>
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSString *answer;     // clear-16, clear-iv:<n>, clear-key:<n>, fairplay, token, error, none
@property (nonatomic) BOOL batch;
@property (nonatomic, strong) AVContentKeyRequest *held;
@end

@implementation Delegate

- (void)answerRequest:(AVContentKeyRequest *)request
{
    self.held = request;
    printf("%s request status=%ld identifier=%s initData=%s options=%s\n", [self.tag UTF8String], (long)request.status,
           [[request.identifier description] UTF8String], [request.initializationData ? @"data" : @"nil" UTF8String],
           [[[[request.options allKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","] UTF8String]);
    printf("%s request persistable=%d renews=%d\n", [self.tag UTF8String], request.canProvidePersistableContentKey, request.renewsExpiringResponseData);
    AVContentKeySpecifier *specifier = request.contentKeySpecifier;
    printf("%s request specifier keySystem=%s identifier=%s\n", [self.tag UTF8String], [[specifier.keySystem description] UTF8String],
           [[specifier.identifier description] UTF8String]);
    printf("%s request contentKey=%d\n", [self.tag UTF8String], request.contentKey != nil);
    NSString *a = self.answer;
    if ([a hasPrefix:@"clear-iv:"]) {
        NSUInteger n = [[a substringFromIndex:9] integerValue];
        [request processContentKeyResponse:[AVContentKeyResponse contentKeyResponseWithClearKeyData:[NSMutableData dataWithLength:16]
                                                                               initializationVector:[NSMutableData dataWithLength:n]]];
    } else if ([a hasPrefix:@"clear-key:"]) {
        NSUInteger n = [[a substringFromIndex:10] integerValue];
        [request processContentKeyResponse:[AVContentKeyResponse contentKeyResponseWithClearKeyData:[NSMutableData dataWithLength:n]
                                                                               initializationVector:[NSMutableData dataWithLength:16]]];
    } else if ([a isEqualToString:@"clear-16"]) {
        [request processContentKeyResponse:[AVContentKeyResponse contentKeyResponseWithClearKeyData:[NSMutableData dataWithLength:16]
                                                                               initializationVector:[NSMutableData dataWithLength:16]]];
    } else if ([a isEqualToString:@"fairplay"]) {
        [request processContentKeyResponse:[AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:
            [@"ckc" dataUsingEncoding:NSUTF8StringEncoding]]];
    } else if ([a isEqualToString:@"token"]) {
        [request processContentKeyResponse:[AVContentKeyResponse contentKeyResponseWithAuthorizationTokenData:
            [@"tok" dataUsingEncoding:NSUTF8StringEncoding]]];
    } else if ([a isEqualToString:@"error"]) {
        [request processContentKeyResponseError:[NSError errorWithDomain:@"probe" code:42 userInfo:nil]];
    }
    if ([a hasPrefix:@"clear"] || [a isEqualToString:@"fairplay"] || [a isEqualToString:@"token"] || [a isEqualToString:@"error"]) {
        printf("%s after status=%ld error=%s\n", [self.tag UTF8String], (long)request.status, [Stable(request.error) UTF8String]);
        if (RefusalShapeVaries(request.error)) fprintf(stderr, "%s shape %s\n", [self.tag UTF8String], [Describe(request.error) UTF8String]);
    }
}

- (void)contentKeySession:(AVContentKeySession *)session didProvideContentKeyRequest:(AVContentKeyRequest *)keyRequest
{
    [self answerRequest:keyRequest];
}

- (void)contentKeySession:(AVContentKeySession *)session contentKeyRequest:(AVContentKeyRequest *)keyRequest didFailWithError:(NSError *)err
{
    printf("%s didFailWithError %s\n", [self.tag UTF8String], [Stable(err) UTF8String]);
    if (RefusalShapeVaries(err)) fprintf(stderr, "%s shape %s\n", [self.tag UTF8String], [Describe(err) UTF8String]);
}

- (void)contentKeySession:(AVContentKeySession *)session contentKeyRequestDidSucceed:(AVContentKeyRequest *)keyRequest
{
    Emit([NSString stringWithFormat:@"%@ didSucceed status=%ld", self.tag, (long)keyRequest.status]);
}

@end

@interface BatchDelegate : Delegate <AVContentKeySessionDelegate>
@end

@implementation BatchDelegate

- (void)contentKeySession:(AVContentKeySession *)session didProvideContentKeyRequests:(NSArray<AVContentKeyRequest *> *)keyRequests
    forInitializationData:(NSData *)initializationData
{
    printf("%s batch count=%lu initData=%s\n", [self.tag UTF8String], (unsigned long)keyRequests.count, [initializationData ? @"data" : @"nil" UTF8String]);
    for (AVContentKeyRequest *request in keyRequests) [self answerRequest:request];
}

@end

// A recipient that asks for keys and records the key it is given.
@interface Recipient : NSObject <AVContentKeyRecipient>
@property (nonatomic, copy) NSString *tag;
@end

@implementation Recipient

- (BOOL)mayRequireContentKeysForMediaDataProcessing
{
    return YES;
}

- (void)contentKeySession:(AVContentKeySession *)session didProvideContentKey:(AVContentKey *)contentKey
{
    Emit([NSString stringWithFormat:@"%@ didProvideContentKey isAVContentKey=%d keySystem=%@ identifier=%@ protection=%ld", self.tag,
          [contentKey isKindOfClass:[AVContentKey class]], contentKey.contentKeySpecifier.keySystem,
          contentKey.contentKeySpecifier.identifier, (long)contentKey.externalContentProtectionStatus]);
    [contentKey revoke];
    Emit([NSString stringWithFormat:@"%@ revoke answered", self.tag]);
}

@end

// One case: a session for a key system, a delegate that answers as asked, a request with the initialization data given.
static Delegate *Case(NSString *tag, NSString *system, NSString *answer, NSData *initData, BOOL batch, BOOL recipient)
{
    AVContentKeySession *session = [AVContentKeySession contentKeySessionWithKeySystem:system];
    printf("%s session keySystem=%s storageURL=%s protectionIdLength=%lu\n", [tag UTF8String], [[session.keySystem description] UTF8String],
           [[session.storageURL description] UTF8String], (unsigned long)[session.contentProtectionSessionIdentifier length]);
    Delegate *delegate = batch ? [BatchDelegate new] : [Delegate new];
    delegate.tag = tag;
    delegate.answer = answer;
    delegate.batch = batch;
    [session setDelegate:delegate queue:dispatch_get_main_queue()];
    printf("%s delegate kept=%d\n", [tag UTF8String], session.delegate == delegate);
    if (recipient) {
        Recipient *r = [Recipient new];
        r.tag = tag;
        [session addContentKeyRecipient:r];
        printf("%s recipients=%lu\n", [tag UTF8String], (unsigned long)session.contentKeyRecipients.count);
    }
    Events = [NSMutableArray array];
    [session processContentKeyRequestWithIdentifier:@"skd://probe" initializationData:initData options:nil];
    spin(0.6);
    if (initData) printf("%s after non-nil initData: no callback expected\n", [tag UTF8String]);
    for (NSString *line in [Events sortedArrayUsingSelector:@selector(compare:)]) printf("%s\n", [line UTF8String]);
    for (NSString *line in Events) fprintf(stderr, "order %s\n", [line UTF8String]);
    Events = nil;
    return delegate;
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        // Session creation and refusals.
        for (NSString *system in @[AVContentKeySystemClearKey, AVContentKeySystemFairPlayStreaming, AVContentKeySystemAuthorizationToken]) {
            AVContentKeySession *s = [AVContentKeySession contentKeySessionWithKeySystem:system];
            printf("create %s keySystem=%s\n", [system UTF8String], [[s.keySystem description] UTF8String]);
        }
        @try {
            [AVContentKeySession contentKeySessionWithKeySystem:@"NoSuchSystem"];
            printf("unknown system: no raise\n");
        } @catch (NSException *e) {
            printf("unknown system raised %s: %s\n", [e.name UTF8String], [[e reason] UTF8String]);
        }
        // A storage directory: FairPlay keeps it (its storageURL is the directory given); ClearKey and the token system
        // refuse one with their own reason. The path is printed by its last component, so the output does not depend on
        // the working directory.
        NSURL *storageDirectory = [NSURL fileURLWithPath:@"avf-contentkey-session-storage"];
        for (NSString *system in @[AVContentKeySystemClearKey, AVContentKeySystemAuthorizationToken]) {
            @try {
                [AVContentKeySession contentKeySessionWithKeySystem:system storageDirectoryAtURL:storageDirectory];
                printf("storage %s: no raise\n", [system UTF8String]);
            } @catch (NSException *e) {
                printf("storage %s raised %s: %s\n", [system UTF8String], [e.name UTF8String], [[e reason] UTF8String]);
            }
        }
        AVContentKeySession *stored = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming
                                                                    storageDirectoryAtURL:storageDirectory];
        printf("stored storageURL last=%s\n", [[stored.storageURL lastPathComponent] UTF8String]);

        // Callbacks: singular, batch, and the initialization-data refusal to call back at all.
        Case(@"C1 clear singular", AVContentKeySystemClearKey, @"clear-16", nil, NO, NO);
        Case(@"C2 clear batch", AVContentKeySystemClearKey, @"clear-16", nil, YES, NO);
        Case(@"C3 clear init-data", AVContentKeySystemClearKey, @"clear-16", [@"init" dataUsingEncoding:NSUTF8StringEncoding], YES, NO);
        Case(@"C4 fairplay singular", AVContentKeySystemFairPlayStreaming, @"fairplay", nil, NO, NO);
        Case(@"C5 token singular", AVContentKeySystemAuthorizationToken, @"token", nil, NO, NO);

        // The clear key success path, with a recipient that receives the key.
        Case(@"R1 clear recipient", AVContentKeySystemClearKey, @"clear-16", nil, NO, YES);

        // The clear key vectors, 0 to 34 (measured table), and the key lengths the host accepts.
        for (NSUInteger n = 0; n <= 34; n++) {
            Case([NSString stringWithFormat:@"V%02lu iv", (unsigned long)n], AVContentKeySystemClearKey,
                 [NSString stringWithFormat:@"clear-iv:%lu", (unsigned long)n], nil, NO, NO);
        }
        Case(@"K0 clear key 0", AVContentKeySystemClearKey, @"clear-key:0", nil, NO, NO);
        Case(@"K4 clear key 4", AVContentKeySystemClearKey, @"clear-key:4", nil, NO, NO);
        Case(@"K32 clear key 32", AVContentKeySystemClearKey, @"clear-key:32", nil, NO, NO);

        // FairPlay refused responses, and the error the request reports.
        Case(@"F1 fairplay response", AVContentKeySystemFairPlayStreaming, @"fairplay", nil, NO, NO);
        Case(@"E1 error given", AVContentKeySystemClearKey, @"error", nil, NO, NO);

        // The streaming request data a FairPlay and a ClearKey request make, which the host refuses without the key services.
        for (NSString *system in @[AVContentKeySystemFairPlayStreaming, AVContentKeySystemClearKey]) {
            AVContentKeySession *s = [AVContentKeySession contentKeySessionWithKeySystem:system];
            Delegate *d = [Delegate new];
            d.tag = [NSString stringWithFormat:@"S %@", system];
            d.answer = @"none";
            [s setDelegate:d queue:dispatch_get_main_queue()];
            [s processContentKeyRequestWithIdentifier:@"skd://stream" initializationData:nil options:nil];
            spin(0.6);
            AVContentKeyRequest *held = d.held;
            __block BOOL answered = NO;
            [held makeStreamingContentKeyRequestDataForApp:[@"app" dataUsingEncoding:NSUTF8StringEncoding]
                                          contentIdentifier:[@"skd://stream" dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:nil
                                          completionHandler:^(NSData *spc, NSError *e) {
                printf("%s streaming spc=%s error=%s\n", [d.tag UTF8String], spc ? "data" : "nil", [Describe(e) UTF8String]);
                answered = YES;
            }];
            spin(0.6);
            printf("%s streaming answered=%d\n", [d.tag UTF8String], answered);
        }

        // Persistence, renewal and invalidation: refused by the ClearKey system, each with its reason.
        AVContentKeySession *p = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemClearKey];
        Delegate *pd = [Delegate new];
        pd.tag = @"P";
        pd.answer = @"none";
        [p setDelegate:pd queue:dispatch_get_main_queue()];
        [p processContentKeyRequestWithIdentifier:@"skd://persist" initializationData:nil options:nil];
        spin(0.6);
        @try {
            [p renewExpiringResponseDataForContentKeyRequest:pd.held];
            printf("renew: no raise\n");
        } @catch (NSException *e) {
            printf("renew raised %s: %s\n", [e.name UTF8String], [[e reason] UTF8String]);
        }
        NSError *persistError = nil;
        @try {
            BOOL ok = [pd.held respondByRequestingPersistableContentKeyRequestAndReturnError:&persistError];
            printf("respondByPersistable ok=%d\n", ok);
        } @catch (NSException *e) {
            printf("respondByPersistable raised %s: %s\n", [e.name UTF8String], [[e reason] UTF8String]);
        }
        @try {
            [p makeSecureTokenForExpirationDateOfPersistableContentKey:[@"expiry" dataUsingEncoding:NSUTF8StringEncoding]
                                                     completionHandler:^(NSData *token, NSError *e) { }];
            printf("secureToken: no raise\n");
        } @catch (NSException *e) {
            printf("secureToken raised %s: %s\n", [e.name UTF8String], [[e reason] UTF8String]);
        }
        @try {
            [p invalidatePersistableContentKey:[@"key" dataUsingEncoding:NSUTF8StringEncoding] options:nil
                             completionHandler:^(NSData *t, NSError *e) { }];
            printf("invalidate: no raise\n");
        } @catch (NSException *e) {
            printf("invalidate raised %s: %s\n", [e.name UTF8String], [[e reason] UTF8String]);
        }
        @try {
            [p invalidateAllPersistableContentKeysForApp:[@"app" dataUsingEncoding:NSUTF8StringEncoding] options:nil
                                       completionHandler:^(NSData *t, NSError *e) { }];
            printf("invalidateAll: no raise\n");
        } @catch (NSException *e) {
            printf("invalidateAll raised %s: %s\n", [e.name UTF8String], [[e reason] UTF8String]);
        }

        // The storage's reports: none pending in an empty directory.
        NSData *app = [@"app" dataUsingEncoding:NSUTF8StringEncoding];
        NSURL *dir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        printf("pending reports=%lu\n", (unsigned long)[[AVContentKeySession pendingExpiredSessionReportsWithAppIdentifier:app storageDirectoryAtURL:dir] count]);
        [AVContentKeySession removePendingExpiredSessionReports:@[] withAppIdentifier:app storageDirectoryAtURL:dir];
        printf("removePending returned\n");
    }
    return 0;
}
