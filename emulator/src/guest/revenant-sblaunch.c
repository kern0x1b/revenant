#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

typedef int (*launch_function)(CFStringRef, Boolean);
typedef int (*debug_launch_function)(CFStringRef, CFURLRef, CFArrayRef, CFDictionaryRef, CFStringRef, CFStringRef, unsigned int);

static double now(void)
{
    struct timeval value;
    gettimeofday(&value, NULL);
    return value.tv_sec + value.tv_usec / 1e6;
}

static void usage(void)
{
    fprintf(stderr, "usage: revenant-sblaunch [--wait SECONDS] [--stdout PATH] [--stderr PATH] [--dyld-statistics] <bundle identifier>\n"
                    "       revenant-sblaunch --probe\n"
                    "  --dyld-statistics: ask dyld to print launch statistics\n"
                    "  --wait: retry until SpringBoard takes the launch and the application is frontmost\n"
                    "  --probe: print the uid, the SpringBoard ports and the launch error table; launches nothing\n");
}

static double started;

static void say(const char* state)
{
    static char last[256];
    if (strcmp(last, state) == 0)
        return;
    snprintf(last, sizeof last, "%s", state);
    printf("revenant-sblaunch: %.1f s: %s\n", now() - started, state);
    fflush(stdout);
}

static const char* screen(bool locked, bool passcode)
{
    return locked ? (passcode ? ", screen=passcode" : ", screen=locked") : "";
}

static CFStringRef string(const char* text)
{
    return text ? CFStringCreateWithCString(NULL, text, kCFStringEncodingUTF8) : NULL;
}

static void c_string(CFStringRef text, char* buffer, size_t size)
{
    snprintf(buffer, size, "nothing");
    if (text)
        CFStringGetCString(text, buffer, size, kCFStringEncodingUTF8);
}

extern mach_port_t bootstrap_port;
kern_return_t bootstrap_look_up(mach_port_t bootstrap, const char* name, mach_port_t* port);

static int probe(void)
{
    void* services = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    if (!services) {
        fprintf(stderr, "revenant-sblaunch: SpringBoardServices does not load\n");
        return 3;
    }
    mach_port_t (*server)(void) = (mach_port_t (*)(void))dlsym(services, "SBSSpringBoardServerPort");
    CFStringRef (*error_string)(int) = (CFStringRef (*)(int))dlsym(services, "SBSApplicationLaunchingErrorString");
    printf("uid=%d euid=%d pid=%d bootstrap_port=%u\n", getuid(), geteuid(), getpid(), bootstrap_port);
    printf("SBSSpringBoardServerPort=%u\n", server ? server() : MACH_PORT_NULL);
    const char* names[] = {"com.apple.springboard.services", "com.apple.SpringBoard", "com.apple.backboard.services", "com.apple.springboard.debugapplications"};
    for (unsigned index = 0; index < sizeof names / sizeof names[0]; ++index) {
        mach_port_t port = MACH_PORT_NULL;
        kern_return_t status = bootstrap_look_up(bootstrap_port, names[index], &port);
        printf("bootstrap_look_up %s: kern_return=%d port=%u\n", names[index], status, port);
    }
    for (int code = 0; code <= 8; ++code) {
        char text[96];
        c_string(error_string ? error_string(code) : NULL, text, sizeof text);
        printf("error %d: %s\n", code, text);
    }
    return 0;
}

