#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "RevenantPasscode.h"

bool RevenantPasscodeUnlockDevice(NSData *passcode, int32_t *status)
{
    void *library = dlopen("/System/Library/PrivateFrameworks/MobileKeyBag.framework/MobileKeyBag", RTLD_LAZY);
    int32_t (*unlock_device)(CFDataRef, void *) = library ? (int32_t (*)(CFDataRef, void *))dlsym(library, "MKBUnlockDevice") : NULL;
    if (!unlock_device)
        return false;
    *status = unlock_device((__bridge CFDataRef)passcode, NULL);
    return true;
}
