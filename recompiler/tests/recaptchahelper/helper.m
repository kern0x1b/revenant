#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <TargetConditionals.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/loader.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/time.h>
#include <unistd.h>

#include "protocol.h"
#ifndef RCHELPER_NATIVE
#include "xl_loader.h"
#endif

#ifndef CONTROL
#define CONTROL 0
#endif
#define STDOUT_KEPT 1
#define NO_DEADLINE 2
#define ANSWERED_TWICE 3
#define NO_ESCAPES 4
#define END_IGNORED 5
#define NO_IDLE_EXIT 6
#define DUPLICATE_TAKEN 7
#define PIPE_SIGNAL 8
#define LEFT_TWICE 9
#define COOKIES_ELSEWHERE 10
#define HOME_KEPT 11

static int answers = 1;
static NSString *state;
static NSUserDefaults *domain;
static NSURLCache *cache;
static NSHTTPCookieStorage *jar;
static unsigned long outside;
static NSMutableDictionary *pending;
static NSMutableDictionary *clients;
static NSMutableDictionary *fetching;
static Class recaptcha, actions;
static long idle_ms = 120000;
static unsigned long idle_turn;
static unsigned long serials;
static char line_out[RC_LINE_MOST];

__attribute__((noreturn)) static void fail(NSString *name, NSString *text);

static double now(void)
{
    struct timeval t;
    gettimeofday(&t, NULL);
    return (double)t.tv_sec + (double)t.tv_usec / 1e6;
}

static void note(NSString *text)
{
    NSData *line = [[NSString stringWithFormat:@"rchelper: %@\n", text] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    rc_write_all(2, line.bytes, line.length);
}

static NSString *preferences_name(void)
{
#if TARGET_OS_IPHONE
    return state;
#else
    return [state stringByAppendingPathComponent:@"preferences"];
#endif
}

static NSString *own_home(void)
{
#if TARGET_OS_IPHONE
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"] stringByAppendingPathComponent:state];
#else
    return [state stringByAppendingPathComponent:@"home"];
#endif
}

static NSString *regional(void)
{
    NSString *(^read)(CFStringRef) = ^NSString *(CFStringRef key) {
        CFPropertyListRef value = CFPreferencesCopyAppValue(key, kCFPreferencesCurrentApplication);
        NSString *text = value ? [(__bridge id)value isKindOfClass:[NSArray class]] ? [(__bridge NSArray *)value componentsJoinedByString:@","] : [(__bridge id)value description] : @"none";
        if (value)
            CFRelease(value);
        return text;
    };
    return [NSString stringWithFormat:@"%@ %@", read(CFSTR("AppleLanguages")), read(CFSTR("AppleLocale"))];
}

static NSString *regional_shown(void)
{
#if TARGET_OS_IPHONE
    return regional();
#else
    return @"not shown on the build host";
#endif
}

static void move_home(void)
{
    if (CONTROL == HOME_KEPT)
        return;
    NSString *home = own_home();
    NSString *before = regional();
    for (NSString *folder in @[@"Library/Caches", @"Library/Preferences"]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[home stringByAppendingPathComponent:folder] withIntermediateDirectories:YES attributes:nil error:&error])
            fail(@"NO_HOME", [NSString stringWithFormat:@"the helper's home %@ cannot be made: %@", home, error.localizedDescription]);
    }
    setenv("CFFIXED_USER_HOME", home.fileSystemRepresentation, 1);
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (![caches hasPrefix:[home stringByAppendingString:@"/"]])
        fail(@"NO_HOME", [NSString stringWithFormat:@"after CFFIXED_USER_HOME was set to %@ the caches folder is %@, so what the library writes there would land outside the helper's state", home, caches]);
    NSString *after = regional();
    if (![after isEqualToString:before])
        fail(@"NO_HOME", [NSString stringWithFormat:@"moving the home to %@ changed the languages and the locale the process reads from the global preferences, which the SDK sends: before [%@], after [%@]", home, before, after]);
}

