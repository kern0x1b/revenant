#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>

const CFStringRef BACKPORT_IMPL(kSecUseAuthenticationContext) = CFSTR("u_AuthCtx");
const CFStringRef BACKPORT_IMPL(kSecUseAuthenticationUI) = CFSTR("u_AuthUI");
const CFStringRef BACKPORT_IMPL(kSecUseAuthenticationUIAllow) = CFSTR("u_AuthUIA");
const CFStringRef BACKPORT_IMPL(kSecUseAuthenticationUIFail) = CFSTR("u_AuthUIF");
const CFStringRef BACKPORT_IMPL(kSecUseAuthenticationUISkip) = CFSTR("u_AuthUIS");
