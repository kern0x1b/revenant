#import "RevenantWebEngine.h"
#import <dlfcn.h>

NSString *const RevenantWebEngineErrorDomain = @"org.revenant.WebEngine";
NSString *const RevenantWebActionNavigationTypeKey = @"WebActionNavigationTypeKey";

static NSString *const RevenantWebEngineDefaultRoot = @"/usr/lib/revenant/webkit-engine";
static NSString *const RevenantWebEngineRootVariable = @"REVENANT_WEBKIT_ENGINE";
static const char *const RevenantWebEngineFrameworkNames[] = {"JavaScriptCore", "WebCore", "WebKitLegacy"};
static const NSUInteger RevenantWebEngineFrameworkCount = sizeof RevenantWebEngineFrameworkNames / sizeof RevenantWebEngineFrameworkNames[0];
static void *RevenantWebEngineHandles[sizeof RevenantWebEngineFrameworkNames / sizeof RevenantWebEngineFrameworkNames[0]];
static NSError *RevenantWebEngineFailure;
static dispatch_once_t RevenantWebEngineOnce;

NSString *RevenantWebEngineRoot(void)
{
    NSString *override = [NSProcessInfo processInfo].environment[RevenantWebEngineRootVariable];
    return override.length ? override : RevenantWebEngineDefaultRoot;
}

BOOL RevenantWebEngineLoad(NSError **error)
{
    dispatch_once(&RevenantWebEngineOnce, ^{
        NSString *root = RevenantWebEngineRoot();
        for (NSUInteger i = 0; i < RevenantWebEngineFrameworkCount; i++) {
            NSString *name = [NSString stringWithUTF8String:RevenantWebEngineFrameworkNames[i]];
            NSString *path = [NSString stringWithFormat:@"%@/%@.framework/%@", root, name, name];
            void *handle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
            if (!handle) {
                const char *reason = dlerror();
                NSString *text = [NSString stringWithFormat:@"%@ did not load from %@: %@", name, path, reason ? @(reason) : @"no reason given"];
                RevenantWebEngineFailure = [NSError errorWithDomain:RevenantWebEngineErrorDomain code:1
                                                           userInfo:@{NSLocalizedDescriptionKey: text}];
                return;
            }
            RevenantWebEngineHandles[i] = handle;
        }
    });
    if (error)
        *error = RevenantWebEngineFailure;
    return RevenantWebEngineFailure == nil;
}

void *RevenantWebEngineSymbol(const char *name)
{
    if (!RevenantWebEngineLoad(NULL))
        return NULL;
    for (NSUInteger i = 0; i < RevenantWebEngineFrameworkCount; i++) {
        void *symbol = dlsym(RevenantWebEngineHandles[i], name);
        if (symbol)
            return symbol;
    }
    return NULL;
}

Class RevenantWebEngineClass(NSString *name)
{
    if (!RevenantWebEngineLoad(NULL))
        return Nil;
    return NSClassFromString(name);
}