static NSURLCache *own_cache(void)
{
#if TARGET_OS_IPHONE
    return [[NSURLCache alloc] initWithMemoryCapacity:512 * 1024 diskCapacity:10 * 1024 * 1024 diskPath:state];
#else
    return [[NSURLCache alloc] initWithMemoryCapacity:512 * 1024 diskCapacity:10 * 1024 * 1024 directoryURL:[NSURL fileURLWithPath:[state stringByAppendingPathComponent:@"cache"]]];
#endif
}

static NSUserDefaults *own_defaults(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if ([NSUserDefaults instancesRespondToSelector:@selector(initWithSuiteName:)])
            domain = [[NSUserDefaults alloc] initWithSuiteName:preferences_name()];
    });
    if (!domain) {
        note(@"NSUserDefaults has no initWithSuiteName:, so no preferences domain of the helper's own can be made, and the standard one is the app's: the process stops here");
        abort();
    }
    return domain;
}

static BOOL cookies_possible(void)
{
    return [NSClassFromString(@"NSURLSessionConfiguration") respondsToSelector:@selector(ephemeralSessionConfiguration)];
}

static NSHTTPCookieStorage *own_cookies(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (cookies_possible())
            jar = [[NSClassFromString(@"NSURLSessionConfiguration") ephemeralSessionConfiguration] HTTPCookieStorage];
    });
    if (!jar) {
        note(@"there is no NSURLSessionConfiguration to take a cookie store of the helper's own from, and the shared one is not the helper's: the process stops here");
        abort();
    }
    return jar;
}

static void redirect(void)
{
    Method standard = class_getClassMethod([NSUserDefaults class], @selector(standardUserDefaults));
    method_setImplementation(standard, imp_implementationWithBlock(^id(id self) {
        return own_defaults();
    }));
    cache = own_cache();
    [NSURLCache setSharedURLCache:cache];
    Method shared = class_getClassMethod([NSHTTPCookieStorage class], @selector(sharedHTTPCookieStorage));
#if TARGET_OS_IPHONE
    NSHTTPCookieStorage *(*original)(id, SEL) = (NSHTTPCookieStorage *(*)(id, SEL))method_getImplementation(shared);
    outside = (unsigned long)original([NSHTTPCookieStorage class], @selector(sharedHTTPCookieStorage)).cookies.count;
#endif
    method_setImplementation(shared, imp_implementationWithBlock(^id(id self) {
        static NSHTTPCookieStorage *elsewhere;
        static dispatch_once_t once;
        if (CONTROL != COOKIES_ELSEWHERE)
            return own_cookies();
        dispatch_once(&once, ^{
            elsewhere = [[NSClassFromString(@"NSURLSessionConfiguration") ephemeralSessionConfiguration] HTTPCookieStorage];
        });
        return elsewhere;
    }));
}

static void look(NSString *when)
{
    CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)preferences_name(), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    long kept = keys ? (long)CFArrayGetCount(keys) : 0;
    if (keys)
        CFRelease(keys);
    NSURLCache *shared = [NSURLCache sharedURLCache];
    note([NSString stringWithFormat:@"%@: state=%@ preferences keys=%ld url cache own=%d disk=%lu memory=%lu cookies own=%lu, in the store the process was given=%lu caches=%@ regional=%@", when, state, kept,
                                     shared == cache, (unsigned long)shared.currentDiskUsage, (unsigned long)shared.currentMemoryUsage, (unsigned long)jar.cookies.count, outside,
                                     NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject, regional_shown()]);
}

__attribute__((noreturn)) static void leave(int code, NSString *why)
{
    static int leaving;
    if (CONTROL != LEFT_TWICE && __atomic_exchange_n(&leaving, 1, __ATOMIC_SEQ_CST)) {
        for (;;)
            pause();
    }
    look(why);
    [domain synchronize];
    _exit(code);
}

static void watch(void)
{
    alarm((unsigned)(idle_ms / 1000 + RC_ALLOWED_MOST / 1000 + 30));
}

