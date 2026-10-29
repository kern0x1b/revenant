#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef kSecImportToMemoryOnly __attribute__((section("__DATA,__data"))) = CFSTR("memory");
