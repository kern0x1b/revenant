#import <Foundation/Foundation.h>

@interface WebGeolocationManager : NSObject @end
@implementation WebGeolocationManager
+ (id)sharedWebGeolocationManager { static WebGeolocationManager *s; if (!s) s = [self new]; return s; }
- (void)setDelegate:(id)d {}
- (void)forwardInvocation:(NSInvocation *)inv {}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)s { return [NSMethodSignature signatureWithObjCTypes:"v@:@"]; }
@end

@interface NSData (RevIOS6Compat) @end
@implementation NSData (RevIOS6Compat)
- (id)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length deallocator:(void (^)(void *, NSUInteger))deallocator
{
    self = [self initWithBytes:bytes length:length];
    if (deallocator) deallocator(bytes, length);
    return self;
}
@end

@interface NSCalendar (RevIOS6Compat) @end
@implementation NSCalendar (RevIOS6Compat)
+ (id)calendarWithIdentifier:(NSString *)identifier
{
    return [[[NSCalendar alloc] initWithCalendarIdentifier:identifier] autorelease];
}
@end

#include <stddef.h>
#include <stdint.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
namespace WebKit {
    class MemoryMeasure {
    public:
        ~MemoryMeasure();
        static void enableLogging(bool);
        static bool isLoggingEnabled();
        static size_t taskMemory();
    };
    MemoryMeasure::~MemoryMeasure() {}
    void MemoryMeasure::enableLogging(bool) {}
    bool MemoryMeasure::isLoggingEnabled() { return false; }
    size_t MemoryMeasure::taskMemory() {
        task_basic_info info;
        mach_msg_type_number_t count = TASK_BASIC_INFO_COUNT;
        if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS)
            return info.resident_size;
        return 0;
    }
}
namespace WebCore {
    uint64_t systemTotalMemory();
    uint64_t systemTotalMemory() {
        uint64_t bytes = 0;
        size_t len = sizeof(bytes);
        if (sysctlbyname("hw.memsize", &bytes, &len, 0, 0) == 0 && bytes)
            return bytes;
        return (uint64_t)512 * 1024 * 1024;
    }
    void* currentCFHTTPCookieStorage();
    void* currentCFHTTPCookieStorage() { return 0; }
}

#include <pthread.h>
#include <dispatch/dispatch.h>
namespace WTF {
    typedef uint32_t ThreadIdentifier;
    typedef void (*ThreadFunction)(void* argument);

    class Mutex { public: Mutex(); pthread_mutex_t m_mutex; };
    Mutex::Mutex() { pthread_mutex_init(&m_mutex, 0); }

    class ThreadCondition { public: ThreadCondition(); pthread_cond_t m_condition; };
    ThreadCondition::ThreadCondition() { pthread_cond_init(&m_condition, 0); }

    static pthread_mutex_t s_staticMutex = PTHREAD_MUTEX_INITIALIZER;
    void lockAtomicallyInitializedStaticMutex();
    void unlockAtomicallyInitializedStaticMutex();
    void lockAtomicallyInitializedStaticMutex() { pthread_mutex_lock(&s_staticMutex); }
    void unlockAtomicallyInitializedStaticMutex() { pthread_mutex_unlock(&s_staticMutex); }

    ThreadIdentifier currentThread();
    ThreadIdentifier currentThread() { return (ThreadIdentifier)pthread_mach_thread_np(pthread_self()); }

    struct ThreadTrampoline { ThreadFunction entry; void* data; };
    static void* threadStart(void* p) {
        ThreadTrampoline t = *(ThreadTrampoline*)p; free(p);
        t.entry(t.data);
        return 0;
    }
    ThreadIdentifier createThread(ThreadFunction, void*, const char*);
    ThreadIdentifier createThread(ThreadFunction entry, void* data, const char*) {
        ThreadTrampoline* t = (ThreadTrampoline*)malloc(sizeof(ThreadTrampoline));
        t->entry = entry; t->data = data;
        pthread_t thread;
        if (pthread_create(&thread, 0, threadStart, t) != 0) { free(t); return 0; }
        return (ThreadIdentifier)pthread_mach_thread_np(thread);
    }

    void callOnMainThread(ThreadFunction, void*);
    void callOnMainThread(ThreadFunction fn, void* data) {
        dispatch_async(dispatch_get_main_queue(), ^{ fn(data); });
    }
}