static BOOL say(NSArray *fields, BOOL ascii)
{
    struct rc_field parts[RC_FIELDS_MOST];
    NSMutableArray *kept = [NSMutableArray array];
    int count = 0;
    for (id field in fields) {
        NSData *bytes = [field isKindOfClass:[NSData class]] ? field : [[field description] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        bytes = bytes ?: [NSData data];
        [kept addObject:bytes];
        parts[count++] = (struct rc_field){bytes.bytes, bytes.length};
    }
    size_t length = 0;
    if (CONTROL == NO_ESCAPES) {
        for (int i = 0; i < count; i++) {
            if (length + parts[i].length + 1 > sizeof line_out)
                return NO;
            memcpy(line_out + length, parts[i].bytes, parts[i].length);
            length += parts[i].length;
            line_out[length++] = i + 1 < count ? '\t' : '\n';
        }
    } else {
        length = rc_build(line_out, sizeof line_out, parts, count, ascii);
        if (length == (size_t)-1)
            return NO;
    }
    if (rc_write_all(answers, line_out, length) != 0)
        leave(0, @"the app closed the answer pipe");
    watch();
    return YES;
}

__attribute__((noreturn)) static void fail(NSString *name, NSString *text)
{
    say(@[@"failed", name, text], NO);
    note([NSString stringWithFormat:@"failed %@: %@", name, text]);
    _exit(3);
}

static void idle_arm(void)
{
    unsigned long turn = ++idle_turn;
    if (CONTROL == NO_IDLE_EXIT)
        return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, idle_ms * (int64_t)NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (turn == idle_turn && !pending.count)
            leave(0, @"no request for the idle time");
    });
}

static BOOL take(NSString *identifier, unsigned long serial)
{
    if ([pending[identifier] unsignedLongValue] != serial)
        return NO;
    if (CONTROL != ANSWERED_TWICE)
        [pending removeObjectForKey:identifier];
    if (!pending.count)
        idle_arm();
    return YES;
}

static void answer_token(NSString *identifier, unsigned long serial, NSString *token)
{
    if (!take(identifier, serial))
        return;
    if (!say(@[@"token", identifier, @"ok", token], NO))
        say(@[@"token", identifier, @"error", @"EXECUTE_FAILED", @"rchelper", @"0", @"the token does not fit a line of the protocol"], NO);
}

static void answer_error(NSString *identifier, unsigned long serial, NSString *name, NSString *where, long code, NSString *text)
{
    if (!take(identifier, serial))
        return;
    NSString *number = [NSString stringWithFormat:@"%ld", code];
    if (!say(@[@"token", identifier, @"error", name, where ?: @"", number, text ?: @""], NO))
        say(@[@"token", identifier, @"error", name, @"rchelper", @"0", @"the error does not fit a line of the protocol"], NO);
}

static id make_action(NSString *name)
{
    Class meta = object_getClass(actions);
    for (NSString *known in @[@"login", @"signup"]) {
        SEL getter = sel_registerName(known.UTF8String);
        if ([name isEqualToString:known] && class_respondsToSelector(meta, getter))
            return ((id (*)(Class, SEL))objc_msgSend)(actions, getter);
    }
    return ((id (*)(Class, SEL, id))objc_msgSend)(actions, sel_registerName("custom:"), name);
}

static void run(NSString *identifier, unsigned long serial, id client, NSString *action)
{
    if ([pending[identifier] unsignedLongValue] != serial)
        return;
    SEL selector = sel_registerName("executeWithAction:completion:");
    id made = make_action(action);
    if (!made || !class_respondsToSelector(object_getClass(client), selector)) {
        answer_error(identifier, serial, @"EXECUTE_FAILED", @"rchelper", 0, @"the library's client does not answer executeWithAction:completion:, or the library has no action of that name");
        return;
    }
    void (^done)(id, id) = ^(id token, id error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *failure = error;
            if (token)
                answer_token(identifier, serial, [token description]);
            else if (failure)
                answer_error(identifier, serial, @"EXECUTE_FAILED", failure.domain, (long)failure.code, failure.localizedDescription);
            else
                answer_error(identifier, serial, @"EXECUTE_FAILED", @"rchelper", 0, @"the SDK answered with neither a token nor an error");
        });
    };
    ((void (*)(id, SEL, id, id))objc_msgSend)(client, selector, made, done);
}

