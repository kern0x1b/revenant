#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef kSecUseAuthenticationContext __attribute__((section("__DATA,__data"))) = CFSTR("u_AuthCtx");
const CFStringRef kSecUseAuthenticationUI __attribute__((section("__DATA,__data"))) = CFSTR("u_AuthUI");
const CFStringRef kSecUseAuthenticationUIAllow __attribute__((section("__DATA,__data"))) = CFSTR("u_AuthUIA");
const CFStringRef kSecUseAuthenticationUIFail __attribute__((section("__DATA,__data"))) = CFSTR("u_AuthUIF");
const CFStringRef kSecUseAuthenticationUISkip __attribute__((section("__DATA,__data"))) = CFSTR("u_AuthUIS");