#include <execinfo.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <sys/ucontext.h>
static void rev_crash_handler(int sig, siginfo_t* info, void* context) {
    fprintf(stderr, "[REVCRASH] signal %d\n", sig);
    if (context) {
        _STRUCT_MCONTEXT* mc = ((ucontext_t*)context)->uc_mcontext;
        if (mc) {
            fprintf(stderr, "[REVCRASH] pc 0x%lx lr 0x%lx sp 0x%lx fault 0x%lx\n",
                (unsigned long)mc->__ss.__pc, (unsigned long)mc->__ss.__lr,
                (unsigned long)mc->__ss.__sp, (unsigned long)(info ? info->si_addr : 0));
            for (int r = 0; r < 13; r += 4)
                fprintf(stderr, "[REVCRASH] r%-2d 0x%08lx  r%-2d 0x%08lx  r%-2d 0x%08lx  r%-2d 0x%08lx\n",
                    r, (unsigned long)mc->__ss.__r[r], r + 1, (unsigned long)mc->__ss.__r[r + 1],
                    r + 2, (unsigned long)mc->__ss.__r[r + 2], r + 3, (unsigned long)mc->__ss.__r[r + 3]);
        }
    }
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name)
            continue;
        if (!strstr(name, "WebCore") && !strstr(name, "JavaScriptCore")
            && !strstr(name, "WebKit") && !strstr(name, "rev-"))
            continue;
        fprintf(stderr, "[REVCRASH] image %s slide 0x%lx\n", name,
            (unsigned long)_dyld_get_image_vmaddr_slide(i));
    }
    void* bt[64];
    int n = backtrace(bt, 64);
    backtrace_symbols_fd(bt, n, fileno(stderr));
    fflush(stderr);
    signal(sig, SIG_DFL);
    raise(sig);
}
__attribute__((constructor))
static void rev_crash_init() {
    static char alternateStack[SIGSTKSZ * 4];
    stack_t signalStack;
    memset(&signalStack, 0, sizeof(signalStack));
    signalStack.ss_sp = alternateStack;
    signalStack.ss_size = sizeof(alternateStack);
    sigaltstack(&signalStack, NULL);

    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_sigaction = rev_crash_handler;
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&action.sa_mask);
    static const int signals[] = { SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGTRAP };
    for (unsigned i = 0; i < sizeof(signals) / sizeof(signals[0]); ++i)
        sigaction(signals[i], &action, NULL);
}

#import <objc/runtime.h>
#import <sqlite3.h>

@interface NSObject (RevStartPage)
- (id)browserView;
- (void)loadHTMLString:(NSString *)string baseURL:(id)url;
@end

static NSString *revHTMLEscape(const char *s) {
    if (!s) return @"";
    NSMutableString *m = [NSMutableString stringWithUTF8String:s];
    [m replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"'" withString:@"&#39;" options:0 range:NSMakeRange(0, m.length)];
    return m;
}

static NSString *revJSEscape(const char *s) {
    if (!s) return @"";
    NSMutableString *m = [NSMutableString stringWithUTF8String:s];
    [m replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"</" withString:@"<\\/" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, m.length)];
    return m;
}

