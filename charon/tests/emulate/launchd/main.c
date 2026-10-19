// The order of a run: is the firmware loaded when the program begins? A program `xmake emulate run`
// starts is the guest's first process of its own, and on a device a process launched after boot finds
// launchd's jobs loaded: every Mach service a LaunchDaemons plist declares is registered with launchd,
// whether or not the daemon behind it runs yet. This program asks for com.apple.cvmsServ before anything
// else, then for every service those plists declare, and polls the missing ones. It passes when nothing
// it asks for first is registered later.
//
// A service a plist marks HideUntilCheckIn is registered only when its daemon checks in, which is the
// daemon's own time and not launchd's loading; those are counted apart and never fail the run.
#include <CoreFoundation/CoreFoundation.h>
#include <dirent.h>
#include <mach/mach.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <unistd.h>

// bootstrap_look_up is not in the SDK's public headers.
extern kern_return_t bootstrap_look_up(mach_port_t bootstrap, const char* name, mach_port_t* service);

#define MAX_SERVICES 2048
#define POLL_SECONDS 60

static char names[MAX_SERVICES][128];
static double seen[MAX_SERVICES];
static int hidden[MAX_SERVICES];
static int count;

static double now(void)
{
    struct timeval value;
    gettimeofday(&value, NULL);
    return value.tv_sec + value.tv_usec / 1e6;
}

static int registered(const char* name)
{
    mach_port_t port = MACH_PORT_NULL;
    return bootstrap_look_up(bootstrap_port, name, &port) == KERN_SUCCESS;
}

// Apple's plists do not agree on the key's case: com.apple.mediastream.mstreamd.plist spells it
// HideUntilCheckin for one service, and that service is registered when mstreamd checks in, like the rest.
static void flag(const void* key, const void* value, void* context)
{
    char name[32];
    if (CFGetTypeID(key) == CFStringGetTypeID() && CFStringGetCString(key, name, sizeof name, kCFStringEncodingUTF8) &&
        strcasecmp(name, "HideUntilCheckIn") == 0 && CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue(value))
        *(int*)context = 1;
}

static void add(const void* key, const void* value, void* context)
{
    char name[128];
    if (CFGetTypeID(key) != CFStringGetTypeID() || !CFStringGetCString(key, name, sizeof name, kCFStringEncodingUTF8))
        return;
    for (int i = 0; i < count; i++)
        if (strcmp(names[i], name) == 0)
            return;
    if (count == MAX_SERVICES)
        return;
    int until_check_in = 0;
    if (CFGetTypeID(value) == CFDictionaryGetTypeID())
        CFDictionaryApplyFunction(value, flag, &until_check_in);
    snprintf(names[count], sizeof names[0], "%s", name);
    hidden[count] = until_check_in;
    seen[count++] = -1;
}

static void declare(const char* file)
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8*)file, strlen(file), false);
    CFReadStreamRef stream = CFReadStreamCreateWithFile(NULL, url);
    if (stream && CFReadStreamOpen(stream)) {
        CFPropertyListRef list = CFPropertyListCreateFromStream(NULL, stream, 0, kCFPropertyListImmutable, NULL, NULL);
        if (list && CFGetTypeID(list) == CFDictionaryGetTypeID()) {
            CFDictionaryRef services = CFDictionaryGetValue(list, CFSTR("MachServices"));
            if (services && CFGetTypeID(services) == CFDictionaryGetTypeID())
                CFDictionaryApplyFunction(services, add, NULL);
        }
        if (list)
            CFRelease(list);
        CFReadStreamClose(stream);
    }
    if (stream)
        CFRelease(stream);
    CFRelease(url);
}

int main(void)
{
    double start = now();
    int first = registered("com.apple.cvmsServ");
    struct timeval boot;
    size_t size = sizeof boot;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    sysctl(mib, 2, &boot, &size, NULL, 0);
    printf("probe: first instruction, %.1f s after boot: com.apple.cvmsServ %s\n", start - boot.tv_sec, first ? "registered" : "NOT registered");
    fflush(stdout);

    const char* folder = "/System/Library/LaunchDaemons";
    DIR* directory = opendir(folder);
    if (!directory) {
        printf("probe: cannot read %s\n", folder);
        return 2;
    }
    struct dirent* entry;
    while ((entry = readdir(directory))) {
        size_t length = strlen(entry->d_name);
        if (length > 6 && strcmp(entry->d_name + length - 6, ".plist") == 0) {
            char file[512];
            snprintf(file, sizeof file, "%s/%s", folder, entry->d_name);
            declare(file);
        }
    }
    closedir(directory);

    int missing = 0, checked_in = 0;
    for (int i = 0; i < count; i++) {
        if (hidden[i])
            checked_in++;
        else if (registered(names[i]))
            seen[i] = 0;
        else
            missing++;
    }
    int at_first_scan = missing;
    printf("probe: %d Mach services declared, %d of them hidden until their daemon checks in, %d of the rest not registered %.1f s after the first instruction\n",
           count, checked_in, at_first_scan, now() - start);
    fflush(stdout);
    while (missing > 0 && now() - start < POLL_SECONDS) {
        usleep(50000);
        for (int i = 0; i < count; i++) {
            if (!hidden[i] && seen[i] < 0 && registered(names[i])) {
                seen[i] = now() - start;
                missing--;
            }
        }
    }
    int late = 0;
    for (int i = 0; i < count; i++) {
        if (hidden[i])
            continue;
        if (seen[i] > 0) {
            printf("probe: registered late, %.2f s after the first instruction: %s\n", seen[i], names[i]);
            late++;
        } else if (seen[i] < 0) {
            printf("probe: never registered in %d s: %s\n", POLL_SECONDS, names[i]);
        }
    }
    printf("probe: cvmsServ at first instruction %s, %d of the %d services registered late, %d never\n",
           first ? "yes" : "NO", late, count - checked_in, missing);
    int ok = first && late == 0;
    printf("probe: %s\n", ok ? "OK" : "FAIL");
    fflush(stdout);
    return ok ? 0 : 1;
}
