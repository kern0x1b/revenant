#import <GameController/GameController.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static void check_lists(void)
{
    CHECK_EQUAL(image_of([GCController class]), @"libGameControllerBackports.dylib", "GCController comes from the backports");
    CHECK_EQUAL(image_of([GCMouse class]), @"libGameControllerBackports.dylib", "GCMouse comes from the backports");
    CHECK_EQUAL(image_of([GCKeyboard class]), @"libGameControllerBackports.dylib", "GCKeyboard comes from the backports");
    NSArray *controllers = [GCController controllers];
    CHECK(controllers != nil && controllers.count == 0, "no controllers are attached");
    NSArray *mice = [GCMouse mice];
    CHECK(mice != nil && mice.count == 0, "no mice are attached");
    CHECK([GCController current] == nil, "there is no current controller");
    CHECK([GCMouse current] == nil, "there is no current mouse");
    CHECK([GCKeyboard coalescedKeyboard] == nil, "there is no keyboard");
}

static void check_notifications(void)
{
    CHECK_EQUAL(GCControllerDidConnectNotification, @"GCControllerDidConnectNotification", "the connect name");
    CHECK_EQUAL(GCControllerDidDisconnectNotification, @"GCControllerDidDisconnectNotification", "the disconnect name");
    CHECK_EQUAL(GCMouseDidConnectNotification, @"GCMouseDidConnectNotification", "the mouse connect name");
    CHECK_EQUAL(GCKeyboardDidDisconnectNotification, @"GCKeyboardDidDisconnectNotification", "the keyboard disconnect name");
    __block int posted = 0;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:nil usingBlock:^(NSNotification *note) { posted++; }];
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    CHECK(posted == 0, "nothing is posted");
}

static void check_discovery(void)
{
    __block int calls = 0;
    __block BOOL onMain = NO;
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        calls++;
        onMain = [NSThread isMainThread];
    }];
    CHECK(calls == 0, "the handler is not called before the start returns");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    CHECK(calls == 1, "the handler is called once");
    CHECK(onMain, "on the main queue");
    [GCController stopWirelessControllerDiscovery];
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
    [GCController stopWirelessControllerDiscovery];
    CHECK(YES, "a start with no handler and a stop do nothing");
    CHECK(![GCController shouldMonitorBackgroundEvents], "the background flag starts NO");
    [GCController setShouldMonitorBackgroundEvents:YES];
    CHECK([GCController shouldMonitorBackgroundEvents], "the background flag answers what was set");
    [GCController setShouldMonitorBackgroundEvents:NO];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_lists();
        check_notifications();
        check_discovery();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