static NSString *revBase64(NSData *data) {
    static const char t[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const uint8_t *b = (const uint8_t *)data.bytes;
    NSUInteger len = data.length;
    NSMutableString *out = [NSMutableString stringWithCapacity:((len + 2) / 3) * 4];
    for (NSUInteger i = 0; i < len; i += 3) {
        uint32_t n = (uint32_t)b[i] << 16;
        if (i + 1 < len) n |= (uint32_t)b[i + 1] << 8;
        if (i + 2 < len) n |= (uint32_t)b[i + 2];
        [out appendFormat:@"%c%c%c%c", t[(n >> 18) & 63], t[(n >> 12) & 63],
            (i + 1 < len) ? t[(n >> 6) & 63] : '=', (i + 2 < len) ? t[n & 63] : '='];
    }
    return out;
}

static NSString *revFaviconDir(void) { return @"/var/mobile/Library/Safari/RevFavicons"; }

static NSString *revFaviconSafeHost(NSString *host) {
    return [host stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
}

static NSString *revFaviconPath(NSString *host) {
    return [revFaviconDir() stringByAppendingFormat:@"/%@.icon", revFaviconSafeHost(host)];
}

static NSString *revFaviconLegacyPath(NSString *host) {
    return [revFaviconDir() stringByAppendingFormat:@"/%@.png", revFaviconSafeHost(host)];
}

static NSString *revFaviconMIMEType(NSData *data) {
    const unsigned char *b = (const unsigned char *)data.bytes;
    NSUInteger n = data.length;
    if (n > 8 && !memcmp(b, "\x89PNG\r\n\x1a\n", 8))
        return @"image/png";
    if (n > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff)
        return @"image/jpeg";
    if (n > 6 && (!memcmp(b, "GIF87a", 6) || !memcmp(b, "GIF89a", 6)))
        return @"image/gif";
    if (n > 4 && !memcmp(b, "\x00\x00\x01\x00", 4))
        return @"image/x-icon";
    if (n > 4 && !memcmp(b, "<svg", 4))
        return @"image/svg+xml";
    if (n > 5 && !memcmp(b, "<?xml", 5))
        return @"image/svg+xml";
    return nil;
}

static NSString *revFaviconSrc(NSString *host) {
    NSData *data = [NSData dataWithContentsOfFile:revFaviconPath(host)];
    NSString *type = data.length > 50 ? revFaviconMIMEType(data) : nil;
    if (!type) {
        data = [NSData dataWithContentsOfFile:revFaviconLegacyPath(host)];
        type = data.length > 50 ? @"image/png" : nil;
    }
    if (!type)
        return @"";
    return [NSString stringWithFormat:@"data:%@;base64,%@", type, revBase64(data)];
}

@interface RevFaviconStore : NSObject
@end

@implementation RevFaviconStore
+ (void)iconLoaded:(NSNotification *)note {
    NSData *data = [note.userInfo objectForKey:@"WebViewMainFrameIconData"];
    NSString *pageURL = [note.userInfo objectForKey:@"WebViewMainFrameIconPageURL"];
    if (![data isKindOfClass:[NSData class]] || data.length <= 50)
        return;
    if (![pageURL isKindOfClass:[NSString class]])
        return;
    NSString *host = [[NSURL URLWithString:pageURL] host];
    if (!host.length || !revFaviconMIMEType(data))
        return;

    NSData *copiedData = [data copy];
    NSString *path = [revFaviconPath(host) copy];
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("rev.favicons", 0); });
    dispatch_async(queue, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:revFaviconDir() withIntermediateDirectories:YES attributes:nil error:nil];
        [copiedData writeToFile:path atomically:YES];
    });
}
@end

__attribute__((constructor))
static void rev_favicon_store_init(void) {
    [[NSNotificationCenter defaultCenter] addObserver:[RevFaviconStore class]
        selector:@selector(iconLoaded:)
        name:@"WebViewDidLoadMainFrameIconNotification"
        object:nil];
}

static NSString *revHTMLEsc(NSString *s) {
    if (![s isKindOfClass:[NSString class]]) return @"";
    NSMutableString *m = [[s mutableCopy] autorelease];
    [m replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"'" withString:@"&#39;" options:0 range:NSMakeRange(0, m.length)];
    return m;
}

#define REV_FOLDER_SVG @"<svg viewBox='0 0 48 48'><path fill='#8aa0bf' d='M5 13c0-1.7 1.3-3 3-3h11l4 4h17c1.7 0 3 1.3 3 3v18c0 1.7-1.3 3-3 3H8c-1.7 0-3-1.3-3-3z'/><path fill='#a7bad6' d='M5 18h38v20c0 1.7-1.3 3-3 3H8c-1.7 0-3-1.3-3-3z'/></svg>"

