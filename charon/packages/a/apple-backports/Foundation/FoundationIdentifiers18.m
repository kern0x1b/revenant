#import "CharonFoundationIdentifiers.h"

/* The cookie attribute of iOS 18.2, in an object of its own for the same reason as the other two
   groups. This is the one value in the three that is not its name: the release's own value is
   "SetInJavaScript", read out of the host's Foundation by dlsym
   (tests/backports/host/foundation-constants/) and recorded in
   facts/Foundation/NSURLResourceKeyStrings.md. Writing the constant's own name here would have been
   a value no release ships, and the differential in that suite is what notices it. */

NSString * const NSHTTPCookieSetByJavaScript = @"SetInJavaScript";
