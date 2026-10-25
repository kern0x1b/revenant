#import "../app/revenant_check.h"
#import <dlfcn.h>

typedef int (*revenant_mkb_lock_state)(CFDictionaryRef options);

REVENANT_CASE(keybag_lock_state)
{
    void *library = dlopen("/System/Library/PrivateFrameworks/MobileKeyBag.framework/MobileKeyBag", RTLD_LAZY);
    revenant_mkb_lock_state lock_state = library ? (revenant_mkb_lock_state)dlsym(library, "MKBGetDeviceLockState") : NULL;
    int state = lock_state ? lock_state(NULL) : -1;
    NSString *detail = [NSString stringWithFormat:@"MKBGetDeviceLockState returned %d (0 unlocked, 1 locked, 2 locking, 3 disabled)", state];
    revenant_expect_true(@"a fresh iOS 6.1.3 image has no passcode, so the lock state is 3",
                         (state == 3) != (BOOL)negative, detail);
}
