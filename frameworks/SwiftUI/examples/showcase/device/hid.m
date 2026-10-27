#import "hid.h"
#include <dlfcn.h>
#include <mach/mach_time.h>

typedef void *HidRef;
static HidRef (*hid_client_create)(CFAllocatorRef);
static void (*hid_dispatch)(HidRef, HidRef);
static HidRef (*hid_hand)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, Boolean, Boolean, uint32_t);
static HidRef (*hid_finger)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, Boolean, Boolean, uint32_t);
static void (*hid_append)(HidRef, HidRef);
static HidRef hid_client;

BOOL hid_ready(void)
{
    if (hid_client)
        return YES;
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!handle)
        return NO;
    hid_client_create = dlsym(handle, "IOHIDEventSystemClientCreate");
    hid_dispatch = dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    hid_hand = dlsym(handle, "IOHIDEventCreateDigitizerEvent");
    hid_finger = dlsym(handle, "IOHIDEventCreateDigitizerFingerEvent");
    hid_append = dlsym(handle, "IOHIDEventAppendEvent");
    if (!hid_client_create || !hid_dispatch || !hid_hand || !hid_finger || !hid_append)
        return NO;
    hid_client = hid_client_create(kCFAllocatorDefault);
    return hid_client != NULL;
}

void hid_touch(int phase, CGPoint point)
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    uint64_t now = mach_absolute_time();
    float x = point.x / size.width, y = point.y / size.height;
    BOOL down = phase != 2;
    uint32_t mask = phase == 1 ? 0x4 : 0x23;
    HidRef hand = hid_hand(kCFAllocatorDefault, now, 3, 0, 0, mask, 0, x, y, 0, 0, 0, down, down, 0);
    HidRef finger = hid_finger(kCFAllocatorDefault, now, 1, 2, mask, x, y, 0, 0, 0, down, down, 0);
    hid_append(hand, finger);
    hid_dispatch(hid_client, hand);
}
