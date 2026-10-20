#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>
#import <CFNetwork/CFSocketStream.h>

const CFStringRef kCFStreamPropertyAllowConstrainedNetworkAccess = CFSTR("kCFStreamPropertyAllowConstrainedNetworkAccess");
const CFStringRef kCFStreamPropertyAllowExpensiveNetworkAccess = CFSTR("kCFStreamPropertyAllowExpensiveNetworkAccess");
const CFStringRef kCFStreamPropertyConnectionIsExpensive = CFSTR("kCFStreamPropertyConnectionIsExpensive");
