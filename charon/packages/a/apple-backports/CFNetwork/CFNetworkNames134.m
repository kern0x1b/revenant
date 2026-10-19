#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>
#import <CFNetwork/CFSocketStream.h>

// The three stream properties CFNetwork added in iOS 13.4 (facts/CFNetwork/Names.md). The ladder
// measures each of them first appearing in the cache of iOS 13.4, which is held. The one name the
// 13.0 headers annotate that the 16.0 cache is the first to export is in CFNetworkNames160.m.
// Each object carries the API of one release, so they are not carried together.

const CFStringRef kCFStreamPropertyAllowConstrainedNetworkAccess = CFSTR("kCFStreamPropertyAllowConstrainedNetworkAccess");
const CFStringRef kCFStreamPropertyAllowExpensiveNetworkAccess = CFSTR("kCFStreamPropertyAllowExpensiveNetworkAccess");
const CFStringRef kCFStreamPropertyConnectionIsExpensive = CFSTR("kCFStreamPropertyConnectionIsExpensive");
