#include <CoreFoundation/CoreFoundation.h>

static void heartbeat(CFRunLoopTimerRef timer, void *info)
{
    (void)timer;
    (void)info;
    CFShow(CFSTR("$name is running"));
}

int main(void)
{
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent(), 3600, 0, 0, heartbeat, NULL);
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes);
    CFRunLoopRun();
    return 0;
}
