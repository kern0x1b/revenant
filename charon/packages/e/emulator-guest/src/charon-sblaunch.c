#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

// iOS 6 has no public way to launch another application by its bundle
// identifier: SpringBoardServices is how SpringBoard's own clients do it
// (debugserver launches through SBSLaunchApplicationForDebugging), so its
// functions are looked up by name rather than linked from a private framework.
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
    fprintf(stderr, "usage: charon-sblaunch [--wait SECONDS] [--stdout PATH] [--stderr PATH] <bundle identifier>\n"
                    "  --wait: retry until SpringBoard takes the launch and the application is frontmost\n");
}

static double started;

// Each state is printed once, when it changes, with the seconds since the
// start, so whoever reads the output line by line - xmake emulate launch does,
// to unlock the screen - sees where the launch waits and for how long.
static void say(const char* state)
{
    static char last[256];
    if (strcmp(last, state) == 0)
        return;
    snprintf(last, sizeof last, "%s", state);
    printf("charon-sblaunch: %.1f s: %s\n", now() - started, state);
    fflush(stdout);
}

// How a refusal names the lock state, as a token of its own that xmake emulate launch reads, so that it depends on this
// word and not on the wording of the sentence around it: ", screen=locked" (unlock it), ", screen=passcode" (nothing
// can unlock it), nothing when SpringBoard did not say.
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

int main(int argc, char** argv)
{
    double wait = 0;
    const char *out = NULL, *err = NULL, *bundle = NULL;
    for (int index = 1; index < argc; ++index) {
        if (strcmp(argv[index], "--wait") == 0 && index + 1 < argc)
            wait = atof(argv[++index]);
        else if (strcmp(argv[index], "--stdout") == 0 && index + 1 < argc)
            out = argv[++index];
        else if (strcmp(argv[index], "--stderr") == 0 && index + 1 < argc)
            err = argv[++index];
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
    if (!launch || ((out || err) && !debug_launch)) {
        fprintf(stderr, "charon-sblaunch: SpringBoardServices has no %s\n",
                launch ? "SBSLaunchApplicationForDebugging, which the application's output needs" : "SBSLaunchApplicationWithIdentifier");
        return 3;
    }
    mach_port_t (*server)(void) = (mach_port_t (*)(void))dlsym(services, "SBSSpringBoardServerPort");
    void (*lock_status)(mach_port_t, bool*, bool*) = (void (*)(mach_port_t, bool*, bool*))dlsym(services, "SBGetScreenLockStatus");
    CFStringRef (*error_string)(int) = (CFStringRef (*)(int))dlsym(services, "SBSApplicationLaunchingErrorString");
    CFStringRef (*frontmost)(void) = (CFStringRef (*)(void))dlsym(services, "SBSCopyFrontmostApplicationDisplayIdentifier");
    if (wait > 0 && !frontmost) {
        fprintf(stderr, "charon-sblaunch: SpringBoardServices has no SBSCopyFrontmostApplicationDisplayIdentifier, which --wait needs\n");
        return 3;
    }

    CFStringRef identifier = string(bundle);
    CFStringRef out_path = string(out), err_path = string(err);
    // The application's output reaches its files as it is written: stdio is
    // unbuffered and CFLog (NSLog) writes to standard error as well as to ASL.
    const void* keys[] = {CFSTR("CFLOG_FORCE_STDERR"), CFSTR("NSUnbufferedIO")};
    const void* values[] = {CFSTR("1"), CFSTR("YES")};
    CFDictionaryRef environment = CFDictionaryCreate(NULL, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

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
            result = debug_launch && (out || err)
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
        fprintf(stderr, "charon-sblaunch: SpringBoard refused %s with %d (%s)%s\n", bundle, result, reason,
                screen(locked, passcode));
        return 1;
    }
    say("launched");
    if (wait <= 0)
        return 0;
    // A launch SpringBoard takes is done when SpringBoard makes the
    // application frontmost, which it does once the application is running.
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
    fprintf(stderr, "charon-sblaunch: SpringBoard took the launch of %s, and after %.0f seconds %s is frontmost\n",
            bundle, wait, front);
    return 4;
}
