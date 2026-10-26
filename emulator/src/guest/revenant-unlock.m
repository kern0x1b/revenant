#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#import "hid.h"

static void drag(CGPoint from, CGPoint to, int steps)
{
    hid_touch(0, from);
    usleep(30000);
    for (int index = 1; index <= steps; index++) {
        CGPoint at = CGPointMake(from.x + (to.x - from.x) * index / steps, from.y + (to.y - from.y) * index / steps);
        hid_touch(1, at);
        usleep(30000);
    }
    hid_touch(2, to);
}

static int locked(void)
{
    void *services = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    mach_port_t (*server)(void) = services ? (mach_port_t (*)(void))dlsym(services, "SBSSpringBoardServerPort") : NULL;
    void (*lock_status)(mach_port_t, bool*, bool*) = services ? (void (*)(mach_port_t, bool*, bool*))dlsym(services, "SBGetScreenLockStatus") : NULL;
    if (!server || !lock_status)
        return -1;
    mach_port_t port = server();
    bool isLocked = false, passcode = false;
    lock_status(port, &isLocked, &passcode);
    return isLocked ? (passcode ? 2 : 1) : 0;
}

static CGPoint fraction(const char *x, const char *y)
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    return CGPointMake(atof(x) * size.width, atof(y) * size.height);
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr, "usage: revenant-unlock status | wake | tap FX FY | drag FX0 FY0 FX1 FY1\n");
        return 2;
    }
    @autoreleasepool {
        if (strcmp(argv[1], "status") == 0) {
            int state = locked();
            printf("%s\n", state == 0 ? "unlocked" : state == 1 ? "locked" : state == 2 ? "passcode" : "unknown");
            return state < 0 ? 1 : 0;
        }
        if (strcmp(argv[1], "wake") == 0) {
            void *services = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
            void (*undim)(void) = services ? (void (*)(void))dlsym(services, "SBSUndimScreen") : NULL;
            if (!undim) {
                fprintf(stderr, "revenant-unlock: SpringBoardServices has no SBSUndimScreen\n");
                return 1;
            }
            undim();
            printf("woke\n");
            return 0;
        }
        if (!hid_ready()) {
            fprintf(stderr, "revenant-unlock: the HID client is not available\n");
            return 1;
        }
        if (strcmp(argv[1], "tap") == 0 && argc == 4) {
            CGPoint at = fraction(argv[2], argv[3]);
            hid_touch(0, at);
            usleep(80000);
            hid_touch(2, at);
            return 0;
        }
        if (strcmp(argv[1], "drag") == 0 && argc == 6) {
            drag(fraction(argv[2], argv[3]), fraction(argv[4], argv[5]), 12);
            return 0;
        }
    }
    fprintf(stderr, "revenant-unlock: unknown command %s\n", argv[1]);
    return 2;
}
