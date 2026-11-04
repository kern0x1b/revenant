#include "../revenant_impl.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>
#import <CFNetwork/CFSocketStream.h>

const CFStringRef BACKPORT_IMPL(kCFHTTPVersion2_0) = CFSTR("HTTP/2.0");

const CFStringRef BACKPORT_IMPL(kCFStreamPropertySocketExtendedBackgroundIdleMode) = CFSTR("kCFStreamPropertySocketExtendedBackgroundIdleMode");
