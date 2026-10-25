#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static Class revenant_stand_in;

__attribute__((constructor)) static void revenant_stand_in_install(void)
{
    revenant_stand_in = objc_allocateClassPair(objc_getClass("NSObject"), "NSPersonNameComponents", 0);
    if (revenant_stand_in)
        objc_registerClassPair(revenant_stand_in);
}

Class revenant_stand_in_class(void)
{
    return revenant_stand_in;
}
