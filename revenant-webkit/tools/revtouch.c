#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_time.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef uint32_t IOOptionBits;
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

enum {
    kIOHIDDigitizerEventRange    = 1u << 1,
    kIOHIDDigitizerEventTouch    = 1u << 2,
    kIOHIDDigitizerEventPosition = 1u << 4,
};

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, uint64_t timeStamp,
    uint32_t transducerType, uint32_t index, uint32_t identity, uint32_t eventMask, uint32_t buttonMask,
    float x, float y, float z, float tipPressure, float barrelPressure,
    boolean_t range, boolean_t touch, IOOptionBits options);
extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp,
    uint32_t index, uint32_t identity, uint32_t eventMask, float x, float y, float z,
    float tipPressure, float twist, boolean_t range, boolean_t touch, IOOptionBits options);
extern void IOHIDEventAppendEvent(IOHIDEventRef parent, IOHIDEventRef child);
extern void IOHIDEventSetIntegerValue(IOHIDEventRef event, uint32_t field, int value);
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

#define FIELD_IS_DISPLAY_INTEGRATED 0xb0017

static IOHIDEventSystemClientRef gClient;
static float gW = 320.0f, gH = 480.0f;

static void post(float px, float py, boolean_t down)
{
    float x = px / gW, y = py / gH;
    uint32_t mask = kIOHIDDigitizerEventPosition | (down ? (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch) : (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch));
    uint64_t ts = mach_absolute_time();

    IOHIDEventRef parent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, ts,
        2 /* hand */, 0, 0, mask, 0, x, y, 0, 0, 0, down, down, 0);
    IOHIDEventSetIntegerValue(parent, FIELD_IS_DISPLAY_INTEGRATED, 1);

    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, ts,
        1, 2, mask, x, y, 0, down ? 1.0f : 0.0f, 0, down, down, 0);
    IOHIDEventAppendEvent(parent, finger);
    CFRelease(finger);

    IOHIDEventSystemClientDispatchEvent(gClient, parent);
    CFRelease(parent);
}

int main(int argc, char **argv)
{
    if (argc < 4) { fprintf(stderr, "usage: revtouch tap|down|move|up|swipe X Y [X2 Y2]\n"); return 2; }
    const char *env;
    if ((env = getenv("REVTOUCH_W"))) gW = atof(env);
    if ((env = getenv("REVTOUCH_H"))) gH = atof(env);

    gClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!gClient) { fprintf(stderr, "IOHIDEventSystemClientCreate failed\n"); return 1; }

    const char *cmd = argv[1];
    float x = atof(argv[2]), y = atof(argv[3]);

    if (!strcmp(cmd, "tap")) {
        post(x, y, 1);
        usleep(60 * 1000);
        post(x, y, 0);
    } else if (!strcmp(cmd, "down")) {
        post(x, y, 1);
    } else if (!strcmp(cmd, "move")) {
        post(x, y, 1);
    } else if (!strcmp(cmd, "up")) {
        post(x, y, 0);
    } else if (!strcmp(cmd, "swipe") && argc >= 6) {
        float x2 = atof(argv[4]), y2 = atof(argv[5]);
        post(x, y, 1);
        for (int i = 1; i <= 10; i++) {
            usleep(16 * 1000);
            post(x + (x2 - x) * i / 10.0f, y + (y2 - y) * i / 10.0f, 1);
        }
        usleep(16 * 1000);
        post(x2, y2, 0);
    } else {
        fprintf(stderr, "bad command\n"); return 2;
    }
    usleep(20 * 1000);
    return 0;
}
