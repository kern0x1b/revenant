#import "RevenantCallKit.h"
#include <notify.h>

NSString *const revenant_call_screen_folder = @"/var/mobile/Library/Caches/org.revenant.callkit";
static const char *const revenant_call_incoming = "org.revenant.callkit.incoming";
static const char *const revenant_call_ended = "org.revenant.callkit.ended";
static const char *const revenant_call_answered = "org.revenant.callkit.answered";
static const char *const revenant_call_declined = "org.revenant.callkit.declined";

static NSString *revenant_call_file(NSString *name)
{
    return [revenant_call_screen_folder stringByAppendingPathComponent:name];
}

@implementation RevenantCallScreen {
    int _answered;
    int _declined;
    NSMutableDictionary<NSString *, CXProvider *> *_shown;
}

+ (instancetype)shared
{
    static RevenantCallScreen *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[RevenantCallScreen alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _answered = NOTIFY_TOKEN_INVALID;
        _declined = NOTIFY_TOKEN_INVALID;
        _shown = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)listen
{
    @synchronized (self) {
        if (_answered != NOTIFY_TOKEN_INVALID)
            return;
        __weak RevenantCallScreen *weak = self;
        notify_register_dispatch(revenant_call_answered, &_answered, dispatch_get_main_queue(), ^(int token) {
            (void)token;
            [weak person:YES];
        });
        notify_register_dispatch(revenant_call_declined, &_declined, dispatch_get_main_queue(), ^(int token) {
            (void)token;
            [weak person:NO];
        });
    }
}

- (void)person:(BOOL)answered
{
    NSString *identifier = [NSString stringWithContentsOfFile:revenant_call_file(answered ? @"answered" : @"declined")
                                                     encoding:NSUTF8StringEncoding error:NULL];
    NSUUID *UUID = identifier.length ? [[NSUUID alloc] initWithUUIDString:[identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]] : nil;
    if (!UUID)
        return;
    CXProvider *provider;
    @synchronized (self) {
        provider = _shown[UUID.UUIDString];
    }
    if (!provider || ![provider revenant_isValid])
        return;
    CXAction *action = answered ? (CXAction *)[[CXAnswerCallAction alloc] initWithCallUUID:UUID]
                                : (CXAction *)[[CXEndCallAction alloc] initWithCallUUID:UUID];
    [provider revenant_execute:[[CXTransaction alloc] initWithActions:@[action]]];
}

- (void)makeFolder
{
    NSFileManager *files = [NSFileManager defaultManager];
    if ([files fileExistsAtPath:revenant_call_screen_folder])
        return;
    [files createDirectoryAtPath:revenant_call_screen_folder withIntermediateDirectories:YES
                      attributes:@{NSFilePosixPermissions: @(0777)} error:NULL];
}

- (void)present:(CXCall *)call of:(CXProvider *)provider
{
    [self makeFolder];
    CXCallUpdate *update = call.revenant_update;
    NSString *bundle = [NSBundle mainBundle].bundleIdentifier ?: @"";
    NSDictionary *payload = @{@"UUID": call.UUID.UUIDString,
                              @"name": update.localizedCallerName ?: update.remoteHandle.value ?: @"",
                              @"handle": update.remoteHandle.value ?: @"",
                              @"handleType": @(update.remoteHandle ? update.remoteHandle.type : 0),
                              @"video": @(update.hasVideo),
                              @"application": bundle,
                              @"ringtone": provider.configuration.ringtoneSound ?: @""};
    NSData *written = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    if (!written || ![written writeToFile:revenant_call_file(@"incoming") atomically:YES])
        return;
    @synchronized (self) {
        _shown[call.UUID.UUIDString] = provider;
    }
    [self listen];
    notify_post(revenant_call_incoming);
}

- (void)dismiss:(CXCall *)call
{
    NSString *identifier = call.UUID.UUIDString;
    BOOL shown;
    @synchronized (self) {
        shown = _shown[identifier] != nil;
        [_shown removeObjectForKey:identifier];
    }
    if (!shown)
        return;
    [identifier writeToFile:revenant_call_file(@"ended") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    notify_post(revenant_call_ended);
}

@end
