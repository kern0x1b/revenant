#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <dirent.h>
#include <fcntl.h>
#include <mach/mach.h>
#include <objc/runtime.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <syslog.h>
#include <time.h>
#include <strings.h>
#include <unistd.h>

extern char** environ;

extern kern_return_t bootstrap_look_up(mach_port_t bootstrap, const char* name, mach_port_t* service);

static const char* verdict_directory = "/private/var/revenant";

static double now(void)
{
    struct timeval value;
    gettimeofday(&value, NULL);
    return value.tv_sec + value.tv_usec / 1e6;
}

static void json_string(FILE* file, const char* text)
{
    fputc('"', file);
    for (const char* c = text ? text : ""; *c; ++c) {
        if (*c == '"' || *c == '\\')
            fputc('\\', file);
        if ((unsigned char)*c < 0x20)
            fprintf(file, "\\u%04x", *c);
        else
            fputc(*c, file);
    }
    fputc('"', file);
}

static void system_version(char* version, size_t size)
{
    snprintf(version, size, "unknown");
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, CFSTR("/System/Library/CoreServices/SystemVersion.plist"), kCFURLPOSIXPathStyle, false);
    CFReadStreamRef stream = CFReadStreamCreateWithFile(NULL, url);
    if (stream && CFReadStreamOpen(stream)) {
        CFPropertyListRef list = CFPropertyListCreateFromStream(NULL, stream, 0, kCFPropertyListImmutable, NULL, NULL);
        if (list && CFGetTypeID(list) == CFDictionaryGetTypeID()) {
            CFStringRef product = CFDictionaryGetValue(list, CFSTR("ProductVersion"));
            CFStringRef build = CFDictionaryGetValue(list, CFSTR("ProductBuildVersion"));
            char p[32] = "?", b[32] = "?";
            if (product)
                CFStringGetCString(product, p, sizeof p, kCFStringEncodingUTF8);
            if (build)
                CFStringGetCString(build, b, sizeof b, kCFStringEncodingUTF8);
            snprintf(version, size, "%s (%s)", p, b);
        }
        if (list)
            CFRelease(list);
        CFReadStreamClose(stream);
    }
    if (stream)
        CFRelease(stream);
    CFRelease(url);
}

static void keep_own_output(void)
{
    int out = open("/private/var/revenant/runner.stdout", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    int err = open("/private/var/revenant/runner.stderr", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out >= 0) {
        dup2(out, STDOUT_FILENO);
        close(out);
    }
    if (err >= 0) {
        dup2(err, STDERR_FILENO);
        close(err);
    }
}

static char** read_job(const char* file, char* self, int* count)
{
    static char words[65536];
    static char* job[256];
    FILE* stream = fopen(file, "rb");
    if (!stream)
        return NULL;
    size_t length = fread(words, 1, sizeof words - 1, stream);
    fclose(stream);
    words[length] = '\0';
    int found = 0;
    job[found++] = self;
    for (size_t at = 0; at < length && found < 255; at += strlen(words + at) + 1)
        job[found++] = words + at;
    job[found] = NULL;
    *count = found;
    return job;
}

static void detach_from_launchctl(void)
{
    if (getppid() == 1)
        return;
    pid_t child = fork();
    if (child < 0)
        return;
    if (child > 0)
        _exit(0);
    setsid();
    signal(SIGTERM, SIG_IGN);
}

static const char* daemons_directory = "/System/Library/LaunchDaemons";

typedef struct {
    char** names;
    int count;
    int capacity;
} services_t;

static void is_hidden_until_check_in(const void* key, const void* value, void* context)
{
    char name[32];
    if (CFGetTypeID(key) == CFStringGetTypeID() && CFStringGetCString(key, name, sizeof name, kCFStringEncodingUTF8) &&
        strcasecmp(name, "HideUntilCheckIn") == 0 && CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue(value))
        *(int*)context = 1;
}

static void add_service(const void* key, const void* value, void* context)
{
    services_t* services = context;
    char name[128];
    int hidden = 0;
    if (CFGetTypeID(key) != CFStringGetTypeID() || !CFStringGetCString(key, name, sizeof name, kCFStringEncodingUTF8))
        return;
    if (CFGetTypeID(value) == CFDictionaryGetTypeID())
        CFDictionaryApplyFunction(value, is_hidden_until_check_in, &hidden);
    if (hidden)
        return;
    if (services->count == services->capacity) {
        int capacity = services->capacity ? services->capacity * 2 : 256;
        char** grown = realloc(services->names, capacity * sizeof(char*));
        if (!grown)
            return;
        services->names = grown;
        services->capacity = capacity;
    }
    services->names[services->count++] = strdup(name);
}

static void declared_services(services_t* services)
{
    DIR* directory = opendir(daemons_directory);
    struct dirent* entry;
    while (directory && (entry = readdir(directory))) {
        size_t length = strlen(entry->d_name);
        if (length < 7 || strcmp(entry->d_name + length - 6, ".plist") != 0)
            continue;
        char file[1024];
        snprintf(file, sizeof file, "%s/%s", daemons_directory, entry->d_name);
        CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8*)file, strlen(file), false);
        CFReadStreamRef stream = CFReadStreamCreateWithFile(NULL, url);
        if (stream && CFReadStreamOpen(stream)) {
            CFPropertyListRef list = CFPropertyListCreateFromStream(NULL, stream, 0, kCFPropertyListImmutable, NULL, NULL);
            if (list && CFGetTypeID(list) == CFDictionaryGetTypeID()) {
                CFDictionaryRef declared = CFDictionaryGetValue(list, CFSTR("MachServices"));
                if (declared && CFGetTypeID(declared) == CFDictionaryGetTypeID())
                    CFDictionaryApplyFunction(declared, add_service, services);
            }
            if (list)
                CFRelease(list);
            CFReadStreamClose(stream);
        }
        if (stream)
            CFRelease(stream);
        CFRelease(url);
    }
    if (directory)
        closedir(directory);
}