static NSString *revStartPageHTMLForFolder(int folderId) {
    NSMutableString *grid = [NSMutableString string];
    NSString *title = @"Favorites";
    sqlite3 *db = NULL;
    if (sqlite3_open_v2("/var/mobile/Library/Safari/Bookmarks.db", &db, SQLITE_OPEN_READONLY, NULL) == SQLITE_OK) {
        if (folderId != 0) {
            sqlite3_stmt *ts = NULL;
            if (sqlite3_prepare_v2(db, "SELECT title FROM bookmarks WHERE id=?", -1, &ts, NULL) == SQLITE_OK) {
                sqlite3_bind_int(ts, 1, folderId);
                if (sqlite3_step(ts) == SQLITE_ROW) {
                    const char *t = (const char *)sqlite3_column_text(ts, 0);
                    if (t) title = [NSString stringWithUTF8String:t];
                }
                sqlite3_finalize(ts);
            }
        }
        sqlite3_stmt *st = NULL;
        const char *q = "SELECT id,type,title,url FROM bookmarks WHERE parent=? AND deleted=0 AND hidden=0 AND special_id=0 AND title NOT LIKE 'com.apple.%' ORDER BY order_index";
        if (sqlite3_prepare_v2(db, q, -1, &st, NULL) == SQLITE_OK) {
            sqlite3_bind_int(st, 1, folderId);
            while (sqlite3_step(st) == SQLITE_ROW) {
                int idv = sqlite3_column_int(st, 0);
                int type = sqlite3_column_int(st, 1);
                const char *titleC = (const char *)sqlite3_column_text(st, 2);
                const char *urlC = (const char *)sqlite3_column_text(st, 3);
                NSString *name = revHTMLEsc(titleC ? [NSString stringWithUTF8String:titleC] : @"");
                if (type == 1) {
                    [grid appendFormat:@"<a class='t' href='favorites:///folder/%d'><span class='i fo'>%@</span><span class='n'>%@</span></a>", idv, REV_FOLDER_SVG, name];
                } else {
                    NSString *rawUrl = urlC ? [NSString stringWithUTF8String:urlC] : @"";
                    NSString *host = [[NSURL URLWithString:rawUrl] host];
                    NSString *fav = host.length ? revFaviconSrc(host) : @"";
                    NSString *img = fav.length ? [NSString stringWithFormat:@"<img src='%@'>", revHTMLEsc(fav)] : @"";
                    [grid appendFormat:@"<a class='t' href='%@'><span class='i'>%@</span><span class='n'>%@</span></a>", revHTMLEsc(rawUrl), img, name];
                }
            }
            sqlite3_finalize(st);
        }
        sqlite3_close(db);
    }
    if (grid.length == 0)
        [grid appendString:@"<div class='empty'>Empty</div>"];
    return [NSString stringWithFormat:@"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>%@</title>"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,minimum-scale=1,user-scalable=no\">"
        "<style>"
        "*{margin:0;padding:0;box-sizing:border-box;-webkit-tap-highlight-color:transparent}"
        "body{font-family:'Helvetica Neue',Helvetica,sans-serif;background:#dfe3e8;color:#333;padding:10px 12px}"
        ".hdr{font-size:12px;font-weight:600;color:#8a8f96;text-transform:uppercase;letter-spacing:.4px;margin:2px 2px 10px}"
        ".grid{font-size:0}"
        ".t{display:inline-block;width:64px;vertical-align:top;margin:0 6px 12px 0;text-decoration:none;color:#444;text-align:center}"
        ".i{display:flex;align-items:center;justify-content:center;width:60px;height:60px;margin:0 auto 5px;"
        "border-radius:13px;overflow:hidden;background:linear-gradient(#fff,#e9edf2);border:1px solid #c3c9d2;"
        "box-shadow:0 1px 1px rgba(255,255,255,.7) inset,0 1px 2px rgba(0,0,0,.14);"
        "-webkit-transition:-webkit-transform .1s ease,opacity .1s ease}"
        ".t:active .i{-webkit-transform:scale(.88);opacity:.6}"
        ".t.load .i{opacity:.45}"
        ".t.load .n{opacity:.45}"
        ".i.fo{background:linear-gradient(#eef1f5,#dbe1ea)}"
        ".i img{width:44px;height:44px}"
        ".i svg{width:40px;height:40px}"
        ".n{display:block;width:64px;font-size:11px;line-height:14px;height:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}"
        ".empty{color:#9aa0a8;font-size:13px;margin:8px 2px}"
        "</style></head><body>"
        "<div class=\"hdr\">%@</div><div class=\"grid\">%@</div>"
        "</body></html>", revHTMLEsc(title), revHTMLEsc(title), grid];
}

