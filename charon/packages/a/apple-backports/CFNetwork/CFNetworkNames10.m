#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFSocketStream.h>

// The call-signalling network service type, with the text CFNetwork itself gives it (facts/CFNetwork/Names.md).
// The armv7 ladder measures it first appearing in the cache of iOS 10.0.1, the first rung of 10.0 held
// and an upper bound for the 10.0 the header annotates.

const CFStringRef kCFStreamNetworkServiceTypeCallSignaling = CFSTR("kCFStreamNetworkServiceTypeCallSignaling");