static int unregistered(services_t* services, char* first, size_t size)
{
    int missing = 0;
    for (int i = 0; i < services->count; i++) {
        mach_port_t port = MACH_PORT_NULL;
        if (bootstrap_look_up(bootstrap_port, services->names[i], &port) != KERN_SUCCESS) {
            if (!missing)
                snprintf(first, size, "%s", services->names[i]);
            missing++;
        }
    }
    return missing;
}

static int wait_for_daemons(int seconds, int* declared, double* waited, char* first, size_t size)
{
    services_t services = {0};
    double began = now();
    declared_services(&services);
    *declared = services.count;
    int missing;
    while ((missing = unregistered(&services, first, size)) > 0 && now() - began < seconds)
        usleep(50000);
    *waited = now() - began;
    return missing;
}

int main(int argc, char** argv)
{
    keep_own_output();
    detach_from_launchctl();
    if (argc == 3 && strcmp(argv[1], "--job") == 0) {
        int count = 0;
        char** job = read_job(argv[2], argv[0], &count);
        if (!job) {
            printf("revenant-runner: cannot read the job %s: %s\n", argv[2], strerror(errno));
            return 1;
        }
        argc = count;
        argv = job;
    }
    int deadline = argc > 1 ? atoi(argv[1]) : 30;
    int declared = 0;
    char absent[128] = "";
    double waited = 0;
    int missing = wait_for_daemons(deadline, &declared, &waited, absent, sizeof absent);
    double started = now();
    printf("revenant-runner: started pid=%d uid=%d\n", getpid(), getuid());
    fflush(stdout);
    openlog("revenant-runner", LOG_PID, LOG_USER);
    syslog(LOG_NOTICE, "revenant-runner started pid=%d", getpid());
    if (missing) {
        printf("revenant-runner: launchd had not registered %d of %d services after %.1f s, the first being %s; starting the test anyway\n", missing, declared, waited, absent);
        syslog(LOG_WARNING, "revenant-runner: launchd had not registered %d of %d services after %.1f s, the first being %s", missing, declared, waited, absent);
    } else {
        printf("revenant-runner: launchd had registered all %d services after %.1f s\n", declared, waited);
    }
    fflush(stdout);

    struct utsname name;
    uname(&name);
    char machine[64] = "";
    size_t length = sizeof machine;
    sysctlbyname("hw.machine", machine, &length, NULL, 0);
    char version[80];
    system_version(version, sizeof version);

    int uikit = dlopen("/System/Library/Frameworks/UIKit.framework/UIKit", RTLD_LAZY) != NULL;
    int ui_application = objc_getClass("UIApplication") != NULL;
    int status = -1, spawned = 0, spawn_error = 0, timed_out = 0, captured = 0;
    double duration = 0;
    if (argc > 2) {
        fflush(stdout);
        fflush(stderr);
        int saved_out = dup(STDOUT_FILENO), saved_err = dup(STDERR_FILENO);
        int out = open("/private/var/revenant/test.stdout", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        int err = open("/private/var/revenant/test.stderr", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        captured = (out >= 0 && err >= 0);
        if (!captured) {
            syslog(LOG_ERR, "revenant-runner cannot open the program's output in %s: %s",
                   verdict_directory, strerror(errno));
            fprintf(stderr, "revenant-runner: cannot open the program's stdout/stderr: %s\n", strerror(errno));
        }
        if (out >= 0)
            dup2(out, STDOUT_FILENO);
        if (err >= 0)
            dup2(err, STDERR_FILENO);
        setenv("NSUnbufferedIO", "YES", 1);
        pid_t child;
        posix_spawnattr_t attributes;
        sigset_t defaults;
        sigemptyset(&defaults);
        sigaddset(&defaults, SIGTERM);
        posix_spawnattr_init(&attributes);
        posix_spawnattr_setsigdefault(&attributes, &defaults);
        posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETSIGDEF);
        double spawned_at = now();
        spawn_error = posix_spawn(&child, argv[2], &attributes, NULL, argv + 2, environ);
        posix_spawnattr_destroy(&attributes);
        dup2(saved_out, STDOUT_FILENO);
        dup2(saved_err, STDERR_FILENO);
        close(saved_out);
        close(saved_err);
        if (out >= 0)
            close(out);
        if (err >= 0)
            close(err);
        if (spawn_error == 0) {
            spawned = 1;
            for (;;) {
                pid_t done = waitpid(child, &status, WNOHANG);
                if (done == child)
                    break;
                if (now() - spawned_at > deadline) {
                    timed_out = 1;
                    kill(child, SIGKILL);
                    waitpid(child, &status, 0);
                    break;
                }
                usleep(100000);
            }
            duration = now() - spawned_at;
        }
    }

    mkdir(verdict_directory, 0755);
    char partial[256], final[256];
    snprintf(partial, sizeof partial, "%s/verdict.json.partial", verdict_directory);
    snprintf(final, sizeof final, "%s/verdict.json", verdict_directory);
    FILE* file = fopen(partial, "w");
    if (!file) {
        syslog(LOG_ERR, "revenant-runner cannot write %s: %s", partial, strerror(errno));
        return 1;
    }
    fprintf(file, "{\"machine\":");
    json_string(file, machine);
    fprintf(file, ",\"kernel\":");
    json_string(file, name.version);
    fprintf(file, ",\"system\":");
    json_string(file, version);
    fprintf(file, ",\"uikit\":%d,\"UIApplication\":%d,\"runner_seconds\":%.3f", uikit, ui_application, now() - started);
    fprintf(file, ",\"daemons\":{\"services\":%d,\"unregistered\":%d,\"waited\":%.3f}", declared, missing, waited);
    if (argc > 2) {
        fprintf(file, ",\"test\":{\"path\":");
        json_string(file, argv[2]);
        fprintf(file, ",\"spawned\":%d,\"spawn_error\":%d,\"timed_out\":%d,\"output\":%d,\"seconds\":%.3f", spawned, spawn_error, timed_out, captured, duration);
        if (spawned && WIFEXITED(status))
            fprintf(file, ",\"exit\":%d", WEXITSTATUS(status));
        if (spawned && WIFSIGNALED(status))
            fprintf(file, ",\"signal\":%d", WTERMSIG(status));
        fprintf(file, "}");
    }
    fprintf(file, "}\n");
    fclose(file);
    rename(partial, final);
    printf("revenant-runner: verdict written\n");
    syslog(LOG_NOTICE, "revenant-runner verdict written");
    return 0;
}
