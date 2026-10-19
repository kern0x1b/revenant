#import "CharonCallKit.h"
#include <notify.h>

// The application's side of the system call screen. The screen itself belongs
// to SpringBoard, which no library of an application can draw in, so what a
// provider does here is say that a call has arrived and listen for what the
// person did with it. The tweak in SpringBoard is the other side.
//
// The two sides speak in Darwin notifications and a file, because that is
// what crosses the boundary on this release: a Darwin notification reaches
// every process whatever its sandbox but carries nothing, and a file carries
// the call but is only readable where both sides may reach it.
//
// Nothing here fails loudly. An application whose device has no such tweak
// installed writes a file nobody reads and posts a notification nobody hears,
// and its calls work exactly as they do without a screen - which is what the
// backports do without the tweak anyway.

NSString *const charon_call_screen_folder = @"/var/mobile/Library/Caches/org.charon.callkit";
static const char *const charon_call_incoming = "org.charon.callkit.incoming";
static const char *const charon_call_ended = "org.charon.callkit.ended";
static const char *const charon_call_answered = "org.charon.callkit.answered";
static const char *const charon_call_declined = "org.charon.callkit.declined";

static NSString *charon_call_file(NSString *name)
{
    return [charon_call_screen_folder stringByAppendingPathComponent:name];
}

@implementation CharonCallScreen {
    int _answered;
    int _declined;
    NSMutableDictionary<NSString *, CXProvider *> *_shown;
}

+ (instancetype)shared
{
    static CharonCallScreen *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonCallScreen alloc] init];
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
        __weak CharonCallScreen *weak = self;
        notify_register_dispatch(charon_call_answered, &_answered, dispatch_get_main_queue(), ^(int token) {
            (void)token;
            [weak person:YES];
        });
        notify_register_dispatch(charon_call_declined, &_declined, dispatch_get_main_queue(), ^(int token) {
            (void)token;
            [weak person:NO];
        });
    }
}

// What the person did on the screen becomes the transaction they would have
// asked for by hand, so the provider's delegate is called exactly as it is
// when the application answers a call from its own interface.
- (void)person:(BOOL)answered
{
    NSString *identifier = [NSString stringWithContentsOfFile:charon_call_file(answered ? @"answered" : @"declined")
                                                     encoding:NSUTF8StringEncoding error:NULL];
    NSUUID *UUID = identifier.length ? [[NSUUID alloc] initWithUUIDString:[identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]] : nil;
    if (!UUID)
        return;
    CXProvider *provider;
    @synchronized (self) {
        provider = _shown[UUID.UUIDString];
    }
    if (!provider || ![provider charon_isValid])
        return;
    CXAction *action = answered ? (CXAction *)[[CXAnswerCallAction alloc] initWithCallUUID:UUID]
                                : (CXAction *)[[CXEndCallAction alloc] initWithCallUUID:UUID];
    [provider charon_execute:[[CXTransaction alloc] initWithActions:@[action]]];
}

// Either side may be the first to run, so either side makes the folder, and
// it is made writable by everyone: the applications that write into it are
// not the user SpringBoard is, and there is no group the two share.
- (void)makeFolder
{
    NSFileManager *files = [NSFileManager defaultManager];
    if ([files fileExistsAtPath:charon_call_screen_folder])
        return;
    [files createDirectoryAtPath:charon_call_screen_folder withIntermediateDirectories:YES
                      attributes:@{NSFilePosixPermissions: @(0777)} error:NULL];
}

- (void)present:(CXCall *)call of:(CXProvider *)provider
{
    [self makeFolder];
    CXCallUpdate *update = call.charon_update;
    NSString *bundle = [NSBundle mainBundle].bundleIdentifier ?: @"";
    NSDictionary *payload = @{@"UUID": call.UUID.UUIDString,
                              @"name": update.localizedCallerName ?: update.remoteHandle.value ?: @"",
                              @"handle": update.remoteHandle.value ?: @"",
                              @"handleType": @(update.remoteHandle ? update.remoteHandle.type : 0),
                              @"video": @(update.hasVideo),
                              @"application": bundle,
                              @"ringtone": provider.configuration.ringtoneSound ?: @""};
    NSData *written = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    if (!written || ![written writeToFile:charon_call_file(@"incoming") atomically:YES])
        return;
    @synchronized (self) {
        _shown[call.UUID.UUIDString] = provider;
    }
    [self listen];
    notify_post(charon_call_incoming);
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
    [identifier writeToFile:charon_call_file(@"ended") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    notify_post(charon_call_ended);
}

@end
