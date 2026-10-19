#include <stdlib.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <limits.h>
#include <string.h>
#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>

extern char ***_NSGetArgv(void);

static int rev_enabled_for_current_app(void)
{
    CFBundleRef mb = CFBundleGetMainBundle();
    CFStringRef bid = mb ? CFBundleGetIdentifier(mb) : NULL;
    if (!bid)
        return 0;
    int enabled = (CFStringCompare(bid, CFSTR("com.apple.mobilesafari"), 0) == kCFCompareEqualTo) ? 1 : 0;
    CFStringRef domain = CFSTR("space.kern0x1b.rev");
    CFPreferencesAppSynchronize(domain);
    CFPropertyListRef apps = CFPreferencesCopyAppValue(CFSTR("InjectedApps"), domain);
    if (apps) {
        if (CFGetTypeID(apps) == CFDictionaryGetTypeID()) {
            CFTypeRef v = CFDictionaryGetValue((CFDictionaryRef)apps, bid);
            if (v && CFGetTypeID(v) == CFBooleanGetTypeID())
                enabled = CFBooleanGetValue((CFBooleanRef)v) ? 1 : 0;
        }
        CFRelease(apps);
    }
    return enabled;
}

__attribute__((constructor))
static void rev_safari_init(void)
{
    const char *pn = getprogname();
    if (pn && strcmp(pn, "SpringBoard") == 0)
        return;

    int active = getenv("REV_SAFARI_ACTIVE") != NULL;
    if (!active && !rev_enabled_for_current_app())
        return;

    freopen("/tmp/rev-safari-stderr.log", "a", stderr);
    setvbuf(stderr, 0, _IOLBF, 0);
    fprintf(stderr, "[tweak] ctor pass, active=%s\n", active ? "yes" : "no");
    if (active)
        return;

    setenv("REV_SAFARI_ACTIVE", "1", 1);
    setenv("DYLD_FORCE_FLAT_NAMESPACE", "1", 1);
    setenv("DYLD_INSERT_LIBRARIES",
        "/usr/lib/rev-fw/JavaScriptCore.framework/JavaScriptCore:/usr/lib/rev-fw/WebCore.framework/WebCore:/usr/lib/rev-fw/WebKit.framework/WebKit:/usr/lib/rev-safari-compat.dylib:/usr/lib/rev-TLS.dylib", 1);
    setenv("DYLD_FRAMEWORK_PATH", "/usr/lib/rev-fw", 1);
    setenv("JSC_forceRAMSize", "25165824", 1);
    setenv("JSC_numberOfGCMarkers", "1", 1);

    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0)
        return;
    FILE *f = fopen("/tmp/rev-safari-tweak.log", "a");
    if (f) { fprintf(f, "re-exec %s\n", path); fclose(f); }
    execv(path, *_NSGetArgv());
}
