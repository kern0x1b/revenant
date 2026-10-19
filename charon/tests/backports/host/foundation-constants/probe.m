#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

/* The names this suite is about: the fourteen the package now carries, and one the package does not
   and no framework exports, which is the control. Our values are the linked definitions, read
   through the symbols themselves so the linker binds them to this binary's own object; the host's
   values come from dlsym on the Foundation image, which returns that image's copy whatever the
   process has linked. The suite's run.sh counts the definitions in the binary before running this,
   so a port that forgot to link an object cannot pass by reading Apple's. */

struct Entry {
    const char *name;
    NSString *ours;
    int carried;   /* 1 when the package is expected to define it */
};

static struct Entry ENTRIES[] = {
    {"NSCalendarIdentifierBangla", nil, 1}, {"NSCalendarIdentifierDangi", nil, 1},
    {"NSCalendarIdentifierGujarati", nil, 1}, {"NSCalendarIdentifierKannada", nil, 1},
    {"NSCalendarIdentifierMalayalam", nil, 1}, {"NSCalendarIdentifierMarathi", nil, 1},
    {"NSCalendarIdentifierOdia", nil, 1}, {"NSCalendarIdentifierTamil", nil, 1},
    {"NSCalendarIdentifierTelugu", nil, 1}, {"NSCalendarIdentifierVietnamese", nil, 1},
    {"NSCalendarIdentifierVikram", nil, 1}, {"NSURLUbiquitousItemIsSyncPausedKey", nil, 1},
    {"NSURLUbiquitousItemSupportedSyncControlsKey", nil, 1},
    {"NSFileProtectionCompleteWhenUserInactive", nil, 1}, {"NSHTTPCookieSetByJavaScript", nil, 1},
    /* the control: no framework exports it, and the package does not carry it */
    {"NSCalendarIdentifierCharonProbeNoSuchConstant", nil, 0},
};

static void fill_ours(void)
{
    ENTRIES[0].ours = NSCalendarIdentifierBangla;
    ENTRIES[1].ours = NSCalendarIdentifierDangi;
    ENTRIES[2].ours = NSCalendarIdentifierGujarati;
    ENTRIES[3].ours = NSCalendarIdentifierKannada;
    ENTRIES[4].ours = NSCalendarIdentifierMalayalam;
    ENTRIES[5].ours = NSCalendarIdentifierMarathi;
    ENTRIES[6].ours = NSCalendarIdentifierOdia;
    ENTRIES[7].ours = NSCalendarIdentifierTamil;
    ENTRIES[8].ours = NSCalendarIdentifierTelugu;
    ENTRIES[9].ours = NSCalendarIdentifierVietnamese;
    ENTRIES[10].ours = NSCalendarIdentifierVikram;
    ENTRIES[11].ours = NSURLUbiquitousItemIsSyncPausedKey;
    ENTRIES[12].ours = NSURLUbiquitousItemSupportedSyncControlsKey;
    ENTRIES[13].ours = NSFileProtectionCompleteWhenUserInactive;
    ENTRIES[14].ours = NSHTTPCookieSetByJavaScript;
}

int main(int argc, char **argv)
{
    /* --none compares nothing on purpose: the run must refuse it, because a check that examined
       nothing has proved nothing. */
    int compare_nothing = (argc > 1 && strcmp(argv[1], "--none") == 0);
    void *host = dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_LAZY);
    if (!host) { printf("FAIL dlopen: %s\n", dlerror()); return 2; }
    fill_ours();

    unsigned compared = 0, differences = 0, missing = 0;
    for (unsigned i = 0; i < sizeof ENTRIES / sizeof *ENTRIES; i++) {
        struct Entry *entry = &ENTRIES[i];
        void *theirs = dlsym(host, entry->name);
        NSString *host_value = theirs ? *(NSString *__unsafe_unretained *)theirs : nil;
        if (compare_nothing) continue;
        if (!entry->carried) {
            if (theirs) { printf("FAIL %-46s the control name is exported after all\n", entry->name); differences++; }
            else printf("ok   %-46s not exported by the host, not carried: the control\n", entry->name);
            continue;
        }
        if (!entry->ours) { printf("FAIL %-46s the linked symbol is NULL\n", entry->name); missing++; continue; }
        if (!host_value) { printf("FAIL %-46s the host does not export it, so there is no value to compare\n", entry->name); missing++; continue; }
        compared++;
        if ([entry->ours isEqualToString:host_value]) {
            printf("ok   %-46s %s\n", entry->name, entry->ours.UTF8String);
        } else {
            printf("FAIL %-46s ours=%s host=%s\n", entry->name, entry->ours.UTF8String, host_value.UTF8String);
            differences++;
        }
    }
    if (compare_nothing) {
        printf("FAIL compared 0 values: nothing was read, so nothing is claimed\n");
        return 1;
    }
    printf("compared=%u differences=%u missing=%u\n", compared, differences, missing);
    return (differences || missing) ? 1 : 0;
}
