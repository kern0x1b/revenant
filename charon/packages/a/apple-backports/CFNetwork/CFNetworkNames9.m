#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <CFNetwork/CFHTTPMessage.h>
#import <CFNetwork/CFSocketStream.h>

// The names CFNetwork of iOS 8.0 and 9.0 added, carried with the texts CFNetwork itself gives them,
// read from the arm64e shared cache of iOS 18.0 (facts/CFNetwork/Names.md). iOS 6.1.3 exports
// kCFHTTPVersion1_1 and none of these, so an application that names one of them loads where it would
// otherwise die in dyld.
//
// The two are in one object because the armv7 ladder measures both of them first appearing in the
// cache of iOS 9.0: the armv7 cache of 8.0 exports neither, although CFHTTPMessage.h annotates
// kCFHTTPVersion2_0 as available from 8.0. An object carries API of one release, so the file is split
// by what the ladder says and not by what the header says.

const CFStringRef kCFHTTPVersion2_0 = CFSTR("HTTP/2.0");

const CFStringRef kCFStreamPropertySocketExtendedBackgroundIdleMode = CFSTR("kCFStreamPropertySocketExtendedBackgroundIdleMode");