static void want(NSString *identifier, unsigned long serial, NSString *key, NSString *action)
{
    id client = clients[key];
    if (client) {
        run(identifier, serial, client, action);
        return;
    }
    NSArray *asked = @[identifier, @(serial), action];
    NSMutableArray *waiting = fetching[key];
    if (waiting) {
        [waiting addObject:asked];
        return;
    }
    waiting = [NSMutableArray arrayWithObject:asked];
    fetching[key] = waiting;
    void (^fetched)(id, id) = ^(id got, id error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *failure = error;
            if (got && !clients[key])
                clients[key] = got;
            if (fetching[key] == waiting)
                [fetching removeObjectForKey:key];
            NSArray *served = [waiting copy];
            [waiting removeAllObjects];
            for (NSArray *one in served) {
                if (got)
                    run(one[0], [one[1] unsignedLongValue], got, one[2]);
                else if (failure)
                    answer_error(one[0], [one[1] unsignedLongValue], @"FETCH_FAILED", failure.domain, (long)failure.code, failure.localizedDescription);
                else
                    answer_error(one[0], [one[1] unsignedLongValue], @"FETCH_FAILED", @"rchelper", 0, @"the SDK answered with neither a client nor an error");
            }
        });
    };
    ((void (*)(Class, SEL, id, id))objc_msgSend)(recaptcha, sel_registerName("fetchClientWithSiteKey:completion:"), key, fetched);
}

static void expire(NSString *identifier, unsigned long serial)
{
    if ([pending[identifier] unsignedLongValue] != serial)
        return;
    for (NSString *key in fetching.allKeys) {
        NSMutableArray *waiting = fetching[key];
        for (NSArray *one in [waiting copy]) {
            if ([one[0] isEqual:identifier] && [one[1] unsignedLongValue] == serial)
                [waiting removeObject:one];
        }
        if (!waiting.count)
            [fetching removeObjectForKey:key];
    }
    answer_error(identifier, serial, @"TIMEOUT", @"rchelper", 0, @"the SDK did not answer in the time allowed");
}

static NSString *text(char *field, size_t length)
{
    size_t plain = rc_unescape(field, length);
    if (plain == (size_t)-1 || plain == 0 || memchr(field, 0, plain) || !rc_utf8_ok(field, plain))
        return nil;
    return [[NSString alloc] initWithBytes:field length:plain encoding:NSUTF8StringEncoding];
}

static BOOL is(char **fields, size_t *lengths, int index, const char *word)
{
    return lengths[index] == strlen(word) && memcmp(fields[index], word, lengths[index]) == 0;
}

static void reject(NSString *name, const char *bytes, size_t length)
{
    say(@[@"rejected", name, [NSData dataWithBytes:bytes length:length < 64 ? length : 64]], YES);
}

