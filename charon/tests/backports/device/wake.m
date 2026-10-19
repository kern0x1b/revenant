#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <mach/mach_time.h>

typedef void *HidRef;
static HidRef (*client_create)(CFAllocatorRef);
static void (*dispatch_event)(HidRef, HidRef);
static HidRef (*hand)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, Boolean, Boolean, uint32_t);
static HidRef (*finger)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, Boolean, Boolean, uint32_t);
static HidRef (*keyboard)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, Boolean, uint32_t);
static void (*append)(HidRef, HidRef);
static HidRef client;

static void press(uint32_t page, uint32_t usage)
{
    dispatch_event(client, keyboard(kCFAllocatorDefault, mach_absolute_time(), page, usage, 1, 0));
    usleep(80000);
    dispatch_event(client, keyboard(kCFAllocatorDefault, mach_absolute_time(), page, usage, 0, 0));
}

static void touch(int phase, float x, float y)
{
    uint64_t now = mach_absolute_time();
    BOOL down = phase != 2;
    uint32_t mask = phase == 1 ? 0x4 : 0x23;
    HidRef parent = hand(kCFAllocatorDefault, now, 3, 0, 0, mask, 0, x, y, 0, 0, 0, down, down, 0);
    HidRef point = finger(kCFAllocatorDefault, now, 1, 2, mask, x, y, 0, 0, 0, down, down, 0);
    append(parent, point);
    dispatch_event(client, parent);
}

int main(void)
{
    @autoreleasepool {
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        client_create = dlsym(handle, "IOHIDEventSystemClientCreate");
        dispatch_event = dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
        hand = dlsym(handle, "IOHIDEventCreateDigitizerEvent");
        finger = dlsym(handle, "IOHIDEventCreateDigitizerFingerEvent");
        keyboard = dlsym(handle, "IOHIDEventCreateKeyboardEvent");
        append = dlsym(handle, "IOHIDEventAppendEvent");
        if (!client_create || !dispatch_event || !hand || !finger || !keyboard || !append)
            return 1;
        client = client_create(kCFAllocatorDefault);
        press(0x0C, 0x40);
        usleep(1200000);
        press(0x0C, 0x40);
        usleep(1200000);
        static const float heights[] = {0.905, 0.93, 0.88};
        static const float starts[] = {0.30, 0.36, 0.10};
        for (int attempt = 0; attempt < 3; attempt++) {
            float from = starts[attempt], to = from + 0.40, y = heights[attempt];
            touch(0, from, y);
            for (int step = 1; step <= 12; step++) {
                usleep(30000);
                touch(1, from + (to - from) * step / 12, y);
            }
            usleep(30000);
            touch(2, to, y);
            usleep(800000);
        }
        printf("checks=0 failures=0\n");
    }
    return 0;
}
