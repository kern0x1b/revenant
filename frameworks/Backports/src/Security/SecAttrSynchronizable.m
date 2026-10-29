#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef kSecAttrSynchronizable __attribute__((section("__DATA,__data"))) = CFSTR("sync");