static void request(NSData *bytes)
{
    watch();
    NSMutableData *copy = [bytes mutableCopy];
    char *line = copy.mutableBytes;
    size_t length = copy.length;
    char *fields[RC_FIELDS_MOST];
    size_t lengths[RC_FIELDS_MOST];
    int count = rc_split(line, length, fields, lengths);
    if (count == 1 && is(fields, lengths, 0, "quit"))
        leave(0, @"quit");
    if (!is(fields, lengths, 0, "token")) {
        reject(@"UNKNOWN_LINE", bytes.bytes, length);
    } else if (count < 2 || !rc_id_ok(fields[1], lengths[1])) {
        reject(@"BAD_ID", bytes.bytes, length);
    } else {
        NSString *identifier = [[NSString alloc] initWithBytes:fields[1] length:lengths[1] encoding:NSASCIIStringEncoding];
        if (pending[identifier] && CONTROL != DUPLICATE_TAKEN) {
            reject(@"DUPLICATE_ID", fields[1], lengths[1]);
        } else {
            unsigned long serial = ++serials;
            pending[identifier] = @(serial);
            NSString *key = nil, *action = nil, *wrong = nil;
            long allowed = -1;
            if (count != 5) {
                wrong = @"a token request has five fields";
            } else {
                key = text(fields[2], lengths[2]);
                action = text(fields[3], lengths[3]);
                allowed = rc_number(fields[4], lengths[4], RC_ALLOWED_MOST);
                if (!key)
                    wrong = @"the site key is empty, has a wrong escape or is not UTF-8";
                else if (!action)
                    wrong = @"the action is empty, has a wrong escape or is not UTF-8";
                else if (allowed < 0)
                    wrong = @"the time allowed is not a number of milliseconds from 1 to 120000";
            }
            if (wrong) {
                answer_error(identifier, serial, @"BAD_REQUEST", @"rchelper", 0, wrong);
            } else {
                if (CONTROL != NO_DEADLINE) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, allowed * (int64_t)NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                        expire(identifier, serial);
                    });
                }
                want(identifier, serial, key, action);
            }
        }
    }
    if (pending.count)
        idle_turn++;
    else
        idle_arm();
}

static void *reader_main(void *unused)
{
    static struct rc_reader reader;
    reader.fd = 0;
    for (;;) {
        @autoreleasepool {
            char *line = NULL;
            size_t length = 0;
            int got = rc_read_line(&reader, -1, &line, &length);
            if (got == RC_LINE) {
                NSData *bytes = [NSData dataWithBytes:line length:length];
                dispatch_async(dispatch_get_main_queue(), ^{
                    request(bytes);
                });
            } else if (got == RC_LONG) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    say(@[@"rejected", @"LINE_TOO_LONG", [NSString stringWithFormat:@"%lu bytes, and a line has %d at most", (unsigned long)length, RC_LINE_MOST]], YES);
                });
            } else {
                if (CONTROL == END_IGNORED)
                    return NULL;
                leave(0, got == RC_END ? @"the app closed the request pipe" : @"the request pipe cannot be read");
            }
        }
    }
}

static NSString *uuid_of(const char *path)
{
    static uint8_t head[32768];
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return @"none";
    ssize_t got = read(fd, head, sizeof head);
    close(fd);
    if (got < (ssize_t)sizeof(struct mach_header_64))
        return @"none";
    const struct mach_header *header = (const void *)head;
    size_t at = header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : header->magic == MH_MAGIC ? sizeof(struct mach_header) : 0;
    if (!at)
        return @"none";
    for (uint32_t i = 0; i < header->ncmds && at + sizeof(struct uuid_command) <= (size_t)got; i++) {
        const struct uuid_command *command = (const void *)(head + at);
        if (command->cmd == LC_UUID) {
            NSMutableString *hex = [NSMutableString string];
            for (int byte = 0; byte < 16; byte++)
                [hex appendFormat:@"%02x", command->uuid[byte]];
            return hex;
        }
        if (command->cmdsize < sizeof(struct load_command))
            break;
        at += command->cmdsize;
    }
    return @"none";
}