@interface RevStartPageProtocol : NSURLProtocol { BOOL _stopped; } @end
@implementation RevStartPageProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [[[request URL] scheme] caseInsensitiveCompare:@"favorites"] == NSOrderedSame;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b { return NO; }
- (void)startLoading {
    [self performSelector:@selector(revDeliver) withObject:nil afterDelay:0.0];
}
- (void)revDeliver {
    if (_stopped)
        return;
    int folderId = 0;
    NSString *path = [[[self request] URL] path];
    NSRange fr = [path rangeOfString:@"/folder/"];
    if (fr.location != NSNotFound)
        folderId = [[path substringFromIndex:fr.location + fr.length] intValue];
    NSData *data = [revStartPageHTMLForFolder(folderId) dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys:
        @"text/html; charset=utf-8", @"Content-Type",
        [NSString stringWithFormat:@"%lu", (unsigned long)data.length], @"Content-Length", nil];
    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:[[self request] URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headers];
    id<NSURLProtocolClient> client = [self client];
    [client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [client URLProtocol:self didLoadData:data];
    [client URLProtocolDidFinishLoading:self];
    [resp release];
}
- (void)stopLoading {
    _stopped = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}
@end

@interface NSObject (RevTabDoc)
- (void)loadURL:(NSURL *)url userDriven:(BOOL)userDriven;
@end

static id revPref(NSString *key) {
    CFPreferencesAppSynchronize(CFSTR("space.kern0x1b.rev"));
    CFPropertyListRef v = CFPreferencesCopyAppValue((CFStringRef)key, CFSTR("space.kern0x1b.rev"));
    return [(id)v autorelease];
}
static BOOL revPrefBool(NSString *key, BOOL def) {
    id v = revPref(key);
    return [v respondsToSelector:@selector(boolValue)] ? [v boolValue] : def;
}
static NSString *revPrefString(NSString *key) {
    id v = revPref(key);
    return [v isKindOfClass:[NSString class]] ? v : nil;
}
static BOOL revInjectionEnabledForThisApp(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (!bid) return NO;
    id apps = revPref(@"InjectedApps");
    if ([apps isKindOfClass:[NSDictionary class]]) {
        id v = [apps objectForKey:bid];
        if (v) return [v boolValue];
    }
    return [bid isEqualToString:@"com.apple.mobilesafari"];
}

#import "RevWasm.h"
#include <dlfcn.h>
typedef void (*RevWindowObjectClearedCallback)(WebView *, WebFrame *);
static void rev_window_object_cleared(WebView *webView, WebFrame *frame) {
    @try { [RevWasm installInWebView:webView forFrame:frame]; } @catch (id e) {}
}
static void rev_install_wasm_hook(void) {
    void (*setCallback)(RevWindowObjectClearedCallback) =
        (void (*)(RevWindowObjectClearedCallback))dlsym(RTLD_DEFAULT, "WebSetWindowObjectClearedCallback");
    if (setCallback) {
        setCallback(rev_window_object_cleared);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        void (*late)(RevWindowObjectClearedCallback) =
            (void (*)(RevWindowObjectClearedCallback))dlsym(RTLD_DEFAULT, "WebSetWindowObjectClearedCallback");
        if (late)
            late(rev_window_object_cleared);
    });
}

static IMP g_openBlank_orig;
static id rev_openBlankTabDocument(id self, SEL _cmd) {
    id doc = ((id(*)(id, SEL))g_openBlank_orig)(self, _cmd);
    if (!doc)
        return doc;
    NSString *target = nil;
    if (revPrefBool(@"CustomURLEnabled", NO)) {
        NSString *u = revPrefString(@"CustomURL");
        u = [u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (u.length) {
            if ([u rangeOfString:@"://"].location == NSNotFound)
                u = [@"https://" stringByAppendingString:u];
            target = u;
        }
    }
    if (!target && revPrefBool(@"NewTabStartPage", YES))
        target = @"favorites:///";
    if (!target)
        return doc;
    id docRef = [doc retain];
    NSString *t = [target copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if ([docRef respondsToSelector:@selector(loadURL:userDriven:)])
                [docRef loadURL:[NSURL URLWithString:t] userDriven:NO];
        } @catch (id e) {}
        [docRef release];
        [t release];
    });
    return doc;
}

@interface NSObject (RevWebPreferences)
+ (id)standardPreferences;
- (void)_setBoolPreferenceForTestingWithValue:(BOOL)value forKey:(NSString *)key;
@end

static void rev_apply_console_logging(void) {
    BOOL wanted = revPrefBool(@"ConsoleLog", NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        Class preferences = NSClassFromString(@"WebPreferences");
        if (![preferences respondsToSelector:@selector(standardPreferences)])
            return;
        id standard = [preferences standardPreferences];
        if ([standard respondsToSelector:@selector(_setBoolPreferenceForTestingWithValue:forKey:)])
            [standard _setBoolPreferenceForTestingWithValue:wanted
                                                     forKey:@"LogsPageMessagesToSystemConsoleEnabled"];
    });
}

__attribute__((constructor))
static void rev_startpage_init(void) {
    if (!revInjectionEnabledForThisApp())
        return;
    [NSURLProtocol registerClass:[RevStartPageProtocol class]];
    rev_install_wasm_hook();
    rev_apply_console_logging();

    Class tc = NSClassFromString(@"TabController");
    if (!tc) return;
    Method m = class_getInstanceMethod(tc, @selector(_openBlankTabDocument));
    if (!m) return;
    g_openBlank_orig = method_getImplementation(m);
    method_setImplementation(m, (IMP)rev_openBlankTabDocument);
}

