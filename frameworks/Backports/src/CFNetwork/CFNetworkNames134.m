#include "../revenant_impl.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>
#import <CFNetwork/CFSocketStream.h>

const CFStringRef BACKPORT_IMPL(kCFStreamPropertyAllowConstrainedNetworkAccess) = CFSTR("kCFStreamPropertyAllowConstrainedNetworkAccess");
const CFStringRef BACKPORT_IMPL(kCFStreamPropertyAllowExpensiveNetworkAccess) = CFSTR("kCFStreamPropertyAllowExpensiveNetworkAccess");
const CFStringRef BACKPORT_IMPL(kCFStreamPropertyConnectionIsExpensive) = CFSTR("kCFStreamPropertyConnectionIsExpensive");
