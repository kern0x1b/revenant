#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Network/Network.h>

const CFStringRef BACKPORT_IMPL(kNWErrorDomainPOSIX) = CFSTR("NSPOSIXErrorDomain");
const CFStringRef BACKPORT_IMPL(kNWErrorDomainDNS) = CFSTR("kNWErrorDomainDNS");
const CFStringRef BACKPORT_IMPL(kNWErrorDomainTLS) = CFSTR("NSOSStatusErrorDomain");
