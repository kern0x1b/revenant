#import "CharonFoundationIdentifiers.h"

/* The file protection level of iOS 17.0, in an object of its own so that this object is not in a
   band whose release already exports the name. The value is the one the host's own Foundation
   exports, read by dlsym (tests/backports/host/foundation-constants/); here it is the name itself,
   which is the case and not the rule - NSHTTPCookieSetByJavaScript, in FoundationIdentifiers18.m,
   holds "SetInJavaScript" and would have been wrong. facts/Foundation/NSURLResourceKeyStrings.md
   carries the table. */

NSString * const NSFileProtectionCompleteWhenUserInactive = @"NSFileProtectionCompleteWhenUserInactive";