static NSString *load(const char *path)
{
#ifdef RCHELPER_NATIVE
    if (!dlopen(path, RTLD_NOW))
        return [NSString stringWithFormat:@"dlopen: %s", dlerror()];
    recaptcha = objc_getClass("RecaptchaEnterprise.Recaptcha");
    actions = objc_getClass("RecaptchaEnterprise.RecaptchaAction");
#else
    xl_load_status status = xl_load(path);
    if (status != XL_LOAD_OK)
        return [NSString stringWithFormat:@"xl_load status %d: %s", (int)status, xl_load_error()];
    recaptcha = (__bridge Class)xl_find_class("RecaptchaEnterprise.Recaptcha");
    actions = (__bridge Class)xl_find_class("RecaptchaEnterprise.RecaptchaAction");
#endif
    return nil;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        if (fcntl(2, F_GETFD) < 0) {
            int null = open("/dev/null", O_WRONLY);
            if (null >= 0 && null != 2) {
                dup2(null, 2);
                close(null);
            }
        }
        if (CONTROL != STDOUT_KEPT) {
            answers = fcntl(1, F_DUPFD, 10);
            if (answers < 0) {
                note(@"descriptor 1 is not open: the helper has nowhere to answer");
                return 4;
            }
            fcntl(answers, F_SETFD, FD_CLOEXEC);
            dup2(2, 1);
        }
        if (CONTROL != PIPE_SIGNAL)
            fcntl(answers, F_SETNOSIGPIPE, 1);
        pending = [NSMutableDictionary dictionary];
        clients = [NSMutableDictionary dictionary];
        fetching = [NSMutableDictionary dictionary];
        BOOL usage = argc < 3;
        NSString *named = nil;
        for (int index = 3; index < argc && !usage; index++) {
            if (strcmp(argv[index], "--state") == 0 && index + 1 < argc) {
                named = @(argv[++index]);
                usage = named.length == 0;
            } else if (strcmp(argv[index], "--idle-ms") == 0 && index + 1 < argc) {
                index++;
                idle_ms = rc_number(argv[index], strlen(argv[index]), 3600000);
                usage = idle_ms < 0;
            } else {
                usage = YES;
            }
        }
        if (usage)
            fail(@"USAGE", @"rchelper LIBRARY VERSION [--state NAME] [--idle-ms N]");
        watch();
        if (strcmp(argv[2], RC_VERSION) != 0)
            fail(@"VERSION", [NSString stringWithFormat:@"this helper speaks version %s of the protocol and was asked for %s", RC_VERSION, argv[2]]);
        NSString *bundle = [NSBundle mainBundle].bundleIdentifier;
        state = named ?: (bundle.length ? [bundle stringByAppendingString:@".recaptcha"] : nil);
        if (!state)
            fail(@"NO_IDENTITY", @"the program has no bundle identifier and no --state, so it has no name for its preferences and its cache");
        move_home();
        redirect();
        double began = now();
        NSString *refused = load(argv[1]);
        if (refused)
            fail(@"LOAD_FAILED", refused);
        long took = (long)((now() - began) * 1000);
        if (![NSUserDefaults instancesRespondToSelector:@selector(initWithSuiteName:)])
            fail(@"NO_DEFAULTS", @"NSUserDefaults has no initWithSuiteName:, so the helper cannot keep the SDK out of the app's preferences");
        own_defaults();
        if (!cookies_possible())
            fail(@"NO_COOKIE_STORE", @"there is no NSURLSessionConfiguration, so the helper cannot keep the SDK out of the cookie store its process was given");
        own_cookies();
        if (!recaptcha || !actions || !class_respondsToSelector(object_getClass(recaptcha), sel_registerName("fetchClientWithSiteKey:completion:")) ||
            !class_respondsToSelector(object_getClass(actions), sel_registerName("custom:")))
            fail(@"NO_CLASSES", @"the library has no RecaptchaEnterprise.Recaptcha with fetchClientWithSiteKey:completion: or no RecaptchaEnterprise.RecaptchaAction with custom:");
        say(@[@"ready", @RC_VERSION, uuid_of(argv[1]), [NSString stringWithFormat:@"%ld", took]], NO);
        look(@"ready");
        idle_arm();
        pthread_t reader;
        pthread_create(&reader, NULL, reader_main, NULL);
        pthread_detach(reader);
        CFRunLoopTimerRef keep = CFRunLoopTimerCreateWithHandler(NULL, CFAbsoluteTimeGetCurrent() + 3600, 3600, 0, 0, ^(CFRunLoopTimerRef timer) {
        });
        CFRunLoopAddTimer(CFRunLoopGetMain(), keep, kCFRunLoopCommonModes);
        CFRunLoopRun();
    }
    return 0;
}
