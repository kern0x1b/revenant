#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>

// The HTTP/3.0 version name, which the 13.0 headers annotate and the held ladder measures first
// exported in the cache of iOS 16.0, so its object is the 16.0 one. The other names of the same
// header are in CFNetworkNames134.m (iOS 13.4).

const CFStringRef kCFHTTPVersion3_0 = CFSTR("HTTP/3.0");
