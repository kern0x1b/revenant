#include "../revenant_impl.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>

const CFStringRef BACKPORT_IMPL(kCFHTTPVersion3_0) = CFSTR("HTTP/3.0");