int main(int argc, char** argv)
{
    if (argc == 2 && strcmp(argv[1], "--probe") == 0)
        return probe();
    double wait = 0;
    const char *out = NULL, *err = NULL, *bundle = NULL;
    bool dyld_statistics = false;
    for (int index = 1; index < argc; ++index) {
        if (strcmp(argv[index], "--wait") == 0 && index + 1 < argc)
            wait = atof(argv[++index]);
        else if (strcmp(argv[index], "--stdout") == 0 && index + 1 < argc)
            out = argv[++index];
        else if (strcmp(argv[index], "--stderr") == 0 && index + 1 < argc)
            err = argv[++index];
        else if (strcmp(argv[index], "--dyld-statistics") == 0)
            dyld_statistics = true;
        else if (!bundle && argv[index][0] != '-')
            bundle = argv[index];
        else {
            usage();
            return 2;
        }
    }
    if (!bundle) {
        usage();
        return 2;
    }
    void* services = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    launch_function launch = services ? (launch_function)dlsym(services, "SBSLaunchApplicationWithIdentifier") : NULL;
    debug_launch_function debug_launch = services ? (debug_launch_function)dlsym(services, "SBSLaunchApplicationForDebugging") : NULL;
    if (!launch || ((out || err || dyld_statistics) && !debug_launch)) {
        fprintf(stderr, "revenant-sblaunch: SpringBoardServices has no %s\n",
                launch ? "SBSLaunchApplicationForDebugging, which launch diagnostics need" : "SBSLaunchApplicationWithIdentifier");
        return 3;
    }
    mach_port_t (*server)(void) = (mach_port_t (*)(void))dlsym(services, "SBSSpringBoardServerPort");
    void (*lock_status)(mach_port_t, bool*, bool*) = (void (*)(mach_port_t, bool*, bool*))dlsym(services, "SBGetScreenLockStatus");
    CFStringRef (*error_string)(int) = (CFStringRef (*)(int))dlsym(services, "SBSApplicationLaunchingErrorString");
    CFStringRef (*frontmost)(void) = (CFStringRef (*)(void))dlsym(services, "SBSCopyFrontmostApplicationDisplayIdentifier");
    if (wait > 0 && !frontmost) {
        fprintf(stderr, "revenant-sblaunch: SpringBoardServices has no SBSCopyFrontmostApplicationDisplayIdentifier, which --wait needs\n");
        return 3;
    }

    CFStringRef identifier = string(bundle);
    CFStringRef out_path = string(out), err_path = string(err);
    const void* keys[] = {CFSTR("CFLOG_FORCE_STDERR"), CFSTR("NSUnbufferedIO"), CFSTR("DYLD_PRINT_STATISTICS")};
    const void* values[] = {CFSTR("1"), CFSTR("YES"), CFSTR("1")};
    CFIndex environment_count = dyld_statistics ? 3 : 2;
    CFDictionaryRef environment = CFDictionaryCreate(NULL, keys, values, environment_count,
                                                      &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    started = now();
    int result = -1;
    bool locked = false, passcode = false;
    for (;;) {
        mach_port_t port = server ? server() : MACH_PORT_NULL;
        locked = passcode = false;
        if (port != MACH_PORT_NULL && lock_status)
            lock_status(port, &locked, &passcode);
        if (server && port == MACH_PORT_NULL)
            say("waiting for SpringBoard");
        else {
            result = debug_launch && (out || err || dyld_statistics)
                ? debug_launch(identifier, NULL, NULL, environment, out_path, err_path, 0)
                : launch(identifier, false);
            if (result == 0)
                break;
            char reason[96], refused[192];
            c_string(error_string ? error_string(result) : NULL, reason, sizeof reason);
            snprintf(refused, sizeof refused, "SpringBoard refused with %d (%s)%s", result, reason,
                     screen(locked, passcode));
            say(refused);
        }
        if (now() - started >= wait)
            break;
        usleep(500000);
    }
    CFRelease(environment);
    CFRelease(identifier);
    if (out_path)
        CFRelease(out_path);
    if (err_path)
        CFRelease(err_path);
    if (result != 0) {
        char reason[96];
        c_string(error_string ? error_string(result) : NULL, reason, sizeof reason);
        fprintf(stderr, "revenant-sblaunch: SpringBoard refused %s with %d (%s)%s\n", bundle, result, reason,
                screen(locked, passcode));
        return 1;
    }
    say("launched");
    if (wait <= 0)
        return 0;
    char front[256] = "nothing";
    for (;;) {
        CFStringRef current = frontmost();
        c_string(current, front, sizeof front);
        if (current)
            CFRelease(current);
        if (strcmp(front, bundle) == 0) {
            say("frontmost");
            return 0;
        }
        if (now() - started >= wait)
            break;
        usleep(500000);
    }
    fprintf(stderr, "revenant-sblaunch: SpringBoard took the launch of %s, and after %.0f seconds %s is frontmost\n",
            bundle, wait, front);
    return 4;
}
